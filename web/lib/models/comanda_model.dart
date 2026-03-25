import 'package:cloud_firestore/cloud_firestore.dart';

// ─── ComandaStatus ────────────────────────────────────────────────────────────

enum ComandaStatus {
  pending,
  aprobat,
  respins;

  String get value {
    switch (this) {
      case ComandaStatus.pending:
        return 'pending';
      case ComandaStatus.aprobat:
        return 'aprobat';
      case ComandaStatus.respins:
        return 'respins';
    }
  }

  static ComandaStatus fromString(String v) {
    switch (v) {
      case 'aprobat':
        return ComandaStatus.aprobat;
      case 'respins':
        return ComandaStatus.respins;
      default:
        return ComandaStatus.pending;
    }
  }

  String get displayLabel {
    switch (this) {
      case ComandaStatus.pending:
        return 'În așteptare';
      case ComandaStatus.aprobat:
        return 'Aprobat';
      case ComandaStatus.respins:
        return 'Respins';
    }
  }
}

// ─── ComandaVizibilitate — derived display category ───────────────────────────

enum ComandaVizibilitate { activActiv, activPlanificat, neaprobatPending }

// ─── Comanda ──────────────────────────────────────────────────────────────────

class Comanda {
  final String id;
  final String santierId;
  final String santierNume;
  final DateTime santierDataIncepere;
  final String vehicleId;
  final String vehicleModel;
  final String vehicleClasa;
  final DateTime dataStart;
  final DateTime dataFinal;
  final ComandaStatus status;
  final String creatDeUserId;
  final String creatDeNume;
  final String? motivRespingere;
  final String? aprobatDeUserId;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Comanda({
    required this.id,
    required this.santierId,
    required this.santierNume,
    required this.santierDataIncepere,
    required this.vehicleId,
    required this.vehicleModel,
    required this.vehicleClasa,
    required this.dataStart,
    required this.dataFinal,
    required this.status,
    required this.creatDeUserId,
    required this.creatDeNume,
    this.motivRespingere,
    this.aprobatDeUserId,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Derived display category (Activ / Planificat / Pending).
  ComandaVizibilitate get vizibilitate {
    if (status != ComandaStatus.aprobat) {
      return ComandaVizibilitate.neaprobatPending;
    }
    final now = DateTime.now();
    if (dataStart.isAfter(now)) return ComandaVizibilitate.activPlanificat;
    return ComandaVizibilitate.activActiv;
  }

  factory Comanda.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Comanda(
      id:                  doc.id,
      santierId:           d['santierId']           as String,
      santierNume:         d['santierNume']         as String,
      santierDataIncepere: (d['santierDataIncepere'] as Timestamp).toDate(),
      vehicleId:           d['vehicleId']           as String,
      vehicleModel:        d['vehicleModel']        as String,
      vehicleClasa:        d['vehicleClasa']        as String,
      dataStart:           (d['dataStart']  as Timestamp).toDate(),
      dataFinal:           (d['dataFinal']  as Timestamp).toDate(),
      status:              ComandaStatus.fromString(
          d['status'] as String? ?? 'pending'),
      creatDeUserId:       d['creatDeUserId']       as String,
      creatDeNume:         d['creatDeNume']         as String,
      motivRespingere:     d['motivRespingere']     as String?,
      aprobatDeUserId:     d['aprobatDeUserId']     as String?,
      note:                d['note']                as String?,
      createdAt:           (d['createdAt']  as Timestamp).toDate(),
      updatedAt:           (d['updatedAt']  as Timestamp).toDate(),
    );
  }
}