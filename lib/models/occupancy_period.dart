import 'package:cloud_firestore/cloud_firestore.dart';

/// OccupancyPeriod — v4.
/// from/to are DateTime WITH time component.
class OccupancyPeriod {
  final DateTime from;
  final DateTime to;
  final String? rentedBy;
  final String santierId;
  final String comenzaId;

  /// "pending" | "aprobat" — null is treated as pending.
  final String? status;

  /// Hex color string e.g. "#2196F3". Null = use cyclic index from kPeriodColors.
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