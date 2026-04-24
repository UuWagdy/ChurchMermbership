import '../database/database_helper.dart';
import '../models/tracking_models.dart';

class FinancialRepository {
  final _dbHelper = DatabaseHelper();

  // Fixed Aid (Count)
  Future<List<FixedAid>> getFixedAidByFamily(int osraId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'count_aid',
      where: 'osra_id = ?',
      whereArgs: [osraId],
    );
    return List.generate(maps.length, (i) => FixedAid.fromMap(maps[i]));
  }

  Future<int> insertFixedAid(FixedAid aid) async {
    final db = await _dbHelper.database;
    return await db.insert('count_aid', aid.toMap());
  }

  Future<int> updateFixedAid(FixedAid aid) async {
    final db = await _dbHelper.database;
    return await db.update(
      'count_aid',
      aid.toMap(),
      where: 'count_id = ?',
      whereArgs: [aid.countId],
    );
  }

  Future<int> deleteFixedAid(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('count_aid', where: 'count_id = ?', whereArgs: [id]);
  }

  // Variable Aid (Count_2)
  Future<List<VariableAid>> getVariableAidByFamily(int osraId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'count_2',
      where: 'osra_id = ?',
      whereArgs: [osraId],
      orderBy: 'date_1 DESC',
    );
    return List.generate(maps.length, (i) => VariableAid.fromMap(maps[i]));
  }

  Future<int> insertVariableAid(VariableAid aid) async {
    final db = await _dbHelper.database;
    return await db.insert('count_2', aid.toMap());
  }

  Future<int> updateVariableAid(VariableAid aid) async {
    final db = await _dbHelper.database;
    return await db.update(
      'count_2',
      aid.toMap(),
      where: 'count_2_id = ?',
      whereArgs: [aid.count2Id],
    );
  }

  Future<int> deleteVariableAid(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('count_2', where: 'count_2_id = ?', whereArgs: [id]);
  }

  // Expenses (Masrofat)
  Future<List<Expense>> getExpensesByFamily(int osraId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'masrofat',
      where: 'osra_id = ?',
      whereArgs: [osraId],
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await _dbHelper.database;
    return await db.insert('masrofat', expense.toMap());
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await _dbHelper.database;
    return await db.update(
      'masrofat',
      expense.toMap(),
      where: 'masrofat_id = ?',
      whereArgs: [expense.masrofatId],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('masrofat', where: 'masrofat_id = ?', whereArgs: [id]);
  }
}
