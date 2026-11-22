import 'package:capira/core/database/app_database.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single app-wide database. Tests override this with an in-memory DB.
///
/// The background update (its own Flutter engine) opens its own connection
/// to the same file; WAL mode and a busy timeout (`AppDatabase.beforeOpen`)
/// make that safe. drift's isolate sharing is not used: it does not work
/// across engines, and a server owned by the short-lived background engine
/// would die with it.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'capira'));
  ref.onDispose(db.close);
  return db;
});
