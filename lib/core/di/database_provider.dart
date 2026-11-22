import 'package:capira/core/database/app_database.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single app-wide database. Tests override this with an in-memory DB.
///
/// Shared across isolates: when the background update runs while the app
/// is open, both use one database server (no lock conflicts, and the app's
/// screens see the new rows at once).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(
    driftDatabase(
      name: 'capira',
      native: const DriftNativeOptions(shareAcrossIsolates: true),
    ),
  );
  ref.onDispose(db.close);
  return db;
});
