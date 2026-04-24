import 'package:flutter/material.dart';
import '../data/models/tracking_models.dart';
import '../data/repositories/financial_repository.dart';

class FinancialProvider with ChangeNotifier {
  final FinancialRepository _financialRepo = FinancialRepository();

  List<FixedAid> _fixedAids = [];
  List<VariableAid> _variableAids = [];
  List<Expense> _expenses = [];
  bool _isLoading = false;

  List<FixedAid> get fixedAids => _fixedAids;
  List<VariableAid> get variableAids => _variableAids;
  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;

  Future<void> loadFinancials(int osraId) async {
    _isLoading = true;
    notifyListeners();
    _fixedAids = await _financialRepo.getFixedAidByFamily(osraId);
    _variableAids = await _financialRepo.getVariableAidByFamily(osraId);
    _expenses = await _financialRepo.getExpensesByFamily(osraId);
    _isLoading = false;
    notifyListeners();
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
