// lib/models/vehicle.dart
//
// Model Vehicle – baza de date: 'meca', colecție: 'vehicles'
// ID document = nr. înmatriculare (sau UUID dacă nu există)

import 'package:cloud_firestore/cloud_firestore.dart';

// ════════════════════════════════════════════════════════════
// OCCUPANCY PERIOD
// ════════════════════════════════════════════════════════════

class OccupancyPeriod {
  final DateTime from;
  final DateTime to;
  final String? rentedBy;
  final String santierId;
  final String comenzaId;

  /// "pending" | "aprobat" — null tratat ca pending.
  final String? status;

  /// Culoarea hex a santierului ex. "#2196F3".
  final String? santierColor;

  const OccupancyPeriod({
    required this.from,
    required this.to,
    this.rentedBy,
    this.santierId = '',
    this.comenzaId = '',
    this.status,
    this.santierColor,
  });

  bool get isPending => status == null || status == 'pending';
  bool get isAprobat => status == 'aprobat';

  bool overlapsWith(DateTime start, DateTime end) =>
      !from.isAfter(end) && !to.isBefore(start);

  Map<String, dynamic> toMap() => {
    'from': Timestamp.fromDate(from),
    'to':   Timestamp.fromDate(to),
    if (rentedBy     != null) 'rentedBy':     rentedBy,
    if (santierId.isNotEmpty) 'santierId':    santierId,
    if (comenzaId.isNotEmpty) 'comenzaId':    comenzaId,
    if (status       != null) 'status':       status,
    if (santierColor != null) 'santierColor': santierColor,
  };

  factory OccupancyPeriod.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      return DateTime(1970);
    }
    return OccupancyPeriod(
      from:         parseDate(map['from']),
      to:           parseDate(map['to']),
      rentedBy:     map['rentedBy']     as String?,
      santierId:    map['santierId']    as String? ?? '',
      comenzaId:    map['comenzaId']    as String? ?? '',
      status:       map['status']       as String?,
      santierColor: map['santierColor'] as String?,
    );
  }
}

// ════════════════════════════════════════════════════════════
// VEHICLE STATUS
// forma_dezvaluire: 'baza' | 'santier' | 'reparatie'
// ════════════════════════════════════════════════════════════

enum VehicleStatus { laBase, inSantier, laReparatie }

extension VehicleStatusX on VehicleStatus {
  String get translationKey {
    switch (this) {
      case VehicleStatus.laBase:
        return 'statusLaBaza';
      case VehicleStatus.inSantier:
        return 'statusInSantier';
      case VehicleStatus.laReparatie:
        return 'statusLaReparatie';
    }
  }

  String get firestoreValue {
    switch (this) {
      case VehicleStatus.laBase:
        return 'baza';
      case VehicleStatus.inSantier:
        return 'santier';
      case VehicleStatus.laReparatie:
        return 'reparatie';
    }
  }

  /// Prioritate sortare: Baza=0, Santier=1, Reparatie=2
  int get sortOrder {
    switch (this) {
      case VehicleStatus.laBase:
        return 0;
      case VehicleStatus.inSantier:
        return 1;
      case VehicleStatus.laReparatie:
        return 2;
    }
  }

  static VehicleStatus fromFirestoreValue(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'santier':
      case 'in santier':
      case 'în santier':
        return VehicleStatus.inSantier;
      case 'reparatie':
      case 'la reparatie':
      case 'la reparație':
        return VehicleStatus.laReparatie;
      default:
        return VehicleStatus.laBase;
    }
  }
}

// ════════════════════════════════════════════════════════════
// VEHICLE MODEL
// ════════════════════════════════════════════════════════════

class Vehicle {
  final String idMeca;
  final String clasa;
  final String subclasa;
  final String model;
  final VehicleStatus status;
  final String tonajMarime;
  final String locatieBaza;
  final double? tonaj;
  final String nrInmatriculare;
  final List<OccupancyPeriod> occupancyPeriods;
  final List<String> imageUrls;
  final int? anFabricatie;
  final String? serieSasiu;
  final String? observatii;

  const Vehicle({
    required this.idMeca,
    required this.clasa,
    required this.subclasa,
    required this.model,
    required this.status,
    required this.tonajMarime,
    required this.locatieBaza,
    this.tonaj,
    this.nrInmatriculare = '',
    this.occupancyPeriods = const [],
    this.imageUrls = const [],
    this.anFabricatie,
    this.serieSasiu,
    this.observatii,
  });

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final tonajStr = (data['tonaj_marime'] ?? '').toString().trim();
    final tonajNum = double.tryParse(
      tonajStr.replaceAll(RegExp(r'[^\d\.]'), ''),
    );

    final List<OccupancyPeriod> periods = [];

    final startRaw = data['data_inceput_rezervare'];
    final endRaw   = data['data_sfarsit_rezervare'];
    if (startRaw is Timestamp && endRaw is Timestamp) {
      final startDt = startRaw.toDate();
      final endDt   = endRaw.toDate();
      final isPlaceholder = startDt.year == 1970 && endDt.year == 1970;
      if (!isPlaceholder) {
        periods.add(OccupancyPeriod(
          from:         startDt,
          to:           endDt,
          rentedBy:     data['rezervat_de'] as String?,
          status:       data['status']       as String?,
          santierColor: data['santierColor'] as String?,
        ));
      }
    }

    if (data['extra_perioade'] is List) {
      for (final item in data['extra_perioade'] as List) {
        if (item is Map<String, dynamic>) {
          periods.add(OccupancyPeriod.fromMap(item));
        }
      }
    }

    return Vehicle(
      idMeca:           doc.id,
      nrInmatriculare:  doc.id,
      clasa:            (data['clasa']          ?? '').toString(),
      subclasa:         (data['subclasa']        ?? '').toString(),
      model:            (data['denumire_model']  ?? '').toString(),
      tonajMarime:      tonajStr,
      tonaj:            tonajNum,
      locatieBaza:      (data['baza']            ?? '').toString(),
      status:           VehicleStatusX.fromFirestoreValue(
          data['forma_dezvaluire'] as String?),
      occupancyPeriods: periods,
      imageUrls:        List<String>.from(data['poze']      ?? []),
      anFabricatie:     data['an_fabricatie']    as int?,
      serieSasiu:       data['serie_sasiu']      as String?,
      observatii:       data['observatii']       as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    final Timestamp zeroTs = Timestamp.fromDate(DateTime(1970, 1, 1));

    Timestamp startTs = zeroTs;
    Timestamp endTs   = zeroTs;
    String?   rentedBy;
    final extraPeriods = <Map<String, dynamic>>[];

    for (int i = 0; i < occupancyPeriods.length; i++) {
      final p = occupancyPeriods[i];
      if (i == 0) {
        startTs  = Timestamp.fromDate(p.from);
        endTs    = Timestamp.fromDate(p.to);
        rentedBy = p.rentedBy;
      } else {
        extraPeriods.add(p.toMap());
      }
    }

    return {
      'clasa':                   clasa,
      'subclasa':                subclasa,
      'denumire_model':          model,
      'tonaj_marime':            tonajMarime,
      'baza':                    locatieBaza,
      'forma_dezvaluire':        status.firestoreValue,
      'data_inceput_rezervare':  startTs,
      'data_sfarsit_rezervare':  endTs,
      if (rentedBy != null) 'rezervat_de': rentedBy,
      if (extraPeriods.isNotEmpty) 'extra_perioade': extraPeriods,
      if (imageUrls.isNotEmpty) 'poze': imageUrls,
      if (anFabricatie != null) 'an_fabricatie': anFabricatie,
      if (serieSasiu != null) 'serie_sasiu': serieSasiu,
      if (observatii != null) 'observatii': observatii,
    };
  }

  Vehicle copyWith({
    String? idMeca,
    String? clasa,
    String? subclasa,
    String? model,
    VehicleStatus? status,
    String? tonajMarime,
    double? tonaj,
    String? locatieBaza,
    String? nrInmatriculare,
    List<OccupancyPeriod>? occupancyPeriods,
    List<String>? imageUrls,
    int? anFabricatie,
    String? serieSasiu,
    String? observatii,
  }) {
    return Vehicle(
      idMeca:           idMeca           ?? this.idMeca,
      clasa:            clasa            ?? this.clasa,
      subclasa:         subclasa         ?? this.subclasa,
      model:            model            ?? this.model,
      status:           status           ?? this.status,
      tonajMarime:      tonajMarime      ?? this.tonajMarime,
      tonaj:            tonaj            ?? this.tonaj,
      locatieBaza:      locatieBaza      ?? this.locatieBaza,
      nrInmatriculare:  nrInmatriculare  ?? this.nrInmatriculare,
      occupancyPeriods: occupancyPeriods ?? this.occupancyPeriods,
      imageUrls:        imageUrls        ?? this.imageUrls,
      anFabricatie:     anFabricatie     ?? this.anFabricatie,
      serieSasiu:       serieSasiu       ?? this.serieSasiu,
      observatii:       observatii       ?? this.observatii,
    );
  }
}

// ════════════════════════════════════════════════════════════
// SORT: Baza > Santier > Reparatie → Clasa → Subclasa → Tonaj
// ════════════════════════════════════════════════════════════

List<Vehicle> sortVehicles(List<Vehicle> vehicles) {
  final copy = [...vehicles];
  copy.sort((a, b) {
    final s = a.status.sortOrder.compareTo(b.status.sortOrder);
    if (s != 0) return s;

    final c = a.clasa.toLowerCase().compareTo(b.clasa.toLowerCase());
    if (c != 0) return c;

    final sc = a.subclasa.toLowerCase().compareTo(b.subclasa.toLowerCase());
    if (sc != 0) return sc;

    if (a.tonaj == null && b.tonaj == null) return 0;
    if (a.tonaj == null) return 1;
    if (b.tonaj == null) return -1;
    return a.tonaj!.compareTo(b.tonaj!);
  });
  return copy;
}