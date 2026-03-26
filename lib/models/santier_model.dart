import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const List<String> kSantierColorPalette = [
  '#2196F3', '#E91E63', '#FF9800', '#9C27B0',
  '#009688', '#F44336', '#3F51B5', '#00BCD4',
];

String santierColorForIndex(int index) =>
    kSantierColorPalette[index % kSantierColorPalette.length];

enum SantierStatus {
  activ,
  suspendat,
  arhivat;

  String get value => name;

  static SantierStatus fromString(String value) => switch (value) {
    'suspendat' => SantierStatus.suspendat,
    'arhivat'   => SantierStatus.arhivat,
    _           => SantierStatus.activ,
  };

  int get sortPriority => switch (this) {
    SantierStatus.activ     => 0,
    SantierStatus.suspendat => 1,
    SantierStatus.arhivat   => 2,
  };

  String get displayLabel => switch (this) {
    SantierStatus.activ     => 'Activ',
    SantierStatus.suspendat => 'Suspendat',
    SantierStatus.arhivat   => 'Arhivat',
  };
}

class Santier {
  final String id;
  final String denumire;
  final String locatie;
  final DateTime? dataIncepere;
  final DateTime? dataFinalizare;
  final SantierStatus status;
  final String creatDeUserId;
  final String creatDeNume;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String color;

  const Santier({
    required this.id,
    required this.denumire,
    required this.locatie,
    this.dataIncepere,
    this.dataFinalizare,
    required this.status,
    required this.creatDeUserId,
    required this.creatDeNume,
    required this.createdAt,
    required this.updatedAt,
    this.color = '#2196F3',
  });

  Color get flutterColor {
    try {
      return Color(int.parse('FF${color.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }

  factory Santier.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime? toDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    return Santier(
      id:             doc.id,
      denumire:       d['denumire']      as String? ?? '',
      locatie:        d['locatie']       as String? ?? '',
      dataIncepere:   toDate(d['dataIncepere']),
      dataFinalizare: toDate(d['dataFinalizare']),
      status:         SantierStatus.fromString(d['status'] as String? ?? 'activ'),
      creatDeUserId:  d['creatDeUserId'] as String? ?? '',
      creatDeNume:    d['creatDeNume']   as String? ?? '',
      createdAt:      toDate(d['createdAt']) ?? DateTime.now(),
      updatedAt:      toDate(d['updatedAt']) ?? DateTime.now(),
      color:          d['color']         as String? ?? '#2196F3',
    );
  }
}