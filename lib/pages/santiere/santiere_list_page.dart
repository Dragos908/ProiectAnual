import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '/approval_theme.dart';
import '/models/user.dart';
import '/models/santier_model.dart';
import '/services/santier_service.dart';
import '/widgets/santiere_filter.dart' as sf;
import 'santier_detail_page.dart';

final _dateFmt = DateFormat('dd.MM.yyyy');

// =============================================================================
// SantiereListPage
// =============================================================================

class SantiereListPage extends StatefulWidget {
  final User currentUser;
  const SantiereListPage({super.key, required this.currentUser});

  @override
  State<SantiereListPage> createState() => _SantiereListPageState();
}

class _SantiereListPageState extends State<SantiereListPage> {
  final Map<SantierStatus, GlobalKey> _groupKeys = {
    SantierStatus.activ:     GlobalKey(),
    SantierStatus.suspendat: GlobalKey(),
    SantierStatus.arhivat:   GlobalKey(),
  };

  sf.SantiereFilter _filter = const sf.SantiereFilter();

  // Userul simplu vede doar propriile santiere.
  Stream<List<Santier>> get _stream =>
      SantierService.streamByUser(widget.currentUser.uid);

  void _scrollToGroup(SantierStatus status) {
    final ctx = _groupKeys[status]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateSantierSheet(
        currentUser: widget.currentUser,
        onCreated: (santierId) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SantierDetailPage(
              santierId: santierId,
              currentUser: widget.currentUser,
            ),
          ));
        },
      ),
    );
  }

  void _openFilterSheet() async {
    final result = await showModalBottomSheet<sf.SantiereFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(currentFilter: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Șantiere')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSheet,
        backgroundColor: ApprovalTheme.primaryAccent(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Santier>>(
        stream: _stream,
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
                  Text('Eroare la încărcare: ${snapshot.error}',
                      style: ApprovalTheme.textBody(context),
                      textAlign: TextAlign.center),
                ]),
              ),
            );
          }

          final all = snapshot.data ?? [];
          final displayed = _filter.apply(all);

          return Column(
            children: [
              _StickyHeader(
                filter: _filter,
                onAnchorTap: _scrollToGroup,
                onFilterTap: _openFilterSheet,
              ),
              Expanded(
                child: displayed.isEmpty
                    ? Center(
                    child: Text('Nu există șantiere.',
                        style: ApprovalTheme.textBody(context)))
                    : ListView(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 8),
                  children: [
                    for (final status in SantierStatus.values)
                      if (displayed.any((s) => s.status == status)) ...[
                        _GroupHeader(
                            key: _groupKeys[status], status: status),
                        for (final santier
                        in displayed.where((s) => s.status == status))
                          _SantierCard(
                            santier: santier,
                            currentUser: widget.currentUser,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => SantierDetailPage(
                                  santierId: santier.id,
                                  currentUser: widget.currentUser,
                                ),
                              ));
                            },
                          ),
                      ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// _StickyHeader
// =============================================================================

class _StickyHeader extends StatelessWidget {
  final sf.SantiereFilter filter;
  final void Function(SantierStatus) onAnchorTap;
  final VoidCallback onFilterTap;

  const _StickyHeader({
    required this.filter,
    required this.onAnchorTap,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(children: [
        Expanded(child: _AnchorButton(
          label: 'Activi',
          color: const Color(0xFF1A6B3C),
          onTap: () => onAnchorTap(SantierStatus.activ),
        )),
        const SizedBox(width: 6),
        Expanded(child: _AnchorButton(
          label: 'Suspendați',
          color: ApprovalTheme.errorColor(context),
          onTap: () => onAnchorTap(SantierStatus.suspendat),
        )),
        const SizedBox(width: 6),
        Expanded(child: _AnchorButton(
          label: 'Arhivați',
          color: ApprovalTheme.textSecondary(context),
          onTap: () => onAnchorTap(SantierStatus.arhivat),
        )),
        const SizedBox(width: 6),
        _FilterButton(filter: filter, onFilter: onFilterTap),
      ]),
    );
  }
}

class _AnchorButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AnchorButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: color, width: 1.4),
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(ApprovalTheme.radiusSmall)),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 11, color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center),
  );
}

class _FilterButton extends StatelessWidget {
  final sf.SantiereFilter filter;
  final VoidCallback onFilter;
  const _FilterButton({required this.filter, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    final active = filter.isActive;
    final color = active
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
            padding:
            const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(ApprovalTheme.radiusSmall)),
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
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// _GroupHeader
// =============================================================================

class _GroupHeader extends StatelessWidget {
  final SantierStatus status;
  const _GroupHeader({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Text(
        status.displayLabel.toUpperCase(),
        style: ApprovalTheme.textSmall(context).copyWith(
          fontWeight: FontWeight.bold,
          color: _statusColor(context, status),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// =============================================================================
// _SantierCard
// =============================================================================

class _SantierCard extends StatelessWidget {
  final Santier santier;
  final User currentUser;
  final VoidCallback onTap;

  const _SantierCard({
    required this.santier,
    required this.currentUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor  = _rowColor(context, santier.status);
    final barColor = _statusColor(context, santier.status);

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
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(santier.denumire,
                        style: ApprovalTheme.textTitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 11,
                          color: ApprovalTheme.textSecondary(context)),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          '${santier.locatie} · ${santier.creatDeNume}',
                          style: ApprovalTheme.textSmall(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 11,
                          color: ApprovalTheme.textSecondary(context)),
                      const SizedBox(width: 2),
                      Text(
                        _formatDateRange(
                            santier.dataIncepere, santier.dataFinalizare),
                        style: ApprovalTheme.textSmall(context),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: santier.status),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _StatusBadge
// =============================================================================

class _StatusBadge extends StatelessWidget {
  final SantierStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    return Container(
      decoration: ApprovalTheme.badgeDecoration(color),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(status.displayLabel, style: ApprovalTheme.badgeTextStyle(color)),
    );
  }
}

// =============================================================================
// _CreateSantierSheet
// =============================================================================

class _CreateSantierSheet extends StatefulWidget {
  final User currentUser;
  final void Function(String santierId) onCreated;

  const _CreateSantierSheet(
      {required this.currentUser, required this.onCreated});

  @override
  State<_CreateSantierSheet> createState() => _CreateSantierSheetState();
}

class _CreateSantierSheetState extends State<_CreateSantierSheet> {
  final _formKey        = GlobalKey<FormState>();
  final _denumireCtrl   = TextEditingController();
  final _locatieCtrl    = TextEditingController();
  DateTime? _dataIncepere;
  DateTime? _dataFinalizare;
  bool _loading = false;

  @override
  void dispose() {
    _denumireCtrl.dispose();
    _locatieCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required DateTime? firstDate,
    required void Function(DateTime) onPicked,
  }) async {
    final effectiveFirst = firstDate ?? DateTime(2000);
    final now = DateTime.now();
    final effectiveInitial = initial != null
        ? (initial.isBefore(effectiveFirst) ? effectiveFirst : initial)
        : (now.isBefore(effectiveFirst) ? effectiveFirst : now);

    final picked = await showDatePicker(
      context: context,
      initialDate: effectiveInitial,
      firstDate: effectiveFirst,
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dataIncepere != null &&
        _dataFinalizare != null &&
        _dataFinalizare!.isBefore(_dataIncepere!)) {
      _showError('Data finalizare trebuie să fie >= data începere.');
      return;
    }

    setState(() => _loading = true);
    try {
      final id = await SantierService.createSantier(
        denumire:      _denumireCtrl.text,
        locatie:       _locatieCtrl.text,
        dataIncepere:  _dataIncepere,
        dataFinalizare: _dataFinalizare,
        creatDeUserId: widget.currentUser.uid,
        creatDeNume:   widget.currentUser.name,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Șantier creat cu succes.'),
        backgroundColor: ApprovalTheme.successColor(context),
      ));
      widget.onCreated(id);
    } on TimeoutException {
      _showError('Timeout — verificați conexiunea și încercați din nou.');
    } catch (e) {
      _showError('Eroare: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ApprovalTheme.errorColor(context),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints:
      BoxConstraints(maxHeight: mq.size.height * 0.9 - mq.viewInsets.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('Șantier nou', style: ApprovalTheme.textTitle(context)),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding:
            EdgeInsets.fromLTRB(16, 16, 16, mq.viewInsets.bottom + 16),
            child: Form(
              key: _formKey,
              child: Column(children: [
                TextFormField(
                  controller: _denumireCtrl,
                  style: ApprovalTheme.textBody(context),
                  decoration:
                  ApprovalTheme.inputDecoration(context, 'Denumire')
                      .copyWith(
                    prefixIcon: Icon(Icons.business_outlined,
                        color: ApprovalTheme.textSecondary(context), size: 20),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Minim 3 caractere.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locatieCtrl,
                  style: ApprovalTheme.textBody(context),
                  decoration:
                  ApprovalTheme.inputDecoration(context, 'Locație')
                      .copyWith(
                    prefixIcon: Icon(Icons.location_on_outlined,
                        color: ApprovalTheme.textSecondary(context), size: 20),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Câmp obligatoriu.' : null,
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: 'Data începere',
                  value: _dataIncepere,
                  onTap: () => _pickDate(
                    initial: _dataIncepere,
                    firstDate: null,
                    onPicked: (d) => setState(() => _dataIncepere = d),
                  ),
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: 'Data finalizare',
                  value: _dataFinalizare,
                  onTap: () => _pickDate(
                    initial: _dataFinalizare,
                    firstDate: _dataIncepere,
                    onPicked: (d) => setState(() => _dataFinalizare = d),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: ApprovalTheme.primaryButtonStyle(context),
                    child: _loading
                        ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Text('Creează'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// EditSantierSheet — editare câmpuri de bază (fără schimbare status / delete)
// =============================================================================

class EditSantierSheet extends StatefulWidget {
  final Santier santier;
  final User currentUser;

  const EditSantierSheet(
      {super.key, required this.santier, required this.currentUser});

  @override
  State<EditSantierSheet> createState() => _EditSantierSheetState();
}

class _EditSantierSheetState extends State<EditSantierSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _denumireCtrl;
  late final TextEditingController _locatieCtrl;
  DateTime? _dataIncepere;
  DateTime? _dataFinalizare;
  bool _loading = false;

  // Userul poate edita propriul șantier.
  bool get _canEdit => widget.santier.creatDeUserId == widget.currentUser.uid;

  @override
  void initState() {
    super.initState();
    _denumireCtrl   = TextEditingController(text: widget.santier.denumire);
    _locatieCtrl    = TextEditingController(text: widget.santier.locatie);
    _dataIncepere   = widget.santier.dataIncepere;
    _dataFinalizare = widget.santier.dataFinalizare;
  }

  @override
  void dispose() {
    _denumireCtrl.dispose();
    _locatieCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required DateTime? firstDate,
    required void Function(DateTime) onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dataIncepere != null &&
        _dataFinalizare != null &&
        _dataFinalizare!.isBefore(_dataIncepere!)) {
      _showError('Data finalizare trebuie să fie >= data începere.');
      return;
    }
    setState(() => _loading = true);
    try {
      await SantierService.updateSantier(
        santierId:         widget.santier.id,
        denumire:          _denumireCtrl.text,
        locatie:           _locatieCtrl.text,
        dataIncepere:      _dataIncepere,
        dataFinalizare:    _dataFinalizare,
        modificatDeUserId: widget.currentUser.uid,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Șantier actualizat.'),
        backgroundColor: ApprovalTheme.successColor(context),
      ));
    } catch (e) {
      _showError('Eroare: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ApprovalTheme.errorColor(context),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints:
      BoxConstraints(maxHeight: mq.size.height * 0.9 - mq.viewInsets.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('Editare șantier', style: ApprovalTheme.textTitle(context)),
            const Spacer(),
            _StatusBadge(status: widget.santier.status),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding:
            EdgeInsets.fromLTRB(16, 16, 16, mq.viewInsets.bottom + 16),
            child: _canEdit
                ? Form(
              key: _formKey,
              child: Column(children: [
                TextFormField(
                  controller: _denumireCtrl,
                  style: ApprovalTheme.textBody(context),
                  decoration:
                  ApprovalTheme.inputDecoration(context, 'Denumire')
                      .copyWith(
                    prefixIcon: Icon(Icons.business_outlined,
                        color: ApprovalTheme.textSecondary(context),
                        size: 20),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Minim 3 caractere.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locatieCtrl,
                  style: ApprovalTheme.textBody(context),
                  decoration:
                  ApprovalTheme.inputDecoration(context, 'Locație')
                      .copyWith(
                    prefixIcon: Icon(Icons.location_on_outlined,
                        color: ApprovalTheme.textSecondary(context),
                        size: 20),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Câmp obligatoriu.'
                      : null,
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: 'Data începere',
                  value: _dataIncepere,
                  onTap: () => _pickDate(
                    initial: _dataIncepere,
                    firstDate: null,
                    onPicked: (d) => setState(() => _dataIncepere = d),
                  ),
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: 'Data finalizare',
                  value: _dataFinalizare,
                  onTap: () => _pickDate(
                    initial: _dataFinalizare,
                    firstDate: _dataIncepere,
                    onPicked: (d) => setState(() => _dataFinalizare = d),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _save,
                    style: ApprovalTheme.primaryButtonStyle(context),
                    child: _loading
                        ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Text('Salvează'),
                  ),
                ),
              ]),
            )
                : Center(
              child: Text('Nu ai permisiunea de a edita acest șantier.',
                  style: ApprovalTheme.textBody(context),
                  textAlign: TextAlign.center),
            ),
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// _FilterSheet — fără filtru după utilizator (simpleUser vede doar ale lui)
// =============================================================================

class _FilterSheet extends StatefulWidget {
  final sf.SantiereFilter currentFilter;
  const _FilterSheet({required this.currentFilter});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SantierStatus? _status;
  sf.DateTimeRange?   _perioadaCreare;

  @override
  void initState() {
    super.initState();
    _status        = widget.currentFilter.status;
    _perioadaCreare = widget.currentFilter.perioadaCreare;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _perioadaCreare != null
          ? DateTimeRange(
          start: _perioadaCreare!.start, end: _perioadaCreare!.end)
          : null,
    );
    if (picked != null) {
      setState(() => _perioadaCreare =
          sf.DateTimeRange(start: picked.start, end: picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Filtru șantiere', style: ApprovalTheme.textTitle(context)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _status = null;
                _perioadaCreare = null;
              }),
              child: const Text('Resetează'),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterDropdown<SantierStatus>(
                    label: 'Status',
                    value: _status,
                    items: SantierStatus.values,
                    itemLabel: (s) => s.displayLabel,
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  const SizedBox(height: 12),
                  Text('Perioadă creare', style: ApprovalTheme.textBody(context)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: ApprovalTheme.borderColor(context)),
                        borderRadius: BorderRadius.circular(
                            ApprovalTheme.radiusSmall),
                        color: ApprovalTheme.surfaceBackground(context),
                      ),
                      child: Row(children: [
                        Icon(Icons.date_range_outlined,
                            size: 18,
                            color: ApprovalTheme.textSecondary(context)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _perioadaCreare != null
                                ? '${_dateFmt.format(_perioadaCreare!.start)} – '
                                '${_dateFmt.format(_perioadaCreare!.end)}'
                                : 'Orice dată',
                            style: ApprovalTheme.textBody(context).copyWith(
                              color: _perioadaCreare != null
                                  ? null
                                  : ApprovalTheme.textSecondary(context),
                            ),
                          ),
                        ),
                        if (_perioadaCreare != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _perioadaCreare = null),
                            child: Icon(Icons.close,
                                size: 16,
                                color: ApprovalTheme.textSecondary(context)),
                          ),
                      ]),
                    ),
                  ),
                ]),
          ),
        ),
        Padding(
          padding:
          EdgeInsets.fromLTRB(16, 8, 16, 16 + mq.viewInsets.bottom),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                sf.SantiereFilter(
                  status: _status,
                  perioadaCreare: _perioadaCreare,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        ApprovalTheme.radiusMedium)),
              ),
              child: const Text('Aplică filtrul'),
            ),
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// Reusable helpers
// =============================================================================

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
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: ApprovalTheme.textBody(context),
        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(ApprovalTheme.radiusSmall),
          borderSide:
          BorderSide(color: ApprovalTheme.borderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(ApprovalTheme.radiusSmall),
          borderSide:
          BorderSide(color: ApprovalTheme.borderColor(context)),
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
            child: Text('Toate', style: ApprovalTheme.textBody(context))),
        ...items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(itemLabel(item),
                style: ApprovalTheme.textBody(context)))),
      ],
      onChanged: onChanged,
    );
  }
}

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

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateField(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: ApprovalTheme.textBody(context)
              .copyWith(color: ApprovalTheme.textSecondary(context)),
          border: OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(ApprovalTheme.radiusSmall),
              borderSide:
              BorderSide(color: ApprovalTheme.borderColor(context))),
          enabledBorder: OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(ApprovalTheme.radiusSmall),
              borderSide:
              BorderSide(color: ApprovalTheme.borderColor(context))),
          filled: true,
          fillColor: ApprovalTheme.surfaceBackground(context),
          prefixIcon: Icon(Icons.calendar_today_outlined,
              size: 18, color: ApprovalTheme.textSecondary(context)),
          suffixIcon: Icon(Icons.arrow_drop_down,
              color: ApprovalTheme.textSecondary(context)),
        ),
        child: Text(
          value != null ? _dateFmt.format(value!) : 'Selectați data',
          style: value != null
              ? ApprovalTheme.textSmall(context)
              : ApprovalTheme.textSmall(context)
              .copyWith(color: ApprovalTheme.textSecondary(context)),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _formatDateRange(DateTime? start, DateTime? end) {
  if (start == null && end == null) return 'Dată nespecificată';
  if (start == null) return '– ${_dateFmt.format(end!)}';
  if (end == null) return '${_dateFmt.format(start)} –';
  return '${_dateFmt.format(start)} – ${_dateFmt.format(end)}';
}

Color _statusColor(BuildContext context, SantierStatus status) {
  switch (status) {
    case SantierStatus.activ:
      return const Color(0xFF1A6B3C);
    case SantierStatus.suspendat:
      return ApprovalTheme.errorColor(context);
    case SantierStatus.arhivat:
      return ApprovalTheme.textSecondary(context);
  }
}

Color _rowColor(BuildContext context, SantierStatus status) {
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