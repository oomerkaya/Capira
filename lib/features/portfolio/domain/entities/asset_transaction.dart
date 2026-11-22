import 'package:capira/features/portfolio/domain/entities/asset_type.dart';
import 'package:decimal/decimal.dart';

/// A single buy or sell. Holdings are always derived from these.
class AssetTransaction {
  const AssetTransaction({
    required this.id,
    required this.assetId,
    required this.kind,
    required this.quantity,
    required this.date,
    this.unitPriceTry,
    this.note,
    this.usdTry,
    this.eurTry,
  });

  final int id;
  final int assetId;
  final TransactionKind kind;

  /// Always positive; [kind] gives the direction.
  final Decimal quantity;

  /// Price per unit in TRY. `null` when unknown (e.g. inherited gold).
  final Decimal? unitPriceTry;
  final DateTime date;
  final String? note;

  /// TRY per USD / EUR on the transaction's day, when known.
  final Decimal? usdTry;
  final Decimal? eurTry;

  AssetTransaction copyWith({
    TransactionKind? kind,
    Decimal? quantity,
    Decimal? Function()? unitPriceTry,
    DateTime? date,
    String? Function()? note,
    Decimal? Function()? usdTry,
    Decimal? Function()? eurTry,
  }) => AssetTransaction(
    id: id,
    assetId: assetId,
    kind: kind ?? this.kind,
    quantity: quantity ?? this.quantity,
    unitPriceTry: unitPriceTry != null ? unitPriceTry() : this.unitPriceTry,
    date: date ?? this.date,
    note: note != null ? note() : this.note,
    usdTry: usdTry != null ? usdTry() : this.usdTry,
    eurTry: eurTry != null ? eurTry() : this.eurTry,
  );
}

/// Input for a new transaction (no id yet).
class TransactionDraft {
  const TransactionDraft({
    required this.kind,
    required this.quantity,
    required this.date,
    this.unitPriceTry,
    this.note,
    this.usdTry,
    this.eurTry,
  });

  final TransactionKind kind;
  final Decimal quantity;
  final Decimal? unitPriceTry;
  final DateTime date;
  final String? note;
  final Decimal? usdTry;
  final Decimal? eurTry;
}
