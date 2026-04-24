import 'package:flutter/material.dart';
import '../data/models/tracking_models.dart';
import '../data/repositories/tracking_repository.dart';

class TrackingProvider with ChangeNotifier {
  final TrackingRepository _trackingRepo = TrackingRepository();

  List<Confession> _confessions = [];
  List<Visit> _visits = [];
  List<Occasion> _occasions = [];
  bool _isLoading = false;

  List<Confession> get confessions => _confessions;
  List<Visit> get visits => _visits;
  List<Occasion> get occasions => _occasions;
  bool get isLoading => _isLoading;

  Future<void> loadConfessions(int personId) async {
    _isLoading = true;
    notifyListeners();
    _confessions = await _trackingRepo.getConfessionsByPerson(personId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addConfession(int personId, String notes) async {
    final confession = Confession(
      personId: personId,
      date: DateTime.now().toIso8601String(),
      notes: notes,
    );
    await _trackingRepo.insertConfession(confession);
    await loadConfessions(personId);
  }

  Future<void> loadVisits(int osraId) async {
    _isLoading = true;
    notifyListeners();
    _visits = await _trackingRepo.getVisitsByFamily(osraId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addVisit(int osraId, String notes) async {
    final visit = Visit(
      osraId: osraId,
      date: DateTime.now().toIso8601String(),
      notes: notes,
    );
    await _trackingRepo.insertVisit(visit);
    await loadVisits(osraId);
  }

  Future<void> loadOccasions(int osraId) async {
    _occasions = await _trackingRepo.getOccasionsByFamily(osraId);
    notifyListeners();
  }

  Future<void> addOccasion(int osraId, String name, DateTime date) async {
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
    await _trackingRepo.updateOccasion(occasion);
    await loadOccasions(occasion.osraId);
  }

  Future<void> deleteOccasion(int id, int osraId) async {
    await _trackingRepo.deleteOccasion(id);
    await loadOccasions(osraId);
  }
}
