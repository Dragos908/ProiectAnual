import '/models/santier_model.dart';

class SantiereFilter {
  final SantierStatus? status;
  final DateTimeRange? perioadaCreare;

  const SantiereFilter({this.status, this.perioadaCreare});

  bool get isActive => status != null || perioadaCreare != null;

  SantiereFilter copyWith({
    SantierStatus? status,
    DateTimeRange? perioadaCreare,
    bool clearStatus = false,
    bool clearPerioad = false,
  }) => SantiereFilter(
    status:         clearStatus  ? null : (status         ?? this.status),
    perioadaCreare: clearPerioad ? null : (perioadaCreare ?? this.perioadaCreare),
  );

  List<Santier> apply(List<Santier> all) => all.where((s) {
    if (status != null && s.status != status) return false;
    if (perioadaCreare != null) {
      if (s.createdAt.isBefore(perioadaCreare!.start)) return false;
      if (s.createdAt.isAfter(perioadaCreare!.end.add(const Duration(days: 1)))) return false;
    }
    return true;
  }).toList();
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});
}