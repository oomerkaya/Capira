import 'package:capira/core/utils/formatters.dart';
import 'package:capira/core/widgets/amount_display.dart';
import 'package:decimal/decimal.dart';

/// Profit or loss in the selected currency, the cost converted at each
/// buy's own rate (the real dollar / euro result).
class CurrencyPnl {
  const CurrencyPnl({required this.amount, this.percent});

  /// In the display currency, not TRY.
  final Decimal amount;
  final Decimal? percent;

  /// `null` in TRY mode or when the cost in that currency is unknown
  /// (a buy without a stored rate).
  static CurrencyPnl? of({
    required AmountFormat format,
    required Decimal? valueTry,
    required Decimal? costInCurrency,
  }) {
    if (!format.converts || valueTry == null || costInCurrency == null) {
      return null;
    }
    final pnl = format.convertValue(valueTry) - costInCurrency;
    return CurrencyPnl(
      amount: pnl,
      percent: costInCurrency > Decimal.zero
          ? (pnl * Decimal.fromInt(100) / costInCurrency).toDecimal(
              scaleOnInfinitePrecision: 4,
            )
          : null,
    );
  }

  /// `+$120,00 (+%3,10)`, masked in privacy mode.
  String label(AmountFormat format) {
    final money = format.hidden
        ? '${format.symbol}${AmountFormat.mask}'
        : Formatters.signedMoney(amount, symbol: format.symbol);
    final p = percent;
    return p == null
        ? money
        : '$money (${Formatters.percent(p, signed: true)})';
  }
}
