import 'package:cloud_firestore/cloud_firestore.dart';

class OccupancyPeriod {
  final DateTime from;
  final DateTime to;
  final String? rentedBy;
  final String santierId;
  final String comenzaId;
  final String? status;
  final String? santierColor;

  const OccupancyPeriod({
    required this.from,
    required this.to,
    this.rentedBy,
    required this.santierId,
    required this.comenzaId,
    this.status,
    this.santierColor,
  });

  bool get isPending => status == null || status == 'pending';

  bool overlapsWith(DateTime start, DateTime end) =>
      !from.isAfter(end) && !to.isBefore(start);
}