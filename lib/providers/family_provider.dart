import 'package:flutter/material.dart';
import '../data/models/family_models.dart';
import '../data/repositories/family_repository.dart';
import '../data/repositories/search_repository.dart';

class FamilyProvider with ChangeNotifier {
  final FamilyRepository _familyRepo = FamilyRepository();
  final PersonRepository _personRepo = PersonRepository();

  List<Family> _families = [];
  bool _isLoading = false;
  int _loadGeneration = 0;
  String? error;
  Family? _selectedFamily;
  List<Person> _selectedFamilyMembers = [];
  Future<List<Family>> Function()? _lastFetchAction;

  List<Family> get families => _families;
  bool get isLoading => _isLoading;
  Family? get selectedFamily => _selectedFamily;
  List<Person> get selectedFamilyMembers => _selectedFamilyMembers;

  void setSelectedFamily(Family? family) {
    _selectedFamily = family;
    notifyListeners();
  }

  Future<void> loadFamilies({String? query}) async {
    final generation = ++_loadGeneration;
    _lastFetchAction = () => _familyRepo.getFamilies(query: query);
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      final families = await _familyRepo.getFamilies(query: query);
      if (generation != _loadGeneration) return;
      _families = families;
    } catch (e) {
      if (generation != _loadGeneration) return;
      error = 'تعذر تحميل الأسر. تحقق من الاتصال وحاول مرة أخرى';
      _families = [];
    } finally {
      if (generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
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
    final generation = ++_loadGeneration;
    error = null;
    _lastFetchAction = () async {
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
      return maps.map((m) => Family.fromMap(m)).toList();
    };

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
      if (generation != _loadGeneration) return;
      _families = maps.map((m) => Family.fromMap(m)).toList();
    } catch (e) {
      if (generation != _loadGeneration) return;
      error = 'تعذر تنفيذ البحث. تحقق من الاتصال وحاول مرة أخرى';
      debugPrint('Error loading families with filters: $e');
      _families = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshSilently() async {
    try {
      if (_lastFetchAction != null) {
        _families = await _lastFetchAction!();
      } else {
        _families = await _familyRepo.getFamilies();
      }
      if (_selectedFamily?.osraId != null) {
        _selectedFamily = await _familyRepo.getFamilyById(
          _selectedFamily!.osraId!,
        );
        if (_selectedFamily == null) {
          _selectedFamilyMembers = [];
          notifyListeners();
          return;
        }
        _selectedFamilyMembers = await _personRepo.getPersonsByFamily(
          _selectedFamily!.osraId!,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error in FamilyProvider.refreshSilently: $e');
    }
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

  Future<List<Person>> getAllPersons() => _personRepo.getAllPersons();

  Future<List<Person>> getPersons(int osraId) async {
    return await _personRepo.getPersonsByFamily(osraId);
  }

  Future<void> savePerson(Person person) async {
    if (person.personId == null) {
      await _personRepo.insertPerson(person);
    } else {
      await _personRepo.updatePerson(person);
    }
    if (_selectedFamily?.osraId == person.osraId) {
      _selectedFamilyMembers = await _personRepo.getPersonsByFamily(
        person.osraId,
      );
    }
    notifyListeners();
  }

  Future<void> deletePerson(int personId) async {
    await _personRepo.deletePerson(personId);
    if (_selectedFamily?.osraId != null) {
      _selectedFamilyMembers = await _personRepo.getPersonsByFamily(
        _selectedFamily!.osraId!,
      );
    }
    notifyListeners();
  }

  Future<List<Person>> getBirthdays(int month) async {
    return await _personRepo.getPersonsByBirthMonth(month);
  }

  Future<List<Map<String, dynamic>>> getSummaryReport() async {
    return await _familyRepo.getSummaryReport();
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

  Future<List<Map<String, dynamic>>> getFamiliesWithLastVisit(
    List<int> areaIds,
  ) async {
    return await _familyRepo.getFamiliesWithLastVisit(areaIds);
  }
}
