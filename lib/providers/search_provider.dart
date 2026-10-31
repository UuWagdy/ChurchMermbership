import 'package:flutter/material.dart';
import '../data/models/family_models.dart';
import '../data/repositories/search_repository.dart';

class SearchProvider with ChangeNotifier {
  final SearchRepository _searchRepo = SearchRepository();
  List<Family> _results = [];
  bool _isLoading = false;
  int _generation = 0;
  String? error;

  List<Family> get results => _results;
  bool get isLoading => _isLoading;

  Future<void> performSearch({
    bool expensesOnly = false,
    List<int>? areaIds,
    int? streetId,
    String? mobile,
    List<String>? birthMonths,
    int? personCount,
    List<int>? socialStatusIds,
    List<int>? economicStatusIds,
    List<int>? stageIds,
    String? job,
    int? ageMin,
    int? ageMax,
    String? name,
    List<int>? healthStatusIds,
    int? fatherId,
    List<int>? mostwaIds,
    List<int>? karabaIds,
    String? nidGov,
    String? nidGender,
    int? nidAgeMin,
    int? nidAgeMax,
    String? nidBirthDateMin,
    String? nidBirthDateMax,
  }) async {
    final generation = ++_generation;
    error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final maps = await _searchRepo.complexSearch(
        expensesOnly: expensesOnly,
        areaIds: areaIds,
        streetId: streetId,
        mobile: mobile,
        birthMonths: birthMonths,
        personCount: personCount,
        socialStatusIds: socialStatusIds,
        economicStatusIds: economicStatusIds,
        stageIds: stageIds,
        job: job,
        ageMin: ageMin,
        ageMax: ageMax,
        name: name,
        healthStatusIds: healthStatusIds,
        fatherId: fatherId,
        mostwaIds: mostwaIds,
        karabaIds: karabaIds,
        nidGov: nidGov,
        nidGender: nidGender,
        nidAgeMin: nidAgeMin,
        nidAgeMax: nidAgeMax,
        nidBirthDateMin: nidBirthDateMin,
        nidBirthDateMax: nidBirthDateMax,
      );
      if (generation != _generation) return;
      _results = maps.map((m) => Family.fromMap(m)).toList();
    } catch (e) {
      if (generation != _generation) return;
      error = 'تعذر تنفيذ البحث. تحقق من الاتصال وحاول مرة أخرى';
      debugPrint('Search error: $e');
      _results = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearResults() {
    _generation++;
    _isLoading = false;
    error = null;
    _results = [];
    notifyListeners();
  }

  Future<List<Person>> searchPersons({
    String? name,
    String? nationalId,
    String? mobile,
    String? job,
    int? areaId,
    int? streetId,
    int? socialStatusId,
    int? economicStatusId,
    int? stageId,
    int? healthStatusId,
    int? mostwaId,
    int? karabaId,
  }) async {
    try {
      final maps = await _searchRepo.searchPersons(
        name: name,
        nationalId: nationalId,
        mobile: mobile,
        job: job,
        areaId: areaId,
        streetId: streetId,
        socialStatusId: socialStatusId,
        economicStatusId: economicStatusId,
        stageId: stageId,
        healthStatusId: healthStatusId,
        mostwaId: mostwaId,
        karabaId: karabaId,
      );
      return maps.map((m) => Person.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Person search error: $e');
      return [];
    }
  }
}
