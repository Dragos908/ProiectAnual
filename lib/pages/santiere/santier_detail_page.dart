import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/models/comanda_model.dart';
import '/services/comanda_service.dart';
import '/models/occupancy_period.dart';
import '/models/santier_model.dart';
import '/approval_theme.dart';
import '/models/user.dart';
import '/widgets/comanda_form_sheet.dart';
import '/services/santier_service.dart';
import 'santiere_list_page.dart';

final _dateFmt      = DateFormat('dd.MM.yyyy HH:mm');
final _dateFmtShort = DateFormat('dd.MM.yyyy');

String _formatDateRangeShort(DateTime? start, DateTime? end) {
  if (start == null && end == null) return 'Dată nespecificată';
  if (start == null) return '– ${_dateFmtShort.format(end!)}';
  if (end == null) return '${_dateFmtShort.format(start)} –';
  return '${_dateFmtShort.format(start)} – ${_dateFmtShort.format(end)}';
}

// =============================================================================
// SantierDetailPage
// =============================================================================

class SantierDetailPage extends StatefulWidget {
  final String santierId;
  final User currentUser;

  const SantierDetailPage({
    super.key,
    required this.santierId,
    required this.currentUser,
  });

  @override
  State<SantierDetailPage> createState() => _SantierDetailPageState();
}

class _SantierDetailPageState extends State<SantierDetailPage> {
  Santier? _santier;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Santier?>(
        stream: SantierService.streamById(widget.santierId),
        builder: (ctx, santierSnap) {
          if (santierSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final santier = santierSnap.data;
          if (santier == null) {
            return const Center(child: Text('Șantierul nu a fost găsit.'));
          }
          _santier = santier;

          return NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(
                child: _SantierHeader(
                  santier: santier,
                  currentUser: widget.currentUser,
                ),
              ),
            ],
            body: _ComenziBody(
              santier: santier,
              currentUser: widget.currentUser,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateComandaSheet,
        backgroundColor: ApprovalTheme.primaryAccent(context),
        icon: const Icon(Icons.add),
        label: const Text('Comandă nouă'),
      ),
    );
  }

  void _openCreateComandaSheet() {
    if (_santier == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComandaFormSheet(
        santierId: _santier!.id,
        santierNume: _santier!.denumire,
        santierDataIncepere: _santier!.dataIncepere ?? DateTime.now(),
        currentUser: widget.currentUser,
      ),
    );
  }
}

// =============================================================================
// _SantierHeader
// =============================================================================

class _SantierHeader extends StatelessWidget {
  final Santier santier;
  final User currentUser;

  const _SantierHeader({required this.santier, required this.currentUser});

  // Userul poate edita doar propriul șantier.
  bool get _canEdit => santier.creatDeUserId == currentUser.uid;

  @override
  Widget build(BuildContext context) {
    final barColor = _santierStatusColor(santier.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBar(
          title: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text('Șantiere',
                  style: ApprovalTheme.textSmall(context)
                      .copyWith(color: ApprovalTheme.primaryAccent(context))),
            ),
            Text(' › ', style: ApprovalTheme.textSmall(context)),
            Flexible(
              child: Text(santier.denumire,
                  overflow: TextOverflow.ellipsis,
                  style: ApprovalTheme.textSmall(context)),
            ),
          ]),
          actions: [
            if (_canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editează șantier',
                onPressed: () => _openEditSheet(context),
              ),
          ],
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          decoration: BoxDecoration(
            color: _santierRowColor(context, santier.status),
            borderRadius:
            BorderRadius.circular(ApprovalTheme.radiusMedium),
            border: Border.all(
                color: ApprovalTheme.borderColor(context),
                width: ApprovalTheme.borderWidth),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(ApprovalTheme.radiusMedium),
                    bottomLeft: Radius.circular(ApprovalTheme.radiusMedium),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(santier.denumire,
                                style: ApprovalTheme.textTitle(context)
                                    .copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          _SantierStatusBadge(status: santier.status),
                          const SizedBox(width: 12),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _InfoRow(
                          icon: Icons.location_on_outlined,
                          text: santier.locatie,
                          context: context),
                      const SizedBox(height: 3),
                      _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          text: _formatDateRangeShort(
                              santier.dataIncepere, santier.dataFinalizare),
                          context: context),
                      const SizedBox(height: 3),
                      _InfoRow(
                          icon: Icons.person_outline,
                          text: 'Creat de: ${santier.creatDeNume}',
                          context: context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditSantierSheet(
        santier: santier,
        currentUser: currentUser,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final BuildContext context;

  const _InfoRow(
      {required this.icon, required this.text, required this.context});

  @override
  Widget build(BuildContext outerContext) {
    return Row(children: [
      Icon(icon, size: 13, color: ApprovalTheme.textSecondary(context)),
      const SizedBox(width: 4),
      Expanded(child: Text(text, style: ApprovalTheme.textSmall(context))),
    ]);
  }
}

// =============================================================================
// _ComenziBody
// =============================================================================

class _ComenziBody extends StatelessWidget {
  final Santier santier;
  final User currentUser;

  const _ComenziBody({required this.santier, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Comanda>>(
      stream: ComenzaService.comenziStream(santier.id, currentUser),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off_outlined,
                    size: 48, color: ApprovalTheme.errorColor(context)),
                const SizedBox(height: 12),
                Text('Eroare: ${snap.error}',
                    style: ApprovalTheme.textBody(context),
                    textAlign: TextAlign.center),
              ]),
            ),
          );
        }

        final all = snap.data ?? [];

        if (all.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox_outlined,
                  size: 48, color: ApprovalTheme.textSecondary(context)),
              const SizedBox(height: 12),
              Text('Nicio comandă pentru acest șantier.',
                  style: ApprovalTheme.textBody(context)),
            ]),
          );
        }

        final activ = all
            .where((c) => c.vizibilitate == ComandaVizibilitate.activActiv)
            .toList();
        final planificat = all
            .where(
                (c) => c.vizibilitate == ComandaVizibilitate.activPlanificat)
            .toList();
        final pending = all
            .where((c) =>
        c.vizibilitate == ComandaVizibilitate.neaprobatPending)
            .toList();

        return ListView(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 80),
          children: [
            if (activ.isNotEmpty) ...[
              _SectionHeader(title: 'Activ', count: activ.length),
              ...activ.map((c) => _ComandaCard(
                comanda: c,
                santier: santier,
                currentUser: currentUser,
                vizType: ComandaVizibilitate.activActiv,
              )),
            ],
            if (planificat.isNotEmpty) ...[
              _SectionHeader(title: 'Planificat', count: planificat.length),
              ...planificat.map((c) => _ComandaCard(
                comanda: c,
                santier: santier,
                currentUser: currentUser,
                vizType: ComandaVizibilitate.activPlanificat,
              )),
            ],
            if (pending.isNotEmpty) ...[
              _SectionHeader(title: 'În așteptare', count: pending.length),
              ...pending.map((c) => _ComandaCard(
                comanda: c,
                santier: santier,
                currentUser: currentUser,
                vizType: ComandaVizibilitate.neaprobatPending,
              )),
            ],
          ],
        );
      },
    );
  }
}

// =============================================================================
// _SectionHeader
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(children: [
        Text(title.toUpperCase(),
            style: ApprovalTheme.textSmall(context).copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            )),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: ApprovalTheme.primaryAccent(context).withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: ApprovalTheme.textSmall(context).copyWith(
                color: ApprovalTheme.primaryAccent(context),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              )),
        ),
      ]),
    );
  }
}

// =============================================================================
// _ComandaCard
// =============================================================================

class _ComandaCard extends StatelessWidget {
  final Comanda comanda;
  final Santier santier;
  final User currentUser;
  final ComandaVizibilitate vizType;

  const _ComandaCard({
    required this.comanda,
    required this.santier,
    required this.currentUser,
    required this.vizType,
  });

  Color _barColor(BuildContext context) {
    switch (comanda.status) {
      case ComandaStatus.aprobat:
        return vizType == ComandaVizibilitate.activActiv
            ? const Color(0xFF1A6B3C)
            : const Color(0xFF1565C0);
      case ComandaStatus.respins:
        return ApprovalTheme.errorColor(context);
      case ComandaStatus.pending:
        return Colors.orange;
    }
  }

  Color _bgColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (comanda.status) {
      case ComandaStatus.aprobat:
        return vizType == ComandaVizibilitate.activActiv
            ? (isDark
            ? const Color(0xFF1B3A24)
            : const Color(0xFFD4EDDA))
            : (isDark
            ? const Color(0xFF0A2A4D)
            : const Color(0xFFD6E9FF));
      case ComandaStatus.respins:
        return isDark ? const Color(0xFF3D0000) : const Color(0xFFF8D7DA);
      case ComandaStatus.pending:
        return isDark ? const Color(0xFF3D2E00) : const Color(0xFFFFF3CD);
    }
  }

  // Userul poate edita propria comandă dacă nu e respinsă.
  bool get _canEdit =>
      comanda.status != ComandaStatus.respins &&
          currentUser.uid == comanda.creatDeUserId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      color: _bgColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
        side: BorderSide(
            color: ApprovalTheme.borderColor(context),
            width: ApprovalTheme.borderWidth),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ComandaDetailSheet(
            comanda: comanda,
            santier: santier,
            currentUser: currentUser,
            canEdit: _canEdit,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3, height: 44,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: _barColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comanda.vehicleModel,
                        style: ApprovalTheme.textTitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.category_outlined,
                          size: 11,
                          color: ApprovalTheme.textSecondary(context)),
                      const SizedBox(width: 2),
                      Text(comanda.vehicleClasa,
                          style: ApprovalTheme.textSmall(context)),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.date_range_outlined,
                          size: 11,
                          color: ApprovalTheme.textSecondary(context)),
                      const SizedBox(width: 2),
                      Text(
                        '${_dateFmtShort.format(comanda.dataStart)} – '
                            '${_dateFmtShort.format(comanda.dataFinal)}',
                        style: ApprovalTheme.textSmall(context),
                      ),
                    ]),
                    if (comanda.note != null && comanda.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.notes_outlined,
                            size: 11,
                            color: ApprovalTheme.textSecondary(context)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(comanda.note!,
                              style: ApprovalTheme.textSmall(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ComandaBadge(comanda: comanda, vizType: vizType),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _ComandaBadge
// =============================================================================

class _ComandaBadge extends StatelessWidget {
  final Comanda comanda;
  final ComandaVizibilitate vizType;
  const _ComandaBadge({required this.comanda, required this.vizType});

  String get _label {
    switch (comanda.status) {
      case ComandaStatus.respins:
        return 'Respins';
      case ComandaStatus.pending:
        return 'Așteptare';
      case ComandaStatus.aprobat:
        return vizType == ComandaVizibilitate.activActiv
            ? 'Activ'
            : 'Planificat';
    }
  }

  Color get _color {
    switch (comanda.status) {
      case ComandaStatus.aprobat:
        return vizType == ComandaVizibilitate.activActiv
            ? const Color(0xFF1A6B3C)
            : const Color(0xFF1565C0);
      case ComandaStatus.respins:
        return ApprovalTheme.errorColorLight;
      case ComandaStatus.pending:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ApprovalTheme.badgeDecoration(_color),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(_label, style: ApprovalTheme.badgeTextStyle(_color)),
    );
  }
}

// =============================================================================
// _ComandaDetailSheet
// =============================================================================

class _ComandaDetailSheet extends StatelessWidget {
  final Comanda comanda;
  final Santier santier;
  final User currentUser;
  final bool canEdit;

  const _ComandaDetailSheet({
    required this.comanda,
    required this.santier,
    required this.currentUser,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.75),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
                child: Text(comanda.vehicleModel,
                    style: ApprovalTheme.textTitle(context))),
            _ComandaBadge(comanda: comanda, vizType: comanda.vizibilitate),
          ]),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding:
            EdgeInsets.fromLTRB(16, 12, 16, mq.viewInsets.bottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Clasă', value: comanda.vehicleClasa),
                _DetailRow(
                    label: 'Start',
                    value: _dateFmt.format(comanda.dataStart)),
                _DetailRow(
                    label: 'Final',
                    value: _dateFmt.format(comanda.dataFinal)),
                _DetailRow(label: 'Creat de', value: comanda.creatDeNume),
                _DetailRow(
                    label: 'Creat la',
                    value: _dateFmt.format(comanda.createdAt)),
                if (comanda.note != null && comanda.note!.isNotEmpty)
                  _DetailRow(label: 'Note', value: comanda.note!),
                if (comanda.status == ComandaStatus.respins &&
                    comanda.motivRespingere != null) ...[
                  const SizedBox(height: 4),
                  _DetailRow(
                    label: 'Motiv respingere',
                    value: comanda.motivRespingere!,
                    valueColor: ApprovalTheme.errorColorLight,
                  ),
                ],
                const SizedBox(height: 16),
                if (canEdit)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editează comanda'),
                      style: ApprovalTheme.primaryButtonStyle(context),
                      onPressed: () {
                        Navigator.of(context).pop();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ComandaFormSheet(
                            santierId: santier.id,
                            santierNume: santier.denumire,
                            santierDataIncepere:
                            santier.dataIncepere ?? DateTime.now(),
                            currentUser: currentUser,
                            existingComanda: comanda,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// _DetailRow
// =============================================================================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 120,
          child: Text('$label:',
              style: ApprovalTheme.textSmall(context)
                  .copyWith(color: ApprovalTheme.textSecondary(context))),
        ),
        Expanded(
          child: Text(value,
              style: ApprovalTheme.textSmall(context).copyWith(
                color: valueColor,
                fontWeight: valueColor != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              )),
        ),
      ]),
    );
  }
}

// =============================================================================
// _SantierStatusBadge
// =============================================================================

class _SantierStatusBadge extends StatelessWidget {
  final SantierStatus status;
  const _SantierStatusBadge({required this.status});

  Color _color() {
    switch (status) {
      case SantierStatus.activ:
        return const Color(0xFF1A6B3C);
      case SantierStatus.suspendat:
        return ApprovalTheme.errorColorLight;
      case SantierStatus.arhivat:
        return ApprovalTheme.textSecondaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      decoration: ApprovalTheme.badgeDecoration(color),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(status.displayLabel,
          style: ApprovalTheme.badgeTextStyle(color)),
    );
  }
}

// =============================================================================
// _SheetHandle
// =============================================================================

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

// ── Status → color helpers ────────────────────────────────────────────────────

Color _santierStatusColor(SantierStatus status) {
  switch (status) {
    case SantierStatus.activ:
      return const Color(0xFF1A6B3C);
    case SantierStatus.suspendat:
      return ApprovalTheme.errorColorLight;
    case SantierStatus.arhivat:
      return ApprovalTheme.textSecondaryLight;
  }
}

Color _santierRowColor(BuildContext context, SantierStatus status) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  switch (status) {
    case SantierStatus.activ:
      return isDark ? const Color(0xFF1B3A24) : const Color(0xFFD4EDDA);
    case SantierStatus.suspendat:
      return isDark ? const Color(0xFF3D0000) : const Color(0xFFF8D7DA);
    case SantierStatus.arhivat:
      return isDark ? ApprovalTheme.cardBackground(context) : Colors.white;
  }
}