import 'package:capira/features/market/domain/entities/market_calendar.dart';
import 'package:capira/features/market/domain/entities/quote.dart';
import 'package:capira/features/market/domain/services/refresh_policy.dart';

/// When the daily background update fetches what. Pure and testable.
///
/// Rules:
/// - Once per day, after the **close**: 18:20 Istanbul (BIST closes at
///   18:00, its data is at least 15 minutes delayed).
/// - The task wakes up every few hours; each run only fetches the
///   categories that have no price from after the latest close. A category
///   the app already refreshed after the close costs nothing.
/// - FX and metals every day; stocks and funds only when the close was on
///   a trading day (no weekends, no holidays).
/// - Funds have one price per day: fetched only when they were not fetched
///   at all on the close's day (the app may have done it in the session).
/// - The day's value is recorded for the close's day, so the history has
///   a point per day even when the app is not opened.
abstract final class CloseUpdatePolicy {
  static const int closeMinute = 18 * 60 + 20;

  /// The latest close at or before [now]: today's 18:20 Istanbul when it
  /// has passed, else yesterday's.
  static DateTime lastClose(DateTime now) {
    final local = RefreshPolicy.toIstanbul(now);
    final todayClose = DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).add(const Duration(minutes: closeMinute));
    final close = local.isBefore(todayClose)
        ? todayClose.subtract(const Duration(days: 1))
        : todayClose;
    return close.subtract(RefreshPolicy.istanbulOffset);
  }

  /// Whether the Istanbul day of [close] had a BIST session.
  static bool isTradingDay(DateTime close, MarketCalendar calendar) {
    final local = RefreshPolicy.toIstanbul(close);
    if (local.weekday == DateTime.saturday ||
        local.weekday == DateTime.sunday) {
      return false;
    }
    return !calendar.isClosed(local);
  }

  /// Categories without a price from after [close].
  static Set<QuoteCategory> due({
    required DateTime close,
    required Map<QuoteCategory, DateTime?> lastSuccess,
    required MarketCalendar calendar,
  }) {
    final trading = isTradingDay(close, calendar);
    return {
      for (final c in QuoteCategory.values)
        if (_isStale(c, lastSuccess[c], close) &&
            (trading ||
                (c != QuoteCategory.stocks && c != QuoteCategory.funds)))
          c,
    };
  }

  static bool _isStale(QuoteCategory c, DateTime? last, DateTime close) {
    if (last == null) return true;
    if (c == QuoteCategory.funds) return !_sameIstanbulDay(last, close);
    return last.isBefore(close);
  }

  static bool _sameIstanbulDay(DateTime a, DateTime b) {
    final x = RefreshPolicy.toIstanbul(a);
    final y = RefreshPolicy.toIstanbul(b);
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}
