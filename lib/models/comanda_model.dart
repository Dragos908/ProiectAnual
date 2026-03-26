import 'package:cloud_firestore/cloud_firestore.dart';

enum ComandaStatus {
  pending,
  aprobat,
  respins;

  String get value => name;

  static ComandaStatus fromString(String v) => switch (v) {
    'aprobat' => ComandaStatus.aprobat,
    'respins' => ComandaStatus.respins,
    _         => ComandaStatus.pending,
  };

  String get displayLabel => switch (this) {
    ComandaStatus.pending => 'În așteptare',
    ComandaStatus.aprobat => 'Aprobat',
    ComandaStatus.respins => 'Respins',
  };
}

enum ComandaVizibilitate { activActiv, activPlanificat, neaprobatPending }

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

  ComandaVizibilitate get vizibilitate {
    if (status != ComandaStatus.aprobat) return ComandaVizibilitate.neaprobatPending;
    return dataStart.isAfter(DateTime.now())
        ? ComandaVizibilitate.activPlanificat
        : ComandaVizibilitate.activActiv;
  }

  factory Comanda.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime ts(String key) => (d[key] as Timestamp).toDate();
    return Comanda(
      id:                  doc.id,
      santierId:           d['santierId']           as String,
      santierNume:         d['santierNume']         as String,
      santierDataIncepere: ts('santierDataIncepere'),
      vehicleId:           d['vehicleId']           as String,
      vehicleModel:        d['vehicleModel']        as String,
      vehicleClasa:        d['vehicleClasa']        as String,
      dataStart:           ts('dataStart'),
      dataFinal:           ts('dataFinal'),
      status:              ComandaStatus.fromString(d['status'] as String? ?? 'pending'),
      creatDeUserId:       d['creatDeUserId']       as String,
      creatDeNume:         d['creatDeNume']         as String,
      motivRespingere:     d['motivRespingere']     as String?,
      aprobatDeUserId:     d['aprobatDeUserId']     as String?,
      note:                d['note']                as String?,
      createdAt:           ts('createdAt'),
      updatedAt:           ts('updatedAt'),
    );
  }
}