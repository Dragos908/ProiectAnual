import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/santier_model.dart';

class SantierService {
  static const Duration _timeout    = Duration(seconds: 15);
  static const String   _collection = 'santiere';

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference get _col => _db.collection(_collection);

  // Streams
  static Stream<List<Santier>> streamAll() => _col
      .snapshots()
      .map((s) => _sorted(s.docs.map(Santier.fromDoc).toList()));

  static Stream<List<Santier>> streamByUser(String uid) => _col
      .snapshots()
      .map((s) => _sorted(s.docs.map(Santier.fromDoc).toList()));

  static Stream<Santier?> streamById(String santierId) => _col
      .doc(santierId)
      .snapshots()
      .map((s) => s.exists ? Santier.fromDoc(s) : null);

  static List<Santier> _sorted(List<Santier> list) {
    list.sort((a, b) {
      final byStatus = a.status.sortPriority.compareTo(b.status.sortPriority);
      return byStatus != 0 ? byStatus : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  // CRUD
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
    final docRef = await _col.add({
      'denumire':        denumire.trim(),
      'locatie':         locatie.trim(),
      if (dataIncepere   != null) 'dataIncepere':   Timestamp.fromDate(dataIncepere),
      if (dataFinalizare != null) 'dataFinalizare': Timestamp.fromDate(dataFinalizare),
      'status':          SantierStatus.activ.value,
      'creatDeUserId':   creatDeUserId,
      'creatDeNume':     creatDeNume,
      'color':           effectiveColor,
      'createdAt':       FieldValue.serverTimestamp(),
      'updatedAt':       FieldValue.serverTimestamp(),
    }).timeout(_timeout);
    return docRef.id;
  }

  static Future<void> updateSantier({
    required String   santierId,
    required String   denumire,
    required String   locatie,
    DateTime?         dataIncepere,
    DateTime?         dataFinalizare,
    required String   modificatDeUserId,
    String?           color,
  }) async {
    await _col.doc(santierId).update({
      'denumire':          denumire.trim(),
      'locatie':           locatie.trim(),
      if (dataIncepere   != null) 'dataIncepere':   Timestamp.fromDate(dataIncepere),
      if (dataFinalizare != null) 'dataFinalizare': Timestamp.fromDate(dataFinalizare),
      if (color          != null) 'color':           color,
      'updatedAt':         FieldValue.serverTimestamp(),
      'modificatDeUserId': modificatDeUserId,
    }).timeout(_timeout);
  }

  // Helpers
  static Future<String> _nextColor() async {
    try {
      final snap = await _col.count().get().timeout(_timeout);
      return santierColorForIndex(snap.count ?? 0);
    } catch (_) {
      return kSantierColorPalette.first;
    }
  }
}