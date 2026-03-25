import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Paleta culori per santier (atribuire ciclica la creare) ───────────────────

const List<String> kSantierColorPalette = [
  '#2196F3', // Albastru
  '#E91E63', // Roz
  '#FF9800', // Portocaliu
  '#9C27B0', // Violet
  '#009688', // Teal
  '#F44336', // Rosu
  '#3F51B5', // Indigo
  '#00BCD4', // Cyan
];

String santierColorForIndex(int index) =>
    kSantierColorPalette[index % kSantierColorPalette.length];

// ── SantierStatus ─────────────────────────────────────────────────────────────

enum SantierStatus {
  activ,
  suspendat,
  arhivat;

  String get value {
    switch (this) {
      case SantierStatus.activ:
        return 'activ';
      case SantierStatus.suspendat:
        return 'suspendat';
      case SantierStatus.arhivat:
        return 'arhivat';
    }
  }

  static SantierStatus fromString(String value) {
    switch (value) {
      case 'suspendat':
        return SantierStatus.suspendat;
      case 'arhivat':
        return SantierStatus.arhivat;
      default:
        return SantierStatus.activ;
    }
  }

  int get sortPriority {
    switch (this) {
      case SantierStatus.activ:
        return 0;
      case SantierStatus.suspendat:
        return 1;
      case SantierStatus.arhivat:
        return 2;
    }
  }

  String get displayLabel {
    switch (this) {
      case SantierStatus.activ:
        return 'Activ';
      case SantierStatus.suspendat:
        return 'Suspendat';
      case SantierStatus.arhivat:
        return 'Arhivat';
    }
  }
}

// ── Santier ───────────────────────────────────────────────────────────────────

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

  /// Culoarea santierului (hex, ex. "#2196F3").
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

  /// Culoarea Flutter parsata din campul hex.
  Color get flutterColor {
    try {
      final clean = color.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }

  static DateTime? _toDateOrNull(dynamic v) =>
      v is Timestamp ? v.toDate() : null;

  static DateTime _toDateOrNow(dynamic v) =>
      v is Timestamp ? v.toDate() : DateTime.now();

  factory Santier.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Santier(
      id:             doc.id,
      denumire:       data['denumire']      as String? ?? '',
      locatie:        data['locatie']       as String? ?? '',
      dataIncepere:   _toDateOrNull(data['dataIncepere']),
      dataFinalizare: _toDateOrNull(data['dataFinalizare']),
      status:         SantierStatus.fromString(
          data['status'] as String? ?? 'activ'),
      creatDeUserId:  data['creatDeUserId'] as String? ?? '',
      creatDeNume:    data['creatDeNume']   as String? ?? '',
      createdAt:      _toDateOrNow(data['createdAt']),
      updatedAt:      _toDateOrNow(data['updatedAt']),
      color:          data['color']         as String? ?? '#2196F3',
    );
  }
}