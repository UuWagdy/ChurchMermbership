import 'package:flutter/material.dart';
import '../data/models/family_models.dart';
import '../data/repositories/family_repository.dart';
import '../data/repositories/search_repository.dart';

class FamilyProvider with ChangeNotifier {
  final FamilyRepository _familyRepo = FamilyRepository();
  final PersonRepository _personRepo = PersonRepository();

  List<Family> _families = [];
  bool _isLoading = false;

  List<Family> get families => _families;
  bool get isLoading => _isLoading;

  Future<void> loadFamilies({String? query}) async {
    _isLoading = true;
    notifyListeners();
    _families = await _familyRepo.getFamilies(query: query);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadFamiliesWithComplexFilters({
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
    _isLoading = true;
    notifyListeners();
    try {
      final searchRepo = SearchRepository();
      final maps = await searchRepo.complexSearch(
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
      _families = maps.map((m) => Family.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error loading families with filters: $e');
      _families = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveFamily(Family family) async {
    if (family.osraId == null) {
      await _familyRepo.insertFamily(family);
    } else {
      await _familyRepo.updateFamily(family);
    }
    await loadFamilies();
  }

  Future<void> deleteFamily(int id) async {
    await _familyRepo.deleteFamily(id);
    await loadFamilies();
  }

  Future<List<Person>> getPersons(int osraId) async {
    return await _personRepo.getPersonsByFamily(osraId);
  }

  Future<void> savePerson(Person person) async {
    if (person.personId == null) {
      await _personRepo.insertPerson(person);
    } else {
      await _personRepo.updatePerson(person);
    }
  }

  Future<void> deletePerson(int personId) async {
    await _personRepo.deletePerson(personId);
  }

  Future<List<Person>> getBirthdays(int month) async {
    _isLoading = true;
    notifyListeners();
    final persons = await _personRepo.getPersonsByBirthMonth(month);
    _isLoading = false;
    notifyListeners();
    return persons;
  }

  Future<List<Map<String, dynamic>>> getSummaryReport() async {
    _isLoading = true;
    notifyListeners();
    final report = await _familyRepo.getSummaryReport();
    _isLoading = false;
    notifyListeners();
    return report;
  }

  // Calculate age logic matching original C# (Year*365 + Month*30 + Day comparison)
  String calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    
    if (months < 0) {
      years--;
      months += 12;
    }
    
    return '$years سنة و $months شهر';
  }

  Future<List<Person>> getPersonsByStage(int stageId) async {
    return await _personRepo.getPersonsByStage(stageId);
  }

  Future<void> promotePersonsStage(List<int> personIds, int toStageId) async {
    await _personRepo.promotePersonsStage(personIds, toStageId);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getFamiliesWithLastVisit(List<int> areaIds) async {
    return await _familyRepo.getFamiliesWithLastVisit(areaIds);
  }
}
