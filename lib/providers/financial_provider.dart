import 'package:flutter/material.dart';
import '../data/models/tracking_models.dart';
import '../data/repositories/financial_repository.dart';

class FinancialProvider with ChangeNotifier {
  final FinancialRepository _financialRepo = FinancialRepository();

  List<FixedAid> _fixedAids = [];
  List<VariableAid> _variableAids = [];
  List<Expense> _expenses = [];
  bool _isLoading = false;
  int? _lastFamilyId;
  int _generation = 0;
  String? _error;
  String? get error => _error;

  List<FixedAid> get fixedAids => _fixedAids;
  List<VariableAid> get variableAids => _variableAids;
  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;
  int? get lastFamilyId => _lastFamilyId;

  Future<void> loadFinancials(int osraId) async {
    final generation = ++_generation;
    _lastFamilyId = osraId;
    _isLoading = true;
    _error = null;
    _fixedAids = [];
    _variableAids = [];
    _expenses = [];
    notifyListeners();
    try {
      final results = await Future.wait([
        _financialRepo.getFixedAidByFamily(osraId),
        _financialRepo.getVariableAidByFamily(osraId),
        _financialRepo.getExpensesByFamily(osraId),
      ]);
      if (generation != _generation) return;
      if (generation != _generation) return;
      _fixedAids = results[0] as List<FixedAid>;
      _variableAids = results[1] as List<VariableAid>;
      _expenses = results[2] as List<Expense>;
    } catch (e) {
      if (generation != _generation) return;
      _error = 'تعذر تحميل البيانات. تحقق من الاتصال';
      debugPrint('Financial load failed: $e');
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshSilently() async {
    final generation = _generation;
    final osraId = _lastFamilyId;
    if (osraId == null) return;
    try {
      final results = await Future.wait([
        _financialRepo.getFixedAidByFamily(osraId),
        _financialRepo.getVariableAidByFamily(osraId),
        _financialRepo.getExpensesByFamily(osraId),
      ]);
      if (generation != _generation) return;
      _fixedAids = results[0] as List<FixedAid>;
      _variableAids = results[1] as List<VariableAid>;
      _expenses = results[2] as List<Expense>;
      notifyListeners();
    } catch (e) {
      debugPrint('Error in FinancialProvider.refreshSilently: $e');
    }
  }

  Future<void> addFixedAid(FixedAid aid) async {
    await _financialRepo.insertFixedAid(aid);
    await loadFinancials(aid.osraId);
  }

  Future<void> addVariableAid(VariableAid aid) async {
    await _financialRepo.insertVariableAid(aid);
    await loadFinancials(aid.osraId);
  }

  Future<void> addExpense(Expense expense) async {
    await _financialRepo.insertExpense(expense);
    await loadFinancials(expense.osraId);
  }

  Future<void> updateFixedAid(FixedAid aid) async {
    await _financialRepo.updateFixedAid(aid);
    await loadFinancials(aid.osraId);
  }

  Future<void> deleteFixedAid(int id, int osraId) async {
    await _financialRepo.deleteFixedAid(id);
    await loadFinancials(osraId);
  }

  Future<void> updateVariableAid(VariableAid aid) async {
    await _financialRepo.updateVariableAid(aid);
    await loadFinancials(aid.osraId);
  }

  Future<void> deleteVariableAid(int id, int osraId) async {
    await _financialRepo.deleteVariableAid(id);
    await loadFinancials(osraId);
  }

  Future<void> updateExpense(Expense expense) async {
    await _financialRepo.updateExpense(expense);
    await loadFinancials(expense.osraId);
  }

  Future<void> deleteExpense(int id, int osraId) async {
    await _financialRepo.deleteExpense(id);
    await loadFinancials(osraId);
  }

  double calculateTotalAids() {
    double total = 0;
    for (var a in _fixedAids) {
      total += a.countValue;
    }
    for (var a in _variableAids) {
      total += a.countAdd;
    }
    return total;
  }

  double calculateTotalExpenses() {
    double total = 0;
    for (var e in _expenses) {
      total += e.countValue;
    }
    return total;
  }
}
