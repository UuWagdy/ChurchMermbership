import 'package:flutter/material.dart';
import '../data/models/family_models.dart';
import '../data/repositories/family_repository.dart';

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
}
