import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/vehicle.dart';
import '../app_localizations.dart';
import '../approval_theme.dart';
import '../widgets/occupancy_calendar.dart';
import '../services/rezervare_service.dart';

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

Color _rowColor(VehicleStatus status, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    VehicleStatus.laBase      => isDark ? ApprovalTheme.cardBackground(context) : Colors.white,
    VehicleStatus.inSantier   => isDark ? const Color(0xFF3D2E00) : const Color(0xFFFFF3CD),
    VehicleStatus.laReparatie => isDark ? const Color(0xFF3D0000) : const Color(0xFFFFEBEE),
  };
}

Color _statusColor(VehicleStatus status, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    VehicleStatus.laBase      => isDark ? const Color(0xFF90A4AE) : const Color(0xFF546E7A),
    VehicleStatus.inSantier   => Colors.orange,
    VehicleStatus.laReparatie => Colors.red,
  };
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String? _freeLabel(Vehicle vehicle, User currentUser) {
  final today = _dateOnly(DateTime.now());

  final others = vehicle.occupancyPeriods
      .where((p) => p.rentedBy != currentUser.name)
      .map((p) => (from: _dateOnly(p.from), to: _dateOnly(p.to)))
      .toList()
    ..sort((a, b) => a.from.compareTo(b.from));

  if (others.isEmpty) return null;

  final activeNow = others.where((p) => !today.isBefore(p.from) && !today.isAfter(p.to));
  if (activeNow.isNotEmpty) {
    DateTime blockEnd = activeNow.map((p) => p.to).reduce((a, b) => a.isAfter(b) ? a : b);
    bool extended = true;
    while (extended) {
      extended = false;
      for (final p in others) {
        if (!p.from.isAfter(blockEnd.add(const Duration(days: 1))) && p.to.isAfter(blockEnd)) {
          blockEnd = p.to;
          extended = true;
        }
      }
    }
    return 'Liber din: ${_fmtDate(blockEnd.add(const Duration(days: 1)))}';
  }

  final upcoming = others.where((p) => p.from.isAfter(today));
  if (upcoming.isNotEmpty) {
    final nextFrom = upcoming.map((p) => p.from).reduce((a, b) => a.isBefore(b) ? a : b);
    return 'Liber până: ${_fmtDate(nextFrom.subtract(const Duration(days: 1)))}';
  }

  return null;
}

class TehnicaVehicleService {
  final _ref = FirebaseFirestore.instance.collection('vehicles');

  Stream<QuerySnapshot> vehiclesStream() => _ref.snapshots();

  Future<void> updateVehicle(Vehicle vehicle) {
    final data = vehicle.toFirestore()
      ..remove('occupancyPeriods')
      ..remove('extra_perioade')
      ..remove('data_inceput_rezervare')
      ..remove('data_sfarsit_rezervare')
      ..remove('rezervat_de');

    return _ref.doc(vehicle.idMeca).update(data).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Timeout: serverul nu răspunde.'),
    );
  }
}

// _VehicleFilter
class _VehicleFilter {
  final String? clasa, subclasa;
  final double? tonajMin, tonajMax;
  final VehicleStatus? status;
  final DateTimeRange? ocupare;

  const _VehicleFilter({
    this.clasa, this.subclasa, this.tonajMin, this.tonajMax,
    this.status, this.ocupare,
  });

  bool get isActive =>
      clasa != null || subclasa != null || tonajMin != null ||
          tonajMax != null || status != null || ocupare != null;

  List<Vehicle> apply(List<Vehicle> vehicles) => vehicles.where((v) {
    if (clasa    != null && v.clasa    != clasa)   return false;
    if (subclasa != null && v.subclasa != subclasa) return false;
    if (status   != null && v.status   != status)  return false;
    if (tonajMin != null && (v.tonaj == null || v.tonaj! < tonajMin!)) return false;
    if (tonajMax != null && (v.tonaj == null || v.tonaj! > tonajMax!)) return false;
    if (ocupare  != null) {
      final hasOverlap = v.occupancyPeriods.any(
              (p) => !p.to.isBefore(ocupare!.start) && !p.from.isAfter(ocupare!.end));
      if (!hasOverlap) return false;
    }
    return true;
  }).toList();
}

// Shared Widgets
class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 8),
      Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
          color: ApprovalTheme.borderColor(context),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(height: 12),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  final VehicleStatus status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: ApprovalTheme.badgeDecoration(color),
    child: Text(
      AppLocalizations.of(context).translate(status.translationKey),
      style: ApprovalTheme.badgeTextStyle(color),
    ),
  );
}

class _DataRow extends StatelessWidget {
  final String label, value;
  const _DataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label, style: ApprovalTheme.textSmall(context))),
        Expanded(child: Text(value, style: ApprovalTheme.textBody(context))),
      ],
    ),
  );
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

// TehnicaPage
class TehnicaPage extends StatefulWidget {
  final User currentUser;
  const TehnicaPage({super.key, required this.currentUser});

  @override
  State<TehnicaPage> createState() => _TehnicaPageState();
}

class _TehnicaPageState extends State<TehnicaPage> {
  final TehnicaVehicleService _service = TehnicaVehicleService();
  final ScrollController _scrollController = ScrollController();
  final _itemKeys = <String, GlobalKey>{};
  _VehicleFilter _filter = const _VehicleFilter();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToNearest(VehicleStatus status, List<Vehicle> displayed) {
    GlobalKey? nearest;
    double? minDist;

    for (final v in displayed) {
      if (v.status != status) continue;
      final key = _itemKeys[v.idMeca];
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final dist = box.localToGlobal(Offset.zero).dy.abs();
      if (minDist == null || dist < minDist) {
        minDist = dist;
        nearest = key;
      }
    }

    if (nearest?.currentContext != null) {
      Scrollable.ensureVisible(
        nearest!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openFilter(List<Vehicle> all) async {
    final result = await showModalBottomSheet<_VehicleFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(vehicles: all, current: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }

  void _openDetail(Vehicle vehicle) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DetailSheet(
      vehicle: vehicle,
      currentUser: widget.currentUser,
      service: _service,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: _service.vehiclesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off_outlined,
                    size: 48, color: ApprovalTheme.errorColor(context)),
                const SizedBox(height: 12),
                Text('${l.translate('networkError')}: ${snapshot.error}',
                    style: ApprovalTheme.textBody(context),
                    textAlign: TextAlign.center),
              ]),
            ),
          );
        }

        final allVehicles = (snapshot.data?.docs ?? [])
            .map(Vehicle.fromFirestore)
            .toList();
        final sorted    = sortVehicles(allVehicles);
        final displayed = _filter.apply(sorted);

        final listItems = displayed.map((v) {
          final key = _itemKeys.putIfAbsent(v.idMeca, () => GlobalKey());
          return SizedBox(
            key: key,
            child: _VehicleRow(
              vehicle: v,
              currentUser: widget.currentUser,
              onTap: () => _openDetail(v),
              service: _service,
            ),
          );
        }).toList();

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(children: [
            _StickyHeader(
              filter: _filter,
              onAnchor: (status) => _scrollToNearest(status, displayed),
              onFilter: () => _openFilter(sorted),
            ),
            Expanded(
              child: displayed.isEmpty
                  ? Center(child: Text(l.translate('noVehicles'),
                  style: ApprovalTheme.textBody(context)))
                  : ListView(
                controller: _scrollController,
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 8),
                children: listItems,
              ),
            ),
          ]),
        );
      },
    );
  }
}

// Sticky Header
class _StickyHeader extends StatelessWidget {
  final _VehicleFilter filter;
  final void Function(VehicleStatus) onAnchor;
  final VoidCallback onFilter;

  const _StickyHeader({required this.filter, required this.onAnchor, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    final l         = AppLocalizations.of(context);
    final baseColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF90A4AE)
        : const Color(0xFF546E7A);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(children: [
        Expanded(child: _AnchorButton(
          label: l.translate('statusInSantier'),
          color: Colors.orange,
          onTap: () => onAnchor(VehicleStatus.inSantier),
        )),
        const SizedBox(width: 6),
        Expanded(child: _AnchorButton(
          label: l.translate('statusLaBaza'),
          color: baseColor,
          onTap: () => onAnchor(VehicleStatus.laBase),
        )),
        const SizedBox(width: 6),
        Expanded(child: _AnchorButton(
          label: l.translate('statusLaReparatie'),
          color: Colors.red,
          onTap: () => onAnchor(VehicleStatus.laReparatie),
        )),
        const SizedBox(width: 6),
        _FilterButton(filter: filter, onFilter: onFilter),
      ]),
    );
  }
}

class _AnchorButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AnchorButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: color, width: 1.4),
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ApprovalTheme.radiusSmall)),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 11, color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center),
  );
}

class _FilterButton extends StatelessWidget {
  final _VehicleFilter filter;
  final VoidCallback onFilter;
  const _FilterButton({required this.filter, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    final active = filter.isActive;
    final color  = active
        ? Theme.of(context).colorScheme.primary
        : ApprovalTheme.textSecondary(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        OutlinedButton(
          onPressed: onFilter,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color, width: 1.4),
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ApprovalTheme.radiusSmall)),
          ),
          child: Icon(Icons.filter_list, size: 18, color: color),
        ),
        if (active)
          Positioned(
            top: -3, right: -3,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

// Vehicle Row
class _VehicleRow extends StatelessWidget {
  final Vehicle vehicle;
  final User currentUser;
  final VoidCallback onTap;
  final TehnicaVehicleService service;

  const _VehicleRow({
    required this.vehicle,
    required this.currentUser,
    required this.onTap,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor    = _rowColor(vehicle.status, context);
    final stateColor = _statusColor(vehicle.status, context);
    final ownPeriod  = vehicle.occupancyPeriods
        .where((p) => p.rentedBy == currentUser.name)
        .firstOrNull;
    final freeLabel  = _freeLabel(vehicle, currentUser);
    final showBaza   = vehicle.status == VehicleStatus.laBase && vehicle.locatieBaza.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
        side: BorderSide(
            color: ApprovalTheme.borderColor(context),
            width: ApprovalTheme.borderWidth),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3, height: 44,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                    color: stateColor, borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.model,
                        style: ApprovalTheme.textTitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    _SubtitleRow(vehicle: vehicle),
                    if (showBaza) ...[
                      const SizedBox(height: 2),
                      _IconLabelRow(icon: Icons.location_on_outlined, text: vehicle.locatieBaza),
                    ],
                    if (freeLabel != null) ...[
                      const SizedBox(height: 2),
                      _FreeLabelRow(label: freeLabel),
                    ],
                    if (ownPeriod != null) ...[
                      const SizedBox(height: 2),
                      _OwnPeriodRow(period: ownPeriod),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatusBadge(status: vehicle.status, color: stateColor),
                  if (vehicle.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ApprovalTheme.radiusSmall),
                      child: Image.network(
                        vehicle.imageUrls.first,
                        width: 44, height: 32, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 44, height: 32,
                          color: ApprovalTheme.borderColor(context),
                          child: Icon(Icons.image_not_supported_outlined,
                              size: 14, color: ApprovalTheme.textSecondary(context)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtitleRow extends StatelessWidget {
  final Vehicle vehicle;
  const _SubtitleRow({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    Widget dot() => Text('  ·  ', style: ApprovalTheme.textSmall(context));
    Widget chip(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: ApprovalTheme.textSecondary(context)),
      const SizedBox(width: 2),
      Text(text, style: ApprovalTheme.textSmall(context)),
    ]);

    return Row(children: [
      Text('${vehicle.clasa} · ${vehicle.subclasa}',
          style: ApprovalTheme.textSmall(context)),
      if (vehicle.nrInmatriculare.isNotEmpty) ...[
        dot(), chip(Icons.badge_outlined, vehicle.nrInmatriculare),
      ],
      if (vehicle.tonajMarime.isNotEmpty) ...[
        dot(), chip(Icons.scale_outlined, vehicle.tonajMarime),
      ],
    ]);
  }
}

class _IconLabelRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconLabelRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 11, color: ApprovalTheme.textSecondary(context)),
    const SizedBox(width: 2),
    Text(text, style: ApprovalTheme.textSmall(context)),
  ]);
}

class _FreeLabelRow extends StatelessWidget {
  final String label;
  const _FreeLabelRow({required this.label});

  @override
  Widget build(BuildContext context) {
    final isOccupied = label.startsWith('Liber din');
    final color = isOccupied
        ? ApprovalTheme.errorColor(context).withOpacity(0.8)
        : Colors.green.shade600;
    return Row(children: [
      Icon(
        isOccupied ? Icons.lock_clock_outlined : Icons.event_available_outlined,
        size: 11, color: color,
      ),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
    ]);
  }
}

class _OwnPeriodRow extends StatelessWidget {
  final OccupancyPeriod period;
  const _OwnPeriodRow({required this.period});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(children: [
      Icon(Icons.calendar_today_outlined,
          size: 14, color: ApprovalTheme.primaryAccent(context)),
      const SizedBox(width: 4),
      Text(
        '${_fmtDate(period.from)} – ${_fmtDate(period.to)}',
        style: TextStyle(
            fontSize: 12,
            color: ApprovalTheme.primaryAccent(context),
            fontWeight: FontWeight.w500),
      ),
    ]),
  );
}

// Detail Sheet
class _DetailSheet extends StatelessWidget {
  final Vehicle vehicle;
  final User currentUser;
  final TehnicaVehicleService service;

  const _DetailSheet({
    required this.vehicle,
    required this.currentUser,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(vehicle.model, style: ApprovalTheme.textTitle(context)),
                Text('${vehicle.clasa} · ${vehicle.subclasa}',
                    style: ApprovalTheme.textSmall(context)),
              ]),
            ),
            _StatusBadge(
              status: vehicle.status,
              color:  _statusColor(vehicle.status, context),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: _DetailsContent(
            vehicle: vehicle,
            currentUser: currentUser,
            isNarrow: mq.size.width < 480,
            service: service,
          ),
        ),
      ]),
    );
  }
}

class _DetailsContent extends StatelessWidget {
  final Vehicle vehicle;
  final User currentUser;
  final bool isNarrow;
  final TehnicaVehicleService service;

  const _DetailsContent({
    required this.vehicle,
    required this.currentUser,
    required this.isNarrow,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final gallery  = _PhotoGallery(imageUrls: vehicle.imageUrls);
    final techData = _TechDataSection(vehicle: vehicle, service: service);
    final calendar = _OccupancyCalendarSection(vehicle: vehicle, currentUser: currentUser);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: isNarrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        gallery, const SizedBox(height: 16),
        techData, const SizedBox(height: 16),
        calendar,
      ])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: gallery),
        const SizedBox(width: 12),
        Expanded(child: techData),
        const SizedBox(width: 12),
        Expanded(child: calendar),
      ]),
    );
  }
}

// Photo Gallery
class _PhotoGallery extends StatefulWidget {
  final List<String> imageUrls;
  const _PhotoGallery({required this.imageUrls});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  final _pageCtrl = PageController();
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrls.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) =>
          _goToPage((_current + 1) % widget.imageUrls.length));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageCtrl.animateToPage(page,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    setState(() => _current = page);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: ApprovalTheme.surfaceBackground(context),
          borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
          border: Border.all(color: ApprovalTheme.borderColor(context)),
        ),
        child: Center(
          child: Icon(Icons.image_not_supported_outlined,
              size: 40, color: ApprovalTheme.textSecondary(context)),
        ),
      );
    }

    if (widget.imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
        child: Image.network(widget.imageUrls.first,
            height: 180, width: double.infinity, fit: BoxFit.cover),
      );
    }

    return SizedBox(
      height: 180,
      child: Stack(children: [
        PageView.builder(
          controller: _pageCtrl,
          itemCount: widget.imageUrls.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
            child: Image.network(widget.imageUrls[i],
                fit: BoxFit.cover, width: double.infinity),
          ),
        ),
        Positioned(
          left: 4, top: 0, bottom: 0,
          child: Center(child: _NavArrow(
            icon: Icons.chevron_left,
            onTap: () => _goToPage(
                (_current - 1 + widget.imageUrls.length) % widget.imageUrls.length),
          )),
        ),
        Positioned(
          right: 4, top: 0, bottom: 0,
          child: Center(child: _NavArrow(
            icon: Icons.chevron_right,
            onTap: () => _goToPage((_current + 1) % widget.imageUrls.length),
          )),
        ),
        Positioned(
          bottom: 6, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.imageUrls.length, (i) =>
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _current ? 10 : 6, height: 6,
                  decoration: BoxDecoration(
                    color: i == _current ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ),
          ),
        ),
      ]),
    );
  }
}

// Tech Data Section
class _TechDataSection extends StatelessWidget {
  final Vehicle vehicle;
  final TehnicaVehicleService service;

  const _TechDataSection({required this.vehicle, required this.service});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.translate('technicalData'), style: ApprovalTheme.textTitle(context)),
      const SizedBox(height: 8),
      _DataRow(label: l.translate('class'),
          value: '${vehicle.clasa} / ${vehicle.subclasa}'),
      _DataRow(label: l.translate('model'), value: vehicle.model),
      _DataRow(label: l.translate('plate'),
          value: vehicle.nrInmatriculare.isNotEmpty
              ? vehicle.nrInmatriculare
              : vehicle.idMeca),
      if (vehicle.tonajMarime.isNotEmpty)
        _DataRow(label: l.translate('tonnage'), value: vehicle.tonajMarime),
      if (vehicle.locatieBaza.isNotEmpty)
        _DataRow(label: l.translate('base'), value: vehicle.locatieBaza),
      if (vehicle.anFabricatie != null)
        _DataRow(label: l.translate('yearMade'), value: '${vehicle.anFabricatie}'),
      if (vehicle.serieSasiu != null)
        _DataRow(label: l.translate('chassisSeries'), value: vehicle.serieSasiu!),
      if (vehicle.observatii?.isNotEmpty == true)
        _DataRow(label: l.translate('observations'), value: vehicle.observatii!),
    ]);
  }
}

// Occupancy Calendar Section
class _OccupancyCalendarSection extends StatelessWidget {
  final Vehicle vehicle;
  final User currentUser;

  const _OccupancyCalendarSection({required this.vehicle, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return StreamBuilder<List<Rezervare>>(
      stream: RezervareService.streamByVehicle(vehicle.idMeca),
      builder: (context, snap) {
        final all     = snap.data ?? [];
        final comenzi = all.where((r) => r.isComanda).toList();
        final periods = all.map((r) => r.toOccupancyPeriod()).toList();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.translate('occupancyCalendar'), style: ApprovalTheme.textTitle(context)),
          const SizedBox(height: 8),
          if (comenzi.isNotEmpty)
            _ComenziReadOnlySection(
                comenzi: comenzi,
                isDark: Theme.of(context).brightness == Brightness.dark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: ApprovalTheme.surfaceBackground(context),
              borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
              border: Border.all(color: ApprovalTheme.borderColor(context)),
            ),
            child: OccupancyCalendar(
              periods:     periods,
              mode:        CalendarMode.dateOnly,
              showActions: false,
            ),
          ),
        ]);
      },
    );
  }
}

// Comenzi Read-Only Section
class _ComenziReadOnlySection extends StatefulWidget {
  final List<Rezervare> comenzi;
  final bool isDark;
  const _ComenziReadOnlySection({required this.comenzi, required this.isDark});

  @override
  State<_ComenziReadOnlySection> createState() => _ComenziReadOnlySectionState();
}

class _ComenziReadOnlySectionState extends State<_ComenziReadOnlySection> {
  bool _expanded = false;

  Color _santierColor(Rezervare r) {
    final hex = r.santierColor;
    if (hex == null) return const Color(0xFF1E88E5);
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF1E88E5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: ApprovalTheme.textSecondary(context),
            ),
            const SizedBox(width: 4),
            Text(
              'Comenzi șantier (${widget.comenzi.length})',
              style: TextStyle(
                  fontSize: 12,
                  color: ApprovalTheme.textSecondary(context),
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      ),
      if (_expanded)
        ...widget.comenzi.map((r) {
          final color = _santierColor(r);
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(widget.isDark ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(ApprovalTheme.radiusSmall),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${_fmtDate(r.dataStart)} – ${_fmtDate(r.dataFinal)}',
                    style: TextStyle(fontSize: 12,
                        color: ApprovalTheme.textBody(context).color),
                  ),
                  if (r.santierNume?.isNotEmpty == true)
                    Text(r.santierNume!, style: ApprovalTheme.textSmall(context)),
                ]),
              ),
              _StatusPill(isAprobat: r.isAprobat),
              if (r.comenzaId != null && r.comenzaId!.isNotEmpty)
                _PrelungitaBadge(comenzaId: r.comenzaId!),
            ]),
          );
        }),
      const SizedBox(height: 4),
    ]);
  }
}

class _StatusPill extends StatelessWidget {
  final bool isAprobat;
  const _StatusPill({required this.isAprobat});

  @override
  Widget build(BuildContext context) {
    final color = isAprobat ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isAprobat ? 'Aprobat' : 'Pending',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isAprobat ? Colors.green.shade700 : Colors.orange.shade700),
      ),
    );
  }
}

class _PrelungitaBadge extends StatefulWidget {
  final String comenzaId;
  const _PrelungitaBadge({required this.comenzaId});

  @override
  State<_PrelungitaBadge> createState() => _PrelungitaBadgeState();
}

class _PrelungitaBadgeState extends State<_PrelungitaBadge> {
  late final Future<({bool prelungita, String? motiv})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({bool prelungita, String? motiv})> _load() async {
    final doc = await FirebaseFirestore.instance
        .collection('comenzi')
        .doc(widget.comenzaId)
        .get();
    if (!doc.exists) return (prelungita: false, motiv: null);
    final data = doc.data()!;
    return (
    prelungita: (data['prelungita'] as bool?) ?? false,
    motiv:      data['motivPrelungire'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({bool prelungita, String? motiv})>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.prelungita) return const SizedBox.shrink();
        final motiv      = snap.data!.motiv;
        final successCol = ApprovalTheme.successColor(context);
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Tooltip(
            message: motiv?.isNotEmpty == true ? 'Prelungit: $motiv' : 'Prelungit cu 1 zi',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: successCol.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: successCol.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event_repeat_outlined, size: 9, color: successCol),
                const SizedBox(width: 2),
                Text('+1zi', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700, color: successCol)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// Filter Sheet
class _FilterSheet extends StatefulWidget {
  final List<Vehicle> vehicles;
  final _VehicleFilter current;
  const _FilterSheet({required this.vehicles, required this.current});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _clasa, _subclasa;
  VehicleStatus? _status;
  DateTimeRange? _ocupare;

  @override
  void initState() {
    super.initState();
    _clasa    = widget.current.clasa;
    _subclasa = widget.current.subclasa;
    _status   = widget.current.status;
    _ocupare  = widget.current.ocupare;
  }

  List<String> get _clasaOptions => widget.vehicles
      .map((v) => v.clasa)
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<String> get _subclasaOptions => widget.vehicles
      .where((v) => _clasa == null || v.clasa == _clasa)
      .map((v) => v.subclasa)
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  void _clearAll() => setState(() {
    _clasa = null; _subclasa = null; _status = null; _ocupare = null;
  });

  @override
  Widget build(BuildContext context) {
    final l  = AppLocalizations.of(context);
    final mq = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.75),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text(l.translate('filterVehicles'), style: ApprovalTheme.textTitle(context)),
            const Spacer(),
            TextButton(onPressed: _clearAll, child: Text(l.translate('clearFilters'))),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FilterDropdown<String>(
                label: l.translate('class'),
                value: _clasa,
                items: _clasaOptions,
                itemLabel: (v) => v,
                onChanged: (v) => setState(() { _clasa = v; _subclasa = null; }),
              ),
              const SizedBox(height: 12),
              _FilterDropdown<String>(
                label: l.translate('subclass'),
                value: _subclasa,
                items: _subclasaOptions,
                itemLabel: (v) => v,
                onChanged: (v) => setState(() => _subclasa = v),
              ),
              const SizedBox(height: 12),
              _FilterDropdown<VehicleStatus>(
                label: l.translate('status'),
                value: _status,
                items: VehicleStatus.values,
                itemLabel: (s) => l.translate(s.translationKey),
                onChanged: (v) => setState(() => _status = v),
              ),
              const SizedBox(height: 12),
              Text(l.translate('occupancyPeriod'), style: ApprovalTheme.textBody(context)),
              const SizedBox(height: 6),
              _DateRangePicker(
                value: _ocupare,
                hintText: l.translate('selectPeriod'),
                onPicked: (r) => setState(() => _ocupare = r),
                onClear:  () => setState(() => _ocupare = null),
              ),
            ]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + mq.viewInsets.bottom),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _VehicleFilter(
                clasa: _clasa, subclasa: _subclasa,
                status: _status, ocupare: _ocupare,
              )),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium)),
              ),
              child: Text(l.translate('applyFilter')),
            ),
          ),
        ),
      ]),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: ApprovalTheme.textBody(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ApprovalTheme.radiusSmall),
          borderSide: BorderSide(color: ApprovalTheme.borderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ApprovalTheme.radiusSmall),
          borderSide: BorderSide(color: ApprovalTheme.borderColor(context)),
        ),
        filled: true,
        fillColor: ApprovalTheme.surfaceBackground(context),
        isDense: true,
      ),
      style: ApprovalTheme.textBody(context),
      dropdownColor: ApprovalTheme.surfaceBackground(context),
      items: [
        DropdownMenuItem<T>(
            value: null,
            child: Text(l.translate('all'), style: ApprovalTheme.textBody(context))),
        ...items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(itemLabel(item), style: ApprovalTheme.textBody(context)))),
      ],
      onChanged: onChanged,
    );
  }
}

class _DateRangePicker extends StatelessWidget {
  final DateTimeRange? value;
  final String hintText;
  final void Function(DateTimeRange) onPicked;
  final VoidCallback onClear;

  const _DateRangePicker({
    required this.value,
    required this.hintText,
    required this.onPicked,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          initialDateRange: value,
        );
        if (range != null) onPicked(range);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: ApprovalTheme.borderColor(context)),
          borderRadius: BorderRadius.circular(ApprovalTheme.radiusSmall),
          color: ApprovalTheme.surfaceBackground(context),
        ),
        child: Row(children: [
          Icon(Icons.date_range_outlined,
              size: 18, color: ApprovalTheme.textSecondary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value != null
                  ? '${_fmtDate(value!.start)} – ${_fmtDate(value!.end)}'
                  : hintText,
              style: ApprovalTheme.textBody(context).copyWith(
                color: value != null ? null : ApprovalTheme.textSecondary(context),
              ),
            ),
          ),
          if (value != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close,
                  size: 16, color: ApprovalTheme.textSecondary(context)),
            ),
        ]),
      ),
    );
  }
}