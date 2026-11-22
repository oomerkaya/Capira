import 'dart:async';

import 'package:capira/core/utils/app_logger.dart';
import 'package:capira/features/background/domain/close_update.dart';
import 'package:capira/features/market/market_providers.dart';
import 'package:capira/features/portfolio/portfolio_providers.dart';
import 'package:capira/features/settings/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

/// Unique name of the periodic Android work.
const String closeUpdateWork = 'capira-close-update';

/// How often Android wakes the task. Runs only fetch what is stale since
/// the last close, so most runs send nothing; 4 hours guarantees a run
/// in every evening window after the close.
const Duration closeUpdateFrequency = Duration(hours: 4);

/// Entry point of the background isolate (Android WorkManager). Builds the
/// same providers as the app, runs [CloseUpdate] once and disposes them.
/// No secret is passed in: the key is read from secure storage like in
/// the app, and nothing about it is logged.
@pragma('vm:entry-point')
void closeUpdateDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer();
    try {
      final report = await container.read(closeUpdateProvider).run();
      AppLogger.info(
        'background update: ${report.fetched.length} categories, '
        'kap ${report.kapFetched}, day ${report.recordedDay}',
      );
    } on Object catch (e, st) {
      AppLogger.error('background update failed', error: e, stackTrace: st);
    } finally {
      container.dispose();
    }
    // Always "done": a failure waits for the next periodic run instead of
    // retrying quickly against the API.
    return true;
  });
}

final closeUpdateProvider = Provider<CloseUpdate>(
  (ref) => CloseUpdate(
    market: ref.watch(marketRepositoryProvider),
    disclosures: ref.watch(disclosureRepositoryProvider),
    portfolio: ref.watch(portfolioRepositoryProvider),
    snapshots: ref.watch(snapshotRepositoryProvider),
    calendar: () => ref.read(marketCalendarProvider.future),
  ),
);

/// Registers or cancels the periodic work; replaced in tests.
abstract interface class BackgroundScheduler {
  Future<void> enable();
  Future<void> disable();
}

class WorkmanagerScheduler implements BackgroundScheduler {
  const WorkmanagerScheduler();

  @override
  Future<void> enable() => Workmanager().registerPeriodicTask(
    closeUpdateWork,
    closeUpdateWork,
    frequency: closeUpdateFrequency,
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
    // Keep the existing schedule across app starts.
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  @override
  Future<void> disable() => Workmanager().cancelByUniqueName(closeUpdateWork);
}

final backgroundSchedulerProvider = Provider<BackgroundScheduler>(
  (ref) => const WorkmanagerScheduler(),
);

/// Whether the daily background update is on (setting, default on). The
/// schedule follows it; nothing is scheduled in tests or off Android.
final backgroundUpdateProvider =
    NotifierProvider<BackgroundUpdateNotifier, bool>(
      BackgroundUpdateNotifier.new,
    );

class BackgroundUpdateNotifier extends Notifier<bool> {
  bool _userChanged = false;

  bool get _canSchedule =>
      ref.read(autoRefreshEnabledProvider) &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  @override
  bool build() {
    _userChanged = false;
    unawaited(_load());
    return true;
  }

  Future<void> _load() async {
    final result = await ref
        .read(settingsRepositoryProvider)
        .getBackgroundUpdate();
    if (!ref.mounted || _userChanged) return;
    final enabled = result.valueOrNull ?? true;
    state = enabled;
    await _apply(enabled);
  }

  Future<void> setEnabled({required bool enabled}) async {
    _userChanged = true;
    state = enabled;
    await ref
        .read(settingsRepositoryProvider)
        .setBackgroundUpdate(enabled: enabled);
    await _apply(enabled);
  }

  Future<void> _apply(bool enabled) async {
    if (!_canSchedule) return;
    try {
      final scheduler = ref.read(backgroundSchedulerProvider);
      await (enabled ? scheduler.enable() : scheduler.disable());
    } on Object catch (e, st) {
      AppLogger.error('background schedule failed', error: e, stackTrace: st);
    }
  }
}
