import 'package:flutter/material.dart';
import '../data/models/tracking_models.dart';
import '../data/repositories/tracking_repository.dart';

class TrackingProvider with ChangeNotifier {
  final TrackingRepository _trackingRepo = TrackingRepository();

  List<Confession> _confessions = [];
  List<Visit> _visits = [];
  List<Occasion> _occasions = [];
  bool _isLoading = false;

  int? _lastPersonId;
  int? _lastOsraId;

  List<Confession> get confessions => _confessions;
  List<Visit> get visits => _visits;
  List<Occasion> get occasions => _occasions;
  bool get isLoading => _isLoading;

  Future<void> refreshSilently() async {
    if (_lastPersonId != null) {
      _confessions = await _trackingRepo.getConfessionsByPerson(_lastPersonId!);
    }
    if (_lastOsraId != null) {
      _visits = await _trackingRepo.getVisitsByFamily(_lastOsraId!);
      _occasions = await _trackingRepo.getOccasionsByFamily(_lastOsraId!);
    }
    notifyListeners();
  }

  Future<void> loadConfessions(int personId) async {
    _lastPersonId = personId;
    _isLoading = true;
    notifyListeners();
    _confessions = await _trackingRepo.getConfessionsByPerson(personId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addConfession(int personId, String notes) async {
    _lastPersonId = personId;
    final confession = Confession(
      personId: personId,
      date: DateTime.now().toIso8601String(),
      notes: notes,
    );
    await _trackingRepo.insertConfession(confession);
    await loadConfessions(personId);
  }

  Future<void> updateConfession(Confession confession) async {
    _lastPersonId = confession.personId;
    await _trackingRepo.updateConfession(confession);
    await loadConfessions(confession.personId);
  }

  Future<void> deleteConfession(int id, int personId) async {
    _lastPersonId = personId;
    await _trackingRepo.deleteConfession(id);
    await loadConfessions(personId);
  }

  Future<void> loadVisits(int osraId) async {
    _lastOsraId = osraId;
    _isLoading = true;
    notifyListeners();
    _visits = await _trackingRepo.getVisitsByFamily(osraId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addVisit(int osraId, String notes) async {
    _lastOsraId = osraId;
    final visit = Visit(
      osraId: osraId,
      date: DateTime.now().toIso8601String(),
      notes: notes,
    );
    await _trackingRepo.insertVisit(visit);
    await loadVisits(osraId);
  }

  Future<void> addVisitWithDate(int osraId, String notes, DateTime date) async {
    _lastOsraId = osraId;
    final visit = Visit(
      osraId: osraId,
      date: date.toIso8601String(),
      notes: notes,
    );
    await _trackingRepo.insertVisit(visit);
    await loadVisits(osraId);
  }

  Future<void> addBatchVisits({required List<int> osraIds, required String notes, required DateTime date}) async {
    _isLoading = true;
    notifyListeners();
    await _trackingRepo.addBatchVisits(osraIds, date.toIso8601String(), notes);
    if (_lastOsraId != null && osraIds.contains(_lastOsraId)) {
      _visits = await _trackingRepo.getVisitsByFamily(_lastOsraId!);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteVisit(int visitId, int osraId) async {
    _lastOsraId = osraId;
    await _trackingRepo.deleteVisit(visitId);
    await loadVisits(osraId);
  }

  Future<void> loadOccasions(int osraId) async {
    _lastOsraId = osraId;
    _occasions = await _trackingRepo.getOccasionsByFamily(osraId);
    notifyListeners();
  }

  Future<void> addOccasion(int osraId, String name, DateTime date) async {
    _lastOsraId = osraId;
    final occasion = Occasion(
      osraId: osraId,
      monasbaName: name,
      monasbaDate: date.toIso8601String(),
      month: date.month.toString(),
    );
    await _trackingRepo.insertOccasion(occasion);
    await loadOccasions(osraId);
  }

  Future<void> updateOccasion(Occasion occasion) async {
    _lastOsraId = occasion.osraId;
    await _trackingRepo.updateOccasion(occasion);
    await loadOccasions(occasion.osraId);
  }

  Future<void> deleteOccasion(int id, int osraId) async {
    _lastOsraId = osraId;
    await _trackingRepo.deleteOccasion(id);
    await loadOccasions(osraId);
  }
}
