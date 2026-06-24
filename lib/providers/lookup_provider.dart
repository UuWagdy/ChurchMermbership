import 'package:flutter/material.dart';
import '../data/models/lookup_models.dart';
import '../data/repositories/lookup_repository.dart';

class LookupProvider with ChangeNotifier {
  final LookupRepository _lookupRepo = LookupRepository();

  List<Area> _areas = [];
  List<Street> _streets = [];
  List<Father> _fathers = [];
  List<Map<String, dynamic>> _karaba = [];
  List<Map<String, dynamic>> _socialStatus = [];
  List<Map<String, dynamic>> _healthStatus = [];
  List<Map<String, dynamic>> _economicStatus = [];
  List<Map<String, dynamic>> _educationLevels = [];
  List<Map<String, dynamic>> _stages = [];
  List<Map<String, dynamic>> _services = [];

  List<Area> get areas => _areas;
  List<Street> get streets => _streets;
  List<Father> get fathers => _fathers;
  List<Map<String, dynamic>> get karaba => _karaba;
  List<Map<String, dynamic>> get socialStatus => _socialStatus;
  List<Map<String, dynamic>> get healthStatus => _healthStatus;
  List<Map<String, dynamic>> get economicStatus => _economicStatus;
  List<Map<String, dynamic>> get educationLevels => _educationLevels;
  List<Map<String, dynamic>> get stages => _stages;
  List<Map<String, dynamic>> get services => _services;

  Future<void> loadAllLookups() async {
    _areas = await _lookupRepo.getAreas();
    _fathers = await _lookupRepo.getFathers();
    _karaba = await _lookupRepo.getKaraba();
    _socialStatus = await _lookupRepo.getHalaEgtimaia();
    _healthStatus = await _lookupRepo.getHalaSehia();
    _economicStatus = await _lookupRepo.getEconomicStatus();
    _educationLevels = await _lookupRepo.getEducationLevels();
    _stages = await _lookupRepo.getStages();
    _services = await _lookupRepo.getServices();
    notifyListeners();
  }

  Future<void> loadStreets(int areaId) async {
    _streets = await _lookupRepo.getStreets(areaId);
    notifyListeners();
  }

  Future<void> loadStreetsForAreas(List<int> areaIds) async {
    _streets = await _lookupRepo.getStreetsForAreas(areaIds);
    notifyListeners();
  }

  Future<void> addArea(String name) async {
    await _lookupRepo.insertArea(Area(areaName: name));
    _areas = await _lookupRepo.getAreas();
    notifyListeners();
  }

  Future<void> addStreet(String name, int areaId) async {
    await _lookupRepo.insertStreet(Street(streetName: name, areaId: areaId));
    await loadStreets(areaId);
  }

  Future<void> updateArea(int id, String name) async {
    await _lookupRepo.updateArea(Area(areaId: id, areaName: name));
    _areas = await _lookupRepo.getAreas();
    notifyListeners();
  }

  Future<void> deleteArea(int id) async {
    await _lookupRepo.deleteArea(id);
    _areas = await _lookupRepo.getAreas();
    notifyListeners();
  }

  Future<void> updateStreet(int id, String name, int areaId) async {
    await _lookupRepo.updateStreet(Street(streetId: id, streetName: name, areaId: areaId));
    await loadStreets(areaId);
  }

  Future<void> deleteStreet(int id, int areaId) async {
    await _lookupRepo.deleteStreet(id);
    await loadStreets(areaId);
  }

  Future<void> addFather(String name, String? mobile, String? birthDate) async {
    await _lookupRepo.insertFather(Father(fatherName: name, fatherMobile: mobile, birthDate: birthDate));
    _fathers = await _lookupRepo.getFathers();
    notifyListeners();
  }

  Future<void> deleteFather(int id) async {
    await _lookupRepo.deleteLookupItem('fathers', 'father_id', id);
    _fathers = await _lookupRepo.getFathers();
    notifyListeners();
  }

  Future<void> updateFather(int id, String name, String? mobile) async {
    await _lookupRepo.updateLookupItem('fathers', 'father_id', id, {
      'father_name': name,
      'father_mobile': mobile,
    });
    _fathers = await _lookupRepo.getFathers();
    notifyListeners();
  }

  Future<void> addStage(String name) async {
    await _lookupRepo.insertLookupItem('stage', {'stage_name': name});
    await loadAllLookups();
  }

  Future<void> deleteStage(int id) async {
    await _lookupRepo.deleteLookupItem('stage', 'stage_id', id);
    await loadAllLookups();
  }

  Future<void> addService(String name) async {
    await _lookupRepo.insertLookupItem('khdma', {'khdma_name': name});
    await loadAllLookups();
  }

  Future<void> deleteService(int id) async {
    await _lookupRepo.deleteLookupItem('khdma', 'khdma_id', id);
    await loadAllLookups();
  }

  Future<void> updateService(int id, String name) async {
    await _lookupRepo.updateLookupItem('khdma', 'khdma_id', id, {'khdma_name': name});
    await loadAllLookups();
  }

  Future<void> updateStage(int id, String name) async {
    await _lookupRepo.updateLookupItem('stage', 'stage_id', id, {'stage_name': name});
    await loadAllLookups();
  }

  // ═══════════════════════════════════════════
  // Karaba (القرابة)
  // ═══════════════════════════════════════════
  Future<void> addKaraba(String name) async {
    await _lookupRepo.insertLookupItem('karaba', {'karaba_name': name});
    await loadAllLookups();
  }

  Future<void> updateKaraba(int id, String name) async {
    await _lookupRepo.updateLookupItem('karaba', 'karaba_id', id, {'karaba_name': name});
    await loadAllLookups();
  }

  Future<void> deleteKaraba(int id) async {
    await _lookupRepo.deleteLookupItem('karaba', 'karaba_id', id);
    await loadAllLookups();
  }

  // ═══════════════════════════════════════════
  // Hala Egtimaia (الحالة الاجتماعية)
  // ═══════════════════════════════════════════
  Future<void> addSocialStatus(String name) async {
    await _lookupRepo.insertLookupItem('hala_egtimaia', {'hala_name': name});
    await loadAllLookups();
  }

  Future<void> updateSocialStatus(int id, String name) async {
    await _lookupRepo.updateLookupItem('hala_egtimaia', 'hala_egtimaia_id', id, {'hala_name': name});
    await loadAllLookups();
  }

  Future<void> deleteSocialStatus(int id) async {
    await _lookupRepo.deleteLookupItem('hala_egtimaia', 'hala_egtimaia_id', id);
    await loadAllLookups();
  }

  // ═══════════════════════════════════════════
  // Hala Sehia (الحالة الصحية)
  // ═══════════════════════════════════════════
  Future<void> addHealthStatus(String name) async {
    await _lookupRepo.insertLookupItem('hala_sehia', {'hala_name': name});
    await loadAllLookups();
  }

  Future<void> updateHealthStatus(int id, String name) async {
    await _lookupRepo.updateLookupItem('hala_sehia', 'hala_sehia_id', id, {'hala_name': name});
    await loadAllLookups();
  }

  Future<void> deleteHealthStatus(int id) async {
    await _lookupRepo.deleteLookupItem('hala_sehia', 'hala_sehia_id', id);
    await loadAllLookups();
  }

  // ═══════════════════════════════════════════
  // E_S (الحالة الاقتصادية)
  // ═══════════════════════════════════════════
  Future<void> addEconomicStatus(String name) async {
    await _lookupRepo.insertLookupItem('e_s', {'e_s_name': name});
    await loadAllLookups();
  }

  Future<void> updateEconomicStatus(int id, String name) async {
    await _lookupRepo.updateLookupItem('e_s', 'e_s_id', id, {'e_s_name': name});
    await loadAllLookups();
  }

  Future<void> deleteEconomicStatus(int id) async {
    await _lookupRepo.deleteLookupItem('e_s', 'e_s_id', id);
    await loadAllLookups();
  }

  // ═══════════════════════════════════════════
  // Mostwa (المستوى التعليمي)
  // ═══════════════════════════════════════════
  Future<void> addEducationLevel(String name) async {
    await _lookupRepo.insertLookupItem('mostwa', {'mostwa_name': name});
    await loadAllLookups();
  }

  Future<void> updateEducationLevel(int id, String name) async {
    await _lookupRepo.updateLookupItem('mostwa', 'mostwa_id', id, {'mostwa_name': name});
    await loadAllLookups();
  }

  Future<void> deleteEducationLevel(int id) async {
    await _lookupRepo.deleteLookupItem('mostwa', 'mostwa_id', id);
    await loadAllLookups();
  }

  String getKarabaName(int? id) {
    if (id == null) return '---';
    final match = _karaba.firstWhere((k) => k['karaba_id'] == id, orElse: () => {});
    return match['karaba_name'] ?? '---';
  }

  String getStageName(int? id) {
    if (id == null) return '---';
    final match = _stages.firstWhere((s) => s['stage_id'] == id, orElse: () => {});
    return match['stage_name'] ?? '---';
  }

  String getHalaEgtimaiaName(int? id) {
    if (id == null) return '---';
    final match = _socialStatus.firstWhere((s) => s['hala_egtimaia_id'] == id, orElse: () => {});
    return match['hala_name'] ?? '---';
  }

  String getHalaSehiaName(int? id) {
    if (id == null) return '---';
    final match = _healthStatus.firstWhere((s) => s['hala_sehia_id'] == id, orElse: () => {});
    return match['hala_name'] ?? '---';
  }

  String getEconomicStatusName(int? id) {
    if (id == null) return '---';
    final match = _economicStatus.firstWhere((s) => s['e_s_id'] == id, orElse: () => {});
    return match['e_s_name'] ?? '---';
  }

  String getEducationLevelName(int? id) {
    if (id == null) return '---';
    final match = _educationLevels.firstWhere((s) => s['mostwa_id'] == id, orElse: () => {});
    return match['mostwa_name'] ?? '---';
  }
}
