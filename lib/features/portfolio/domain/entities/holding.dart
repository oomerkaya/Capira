import 'package:capira/core/domain/display_currency.dart';
import 'package:capira/features/portfolio/domain/entities/asset.dart';
import 'package:capira/features/portfolio/domain/entities/asset_transaction.dart';
import 'package:decimal/decimal.dart';

/// Current position in one asset, computed from its transactions with the
/// weighted average cost method. Cost fields are `null` when at least one
/// relevant transaction has no price.
class Holding {
  const Holding({
    required this.asset,
    required this.quantity,
    required this.transactionCount,
    this.totalCostTry,
    this.averageCostTry,
    this.realizedPnlTry,
    this.totalCostUsd,
    this.totalCostEur,
  });

  final Asset asset;
  final Decimal quantity;
  final int transactionCount;
  final Decimal? totalCostTry;
  final Decimal? averageCostTry;
  final Decimal? realizedPnlTry;

  /// Cost in USD / EUR at each buy's own rate; `null` when a buy with a
  /// price has no rate stored (entered before v5 or back-dated).
  final Decimal? totalCostUsd;
  final Decimal? totalCostEur;

  Decimal? totalCostIn(DisplayCurrency currency) => switch (currency) {
    DisplayCurrency.tryLira => totalCostTry,
    DisplayCurrency.usd => totalCostUsd,
    DisplayCurrency.eur => totalCostEur,
  };

  bool get isClosed => quantity == Decimal.zero;
}

/// An asset together with all of its transactions.
class AssetWithTransactions {
  const AssetWithTransactions({
    required this.asset,
    required this.transactions,
  });

  final Asset asset;
  final List<AssetTransaction> transactions;
}
