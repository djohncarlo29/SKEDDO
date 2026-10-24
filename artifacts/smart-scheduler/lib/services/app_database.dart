import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Event snapshots are kept as JSON to preserve the existing ScheduledEvent
/// schema while SQLite owns collection membership and stable ordering.
class StoredEvents extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get collection => text()();
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get payload => text()();
}

/// Structured category/search documents retain their current serializers.
/// Small appearance and UI preferences intentionally remain in
/// SharedPreferences.
class StoredContent extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [StoredEvents, StoredContent])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'skeddo_local',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  static final AppDatabase instance = AppDatabase();

  @override
  int get schemaVersion => 1;
}
