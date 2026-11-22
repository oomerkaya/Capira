import 'package:capira/app.dart';
import 'package:capira/features/background/presentation/background_update.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // Registers the background entry point; scheduling follows the
    // setting (BackgroundUpdateNotifier).
    await Workmanager().initialize(closeUpdateDispatcher);
  }
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/inter/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Inter'], license);
  });
  runApp(const ProviderScope(child: CapiraApp()));
}
