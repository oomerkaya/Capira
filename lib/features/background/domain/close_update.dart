import 'package:capira/core/error/result.dart';
import 'package:capira/features/background/domain/close_update_policy.dart';
import 'package:capira/features/market/domain/entities/market_calendar.dart';
import 'package:capira/features/market/domain/entities/quote.dart';
import 'package:capira/features/market/domain/repositories/disclosure_repository.dart';
import 'package:capira/features/market/domain/repositories/market_repository.dart';
import 'package:capira/features/market/domain/services/disclosure_policy.dart';
import 'package:capira/features/market/domain/services/refresh_policy.dart';
import 'package:capira/features/portfolio/domain/repositories/portfolio_repository.dart';
import 'package:capira/features/portfolio/domain/repositories/snapshot_repository.dart';
import 'package:capira/features/portfolio/domain/services/holding_calculator.dart';
import 'package:capira/features/portfolio/domain/services/portfolio_valuator.dart';
import 'package:capira/features/portfolio/domain/services/snapshot_builder.dart';
import 'package:capira/features/portfolio/domain/usecases/snapshot_use_cases.dart';
import 'package:decimal/decimal.dart';

/// What one background run did (for tests and the debug log).
class CloseUpdateReport {
  const CloseUpdateReport({
    required this.fetched,
    required this.kapFetched,
    required this.recordedDay,
  });

  /// Categories fetched successfully.
  final Set<QuoteCategory> fetched;
  final bool kapFetched;

  /// Day of the value recorded, or `null` when none was written.
  final String? recordedDay;
}

/// The daily update after the close ([CloseUpdatePolicy]): prices that
/// are stale since the close, the KAP feed when due, and the close day's
/// value. Uses the same repositories, quota counter and key as the app;
/// nothing is sent without a key or with the monthly quota used up.
class CloseUpdate {
  CloseUpdate({
    required this._market,
    required this._disclosures,
    required this._portfolio,
    required this._snapshots,
    required this._calendar,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MarketRepository _market;
  final DisclosureRepository _disclosures;
  final PortfolioRepository _portfolio;
  final SnapshotRepository _snapshots;
  final Future<MarketCalendar> Function() _calendar;
  final DateTime Function() _clock;

  Future<CloseUpdateReport> run() async {
    final now = _clock();
    final close = CloseUpdatePolicy.lastClose(now);

    // The server's own count first (free): an exhausted quota sends nothing.
    await _market.syncQuota();
    final usage = (await _market.quotaUsage()).valueOrNull;
    final canSend = usage != null && !usage.isExhausted;

    final before = (await _market.watchQuotes().first).valueOrNull ?? [];
    final lastSuccess = RefreshPolicy.lastSuccessByCategory(before)
      ..[QuoteCategory.stocks] = await _market.stocksSnapshotAt();
    final due = canSend
        ? CloseUpdatePolicy.due(
            close: close,
            lastSuccess: lastSuccess,
            calendar: await _calendar(),
          )
        : const <QuoteCategory>{};

    var fetched = <QuoteCategory>{};
    if (due.isNotEmpty) {
      final result = await _market.refresh(categories: due);
      if (result case Success(value: final report)) {
        fetched = due.difference(report.failures.keys.toSet());
      }
    }

    var kapFetched = false;
    if (canSend &&
        DisclosurePolicy.isDue(
          now: now,
          lastFetched: await _disclosures.lastFeedAt(),
        )) {
      kapFetched = await _disclosures.refreshFeed() is Success;
    }
    await _disclosures.prune();

    final recordedDay = await _recordCloseDay(close, fetched.isNotEmpty);
    return CloseUpdateReport(
      fetched: fetched,
      kapFetched: kapFetched,
      recordedDay: recordedDay,
    );
  }

  /// Writes the close day's value when prices were just fetched, or when
  /// that day has no value yet (better a slightly later price than a gap).
  Future<String?> _recordCloseDay(DateTime close, bool freshPrices) async {
    final day = SnapshotBuilder.dayKey(close);
    final stored = (await _snapshots.watchSnapshots().first).valueOrNull;
    if (stored == null) return null;
    if (!freshPrices && stored.any((s) => s.day == day)) return null;

    final quotes = (await _market.watchQuotes().first).valueOrNull;
    final items = (await _portfolio.watchPortfolio().first).valueOrNull;
    if (quotes == null || items == null) return null;
    final summary = PortfolioValuator.value([
      for (final item in items)
        HoldingCalculator.calculate(item.asset, item.transactions),
    ], quotes);
    if (summary.totalValue <= Decimal.zero) return null;
    final saved = await RecordSnapshot(
      _snapshots,
    ).call(summary: summary, quotes: quotes, now: close);
    return saved is Success ? day : null;
  }
}
