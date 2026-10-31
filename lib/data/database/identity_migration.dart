import 'package:sqflite_common_ffi/sqflite_ffi.dart' show DatabaseExecutor;

/// Seed databases and restored backups can have user_version=0 even when their
/// tables already exist, so CREATE TABLE IF NOT EXISTS is not an upgrade.
Future<void> ensureIdentityColumns(DatabaseExecutor db) async {
  for (final table in ['osra', 'person']) {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    for (final column in [
      'gender',
      'governorate',
      if (table == 'osra') ...['birth_date', 'age'],
    ]) {
      if (!columns.any((c) => c['name'] == column)) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column TEXT');
      }
    }
  }
}
