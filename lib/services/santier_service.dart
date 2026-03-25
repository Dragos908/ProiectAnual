import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/santier_model.dart';

class SantierService {
  static const Duration _timeout    = Duration(seconds: 15);
  static const String   _collection = 'santiere';

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Santierele utilizatorului curent.
  static Stream<List<Santier>> streamByUser(String uid) {
    return _db
        .collection(_collection)
        .where('creatDeUserId', isEqualTo: uid)
        .snapshots()
        .map((snap) =>
        _sorted(snap.docs.map(Santier.fromDoc).toList()));
  }

  /// Un singur santier după ID.
  static Stream<Santier?> streamById(String santierId) {
    return _db
        .collection(_collection)
        .doc(santierId)
        .snapshots()
        .map((snap) => snap.exists ? Santier.fromDoc(snap) : null);
  }

  static List<Santier> _sorted(List<Santier> list) {
    list.sort((a, b) {
      final sc = a.status.sortPriority.compareTo(b.status.sortPriority);
      if (sc != 0) return sc;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  /// Creează santier nou. Culoarea este atribuită ciclic din paletă dacă
  /// nu e furnizată explicit. Returnează ID-ul documentului.
  static Future<String> createSantier({
    required String   denumire,
    required String   locatie,
    DateTime?         dataIncepere,
    DateTime?         dataFinalizare,
    required String   creatDeUserId,
    required String   creatDeNume,
    String?           color,
  }) async {
    final effectiveColor = color ?? await _nextColor();

    final data = <String, dynamic>{
      'denumire': denumire.trim(),
      'locatie':  locatie.trim(),
      if (dataIncepere   != null)
        'dataIncepere':   Timestamp.fromDate(dataIncepere),
      if (dataFinalizare != null)
        'dataFinalizare': Timestamp.fromDate(dataFinalizare),
      'status':          SantierStatus.activ.value,
      'creatDeUserId':   creatDeUserId,
      'creatDeNume':     creatDeNume,
      'color':           effectiveColor,
      'createdAt':       FieldValue.serverTimestamp(),
      'updatedAt':       FieldValue.serverTimestamp(),
    };

    final docRef = await _db
        .collection(_collection)
        .add(data)
        .timeout(_timeout);
    return docRef.id;
  }

  /// Actualizează câmpurile editabile.
  static Future<void> updateSantier({
    required String   santierId,
    required String   denumire,
    required String   locatie,
    DateTime?         dataIncepere,
    DateTime?         dataFinalizare,
    required String   modificatDeUserId,
    String?           color,
  }) async {
    await _db.collection(_collection).doc(santierId).update({
      'denumire': denumire.trim(),
      'locatie':  locatie.trim(),
      if (dataIncepere   != null)
        'dataIncepere':   Timestamp.fromDate(dataIncepere),
      if (dataFinalizare != null)
        'dataFinalizare': Timestamp.fromDate(dataFinalizare),
      if (color          != null) 'color': color,
      'updatedAt':         FieldValue.serverTimestamp(),
      'modificatDeUserId': modificatDeUserId,
    }).timeout(_timeout);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<String> _nextColor() async {
    try {
      final snap = await _db
          .collection(_collection)
          .count()
          .get()
          .timeout(_timeout);
      return santierColorForIndex(snap.count ?? 0);
    } catch (_) {
      return kSantierColorPalette.first;
    }
  }
}