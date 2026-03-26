import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/occupancy_period.dart';
import '../models/user.dart';

// Enums
enum RezervareType { comanda }

enum RezervareStatus { pending, aprobat, respins }

extension RezervareStatusX on RezervareStatus {
  String get value => name;

  static RezervareStatus from(String? v) => switch (v) {
    'aprobat' => RezervareStatus.aprobat,
    'respins' => RezervareStatus.respins,
    _         => RezervareStatus.pending,
  };
}

// Rezervare
class Rezervare {
  final String          id;
  final RezervareType   tip;
  final RezervareStatus status;
  final String vehicleId;
  final String vehicleModel;
  final String vehicleClasa;
  final String? santierId;
  final String? santierNume;
  final String? santierColor;
  final String? comenzaId;
  final DateTime dataStart;
  final DateTime dataFinal;
  final String? note;
  final String  creatDeUserId;
  final String  creatDeNume;
  final String? aprobatDeUserId;
  final String? respinsDe;
  final String? motivRespingere;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Rezervare({
    required this.id,
    required this.tip,
    required this.status,
    required this.vehicleId,
    required this.vehicleModel,
    required this.vehicleClasa,
    this.santierId,
    this.santierNume,
    this.santierColor,
    this.comenzaId,
    required this.dataStart,
    required this.dataFinal,
    this.note,
    required this.creatDeUserId,
    required this.creatDeNume,
    this.aprobatDeUserId,
    this.respinsDe,
    this.motivRespingere,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Rezervare.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime)  return v;
      return DateTime(1970);
    }
    return Rezervare(
      id:              doc.id,
      tip:             RezervareType.comanda,
      status:          RezervareStatusX.from(d['status'] as String?),
      vehicleId:       (d['vehicleId']    ?? '').toString(),
      vehicleModel:    (d['vehicleModel'] ?? '').toString(),
      vehicleClasa:    (d['vehicleClasa'] ?? '').toString(),
      santierId:       d['santierId']    as String?,
      santierNume:     d['santierNume']  as String?,
      santierColor:    d['santierColor'] as String?,
      comenzaId:       d['comenzaId']    as String?,
      dataStart:       ts(d['dataStart']),
      dataFinal:       ts(d['dataFinal']),
      note:            d['note']         as String?,
      creatDeUserId:   (d['creatDeUserId'] ?? '').toString(),
      creatDeNume:     (d['creatDeNume']   ?? '').toString(),
      aprobatDeUserId: d['aprobatDeUserId'] as String?,
      respinsDe:       d['respinsDe']       as String?,
      motivRespingere: d['motivRespingere'] as String?,
      createdAt:       ts(d['createdAt']),
      updatedAt:       ts(d['updatedAt']),
    );
  }

  OccupancyPeriod toOccupancyPeriod() => OccupancyPeriod(
    from:         dataStart,
    to:           dataFinal,
    rentedBy:     creatDeNume,
    santierId:    santierId ?? '',
    comenzaId:    comenzaId ?? id,
    status:       status.value,
    santierColor: santierColor,
  );

  bool get isComanda => true;
  bool get isPending  => status == RezervareStatus.pending;
  bool get isAprobat  => status == RezervareStatus.aprobat;
  bool get isRespins  => status == RezervareStatus.respins;
}

// RezervareService
class RezervareService {
  static const Duration _timeout = Duration(seconds: 15);

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference get _rezervari => _db.collection('rezervari');
  static CollectionReference get _vehicles  => _db.collection('vehicles');
  static CollectionReference get _santiere  => _db.collection('santiere');

  // Streams
  static Stream<List<Rezervare>> streamByVehicle(String vehicleId) =>
      _rezervari
          .where('vehicleId', isEqualTo: vehicleId)
          .snapshots()
          .map((s) => s.docs.map(Rezervare.fromDoc).toList());

  static Stream<List<OccupancyPeriod>> vehicleOccupancyStream(String vehicleId) =>
      streamByVehicle(vehicleId)
          .map((list) => list.map((r) => r.toOccupancyPeriod()).toList());

  static Stream<List<Rezervare>> streamBySantier(String santierId, User currentUser) =>
      _rezervari
          .where('santierId', isEqualTo: santierId)
          .where('tip', isEqualTo: 'comanda')
          .snapshots()
          .map((s) {
        final list = s.docs.map(Rezervare.fromDoc).toList();
        list.sort((a, b) => a.dataStart.compareTo(b.dataStart));
        return list;
      });

  // Creare
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
    String?           comenzaId,
  }) async {
    final vSnap = await _vehicles.doc(vehicleId).get().timeout(_timeout);
    if (!vSnap.exists) throw Exception('Vehiculul nu mai există în baza de date.');

    await _assertNoOverlap(vehicleId, dataStart, dataFinal, excludeId: null);

    final effectiveColor = santierColor ?? await _getSantierColor(santierId);
    final ref = _rezervari.doc();

    await ref.set({
      'tip':                 'comanda',
      'status':              RezervareStatus.pending.value,
      'vehicleId':           vehicleId,
      'vehicleModel':        vehicleModel,
      'vehicleClasa':        vehicleClasa,
      'santierId':           santierId,
      'santierNume':         santierNume,
      'santierDataIncepere': Timestamp.fromDate(santierDataIncepere),
      if (effectiveColor != null) 'santierColor': effectiveColor,
      if (comenzaId != null)      'comenzaId':    comenzaId,
      'dataStart':      Timestamp.fromDate(dataStart),
      'dataFinal':      Timestamp.fromDate(dataFinal),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'creatDeUserId':  currentUser.uid,
      'creatDeNume':    currentUser.name,
      'createdAt':      FieldValue.serverTimestamp(),
      'updatedAt':      FieldValue.serverTimestamp(),
    }).timeout(_timeout);

    return ref.id;
  }

  // Actualizare
  static Future<void> updateInterval({
    required String   rezervareId,
    required String   vehicleId,
    required DateTime newDataStart,
    required DateTime newDataFinal,
    required String   modificatDeUserId,
  }) async {
    await _assertNoOverlap(vehicleId, newDataStart, newDataFinal, excludeId: rezervareId);
    await _rezervari.doc(rezervareId).update({
      'dataStart':         Timestamp.fromDate(newDataStart),
      'dataFinal':         Timestamp.fromDate(newDataFinal),
      'updatedAt':         FieldValue.serverTimestamp(),
      'modificatDeUserId': modificatDeUserId,
    }).timeout(_timeout);
  }

  // Ștergere
  static Future<void> delete(String rezervareId) =>
      _rezervari.doc(rezervareId).delete().timeout(_timeout);

  // Verificare disponibilitate
  static Future<Rezervare?> checkOverlap(
      String vehicleId, DateTime start, DateTime end, {String? excludeId}
      ) async {
    final snap = await _rezervari
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', whereIn: ['pending', 'aprobat'])
        .get()
        .timeout(_timeout);

    for (final doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final r = Rezervare.fromDoc(doc);
      if (!r.dataStart.isAfter(end) && !r.dataFinal.isBefore(start)) return r;
    }
    return null;
  }

  // Helpers
  static Future<void> _assertNoOverlap(
      String vehicleId, DateTime start, DateTime end, {required String? excludeId}
      ) async {
    final conflict = await checkOverlap(vehicleId, start, end, excludeId: excludeId);
    if (conflict != null) throw RezervareOverlapException(conflict);
  }

  static Future<String?> _getSantierColor(String santierId) async {
    try {
      final snap = await _santiere.doc(santierId).get().timeout(_timeout);
      if (!snap.exists) return null;
      return (snap.data() as Map<String, dynamic>)['color'] as String?;
    } catch (_) {
      return null;
    }
  }
}

// RezervareOverlapException
class RezervareOverlapException implements Exception {
  final Rezervare conflicting;
  const RezervareOverlapException(this.conflicting);

  @override
  String toString() =>
      'Interval suprapus: ${conflicting.dataStart} – ${conflicting.dataFinal} '
          '(${conflicting.status.name})';
}