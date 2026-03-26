import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comanda_model.dart';
import '../models/occupancy_period.dart';
import '../models/user.dart';
import 'rezervare_service.dart';

export 'rezervare_service.dart'
    show RezervareOverlapException, RezervareService, Rezervare, RezervareType,
    RezervareStatus, RezervareStatusX;

class VehicleSearchResult {
  final String id;
  final String model;
  final String clasa;
  final String subclasa;
  final List<OccupancyPeriod> occupancyPeriods;

  const VehicleSearchResult({
    required this.id,
    required this.model,
    required this.clasa,
    required this.subclasa,
    this.occupancyPeriods = const [],
  });

  factory VehicleSearchResult.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return VehicleSearchResult(
      id:       doc.id,
      model:    (d['denumire_model'] ?? d['model'] ?? '').toString(),
      clasa:    (d['clasa']    ?? '').toString(),
      subclasa: (d['subclasa'] ?? '').toString(),
    );
  }

  bool isOccupied(DateTime start, DateTime end) =>
      occupancyPeriods.any((p) => p.overlapsWith(start, end));

  OccupancyPeriod? occupiedPeriod(DateTime start, DateTime end) {
    try {
      return occupancyPeriods.firstWhere((p) => p.overlapsWith(start, end));
    } catch (_) {
      return null;
    }
  }
}

// ComenzaService
class ComenzaService {
  static const Duration _timeout = Duration(seconds: 15);

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference get _vehicles => _db.collection('vehicles');

  // Streams
  static Stream<List<Comanda>> comenziStream(
      String santierId, User currentUser) {
    return RezervareService.streamBySantier(santierId, currentUser)
        .map((list) => list.map(_toComanada).toList());
  }

  static Stream<List<OccupancyPeriod>> vehicleOccupancyStream(
      String vehicleId) {
    return RezervareService.vehicleOccupancyStream(vehicleId);
  }

  // Căutare vehicule
  static Future<List<VehicleSearchResult>> searchVehicles(
      String query) async {
    if (query.trim().length < 2) return [];
    final q    = query.trim().toLowerCase();
    final snap = await _vehicles.limit(500).get().timeout(_timeout);
    return snap.docs
        .map(VehicleSearchResult.fromDoc)
        .where((v) =>
    v.model.toLowerCase().contains(q) ||
        v.clasa.toLowerCase().contains(q) ||
        v.subclasa.toLowerCase().contains(q))
        .toList();
  }

  // Creare comandă
  static Future<String> createComanda({
    required String   santierId,
    required String   santierNume,
    required DateTime santierDataIncepere,
    required String   vehicleId,
    required String   vehicleModel,
    required String   vehicleClasa,
    required DateTime dataStart,
    required DateTime dataFinal,
    required User     currentUser,
    String?           note,
    String?           santierColor,
  }) async {
    final rezervareId = await RezervareService.createComanda(
      santierId:           santierId,
      santierNume:         santierNume,
      santierDataIncepere: santierDataIncepere,
      vehicleId:           vehicleId,
      vehicleModel:        vehicleModel,
      vehicleClasa:        vehicleClasa,
      dataStart:           dataStart,
      dataFinal:           dataFinal,
      currentUser:         currentUser,
      note:                note,
      santierColor:        santierColor,
    );

    await _db.collection('comenzi').doc(rezervareId).set({
      'santierId':           santierId,
      'santierNume':         santierNume,
      'santierDataIncepere': Timestamp.fromDate(santierDataIncepere),
      'vehicleId':           vehicleId,
      'vehicleModel':        vehicleModel,
      'vehicleClasa':        vehicleClasa,
      'dataStart':           Timestamp.fromDate(dataStart),
      'dataFinal':           Timestamp.fromDate(dataFinal),
      'status':              ComandaStatus.pending.value,
      'creatDeUserId':       currentUser.uid,
      'creatDeNume':         currentUser.name,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'createdAt':           FieldValue.serverTimestamp(),
      'updatedAt':           FieldValue.serverTimestamp(),
      'rezervareId':         rezervareId,
    }).timeout(_timeout);

    return rezervareId;
  }

  // Actualizare interval
  static Future<void> updateComandaInterval({
    required Comanda         comanda,
    required OccupancyPeriod oldPeriod,
    required DateTime        newDataStart,
    required DateTime        newDataFinal,
    required String          modificatDeUserId,
    required String          modificatDeNume,
  }) async {
    await RezervareService.updateInterval(
      rezervareId:       comanda.id,
      vehicleId:         comanda.vehicleId,
      newDataStart:      newDataStart,
      newDataFinal:      newDataFinal,
      modificatDeUserId: modificatDeUserId,
    );

    await _db.collection('comenzi').doc(comanda.id).update({
      'dataStart':         Timestamp.fromDate(newDataStart),
      'dataFinal':         Timestamp.fromDate(newDataFinal),
      'updatedAt':         FieldValue.serverTimestamp(),
      'modificatDeUserId': modificatDeUserId,
    }).timeout(_timeout);
  }

  // Ștergere
  static Future<void> deleteComanda({
    required Comanda         comanda,
    required OccupancyPeriod period,
  }) async {
    await RezervareService.delete(comanda.id);
    await _db.collection('comenzi').doc(comanda.id).delete().timeout(_timeout);
  }

  // Convertor Rezervare → Comanda
  static Comanda _toComanada(Rezervare r) => Comanda(
    id:                  r.id,
    santierId:           r.santierId ?? '',
    santierNume:         r.santierNume ?? '',
    santierDataIncepere: DateTime(1970),
    vehicleId:           r.vehicleId,
    vehicleModel:        r.vehicleModel,
    vehicleClasa:        r.vehicleClasa,
    dataStart:           r.dataStart,
    dataFinal:           r.dataFinal,
    status:              _mapStatus(r.status),
    creatDeUserId:       r.creatDeUserId,
    creatDeNume:         r.creatDeNume,
    aprobatDeUserId:     r.aprobatDeUserId,
    note:                r.note,
    motivRespingere:     r.motivRespingere,
    createdAt:           r.createdAt,
    updatedAt:           r.updatedAt,
  );

  static ComandaStatus _mapStatus(RezervareStatus s) => switch (s) {
    RezervareStatus.aprobat => ComandaStatus.aprobat,
    RezervareStatus.respins => ComandaStatus.respins,
    _                       => ComandaStatus.pending,
  };
}