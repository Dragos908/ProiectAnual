import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '/app_localizations.dart';
import '/approval_theme.dart';
import '/models/user.dart';
import '/models/santier_model.dart';
import '/services/santier_service.dart';
import '/widgets/santiere_filter.dart' as sf;
import 'santier_detail_page.dart';

final _dateFmt = DateFormat('dd.MM.yyyy');


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

  Stream<List<Santier>> get _stream =>
      SantierService.streamAll();

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
        onCreated: (id) => Navigator.push(context, MaterialPageRoute(
          builder: (_) => SantierDetailPage(
              santierId: id, currentUser: widget.currentUser),
        )),
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

  void _navigateToDetail(String santierId) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SantierDetailPage(
          santierId: santierId, currentUser: widget.currentUser),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  Text('${AppLocalizations.of(context).loadError}: ${snapshot.error}',
                      style: ApprovalTheme.textBody(context),
                      textAlign: TextAlign.center),
                ]),
              ),
            );
          }

          final displayed = _filter.apply(snapshot.data ?? []);

          return Column(children: [
            _StickyHeader(
              filter: _filter,
              onAnchorTap: _scrollToGroup,
              onFilterTap: _openFilterSheet,
            ),
            Expanded(
              child: displayed.isEmpty
                  ? Center(child: Text(AppLocalizations.of(context).noSantiere,
                  style: ApprovalTheme.textBody(context)))
                  : ListView(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 8),
                children: [
                  for (final status in SantierStatus.values)
                    if (displayed.any((s) => s.status == status)) ...[
                      _GroupHeader(key: _groupKeys[status], status: status),
                      for (final santier
                      in displayed.where((s) => s.status == status))
                        _SantierCard(
                          santier: santier,
                          currentUser: widget.currentUser,
                          onTap: () => _navigateToDetail(santier.id),
                        ),
                    ],
                ],
              ),
            ),
          ]);
        },
      ),
    );
  }
}

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
          label: AppLocalizations.of(context).santiereActivi,
          color: const Color(0xFF1A6B3C),
          onTap: () => onAnchorTap(SantierStatus.activ),
        )),
        const SizedBox(width: 6),
        Expanded(child: _AnchorButton(
          label: AppLocalizations.of(context).santiereSuspendati,
          color: ApprovalTheme.errorColor(context),
          onTap: () => onAnchorTap(SantierStatus.suspendat),
        )),
        const SizedBox(width: 6),
        Expanded(child: _AnchorButton(
          label: AppLocalizations.of(context).santiereArhivati,
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
  final sf.SantiereFilter filter;
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

class _GroupHeader extends StatelessWidget {
  final SantierStatus status;
  const _GroupHeader({super.key, required this.status});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
    child: Text(
      switch (status) {
        SantierStatus.activ     => AppLocalizations.of(context).translate('statusActiv'),
        SantierStatus.suspendat => AppLocalizations.of(context).translate('statusSuspendat'),
        SantierStatus.arhivat   => AppLocalizations.of(context).translate('statusArhivat'),
      }.toUpperCase(),
      style: ApprovalTheme.textSmall(context).copyWith(
        fontWeight: FontWeight.bold,
        color: _statusColor(context, status),
        letterSpacing: 1.2,
      ),
    ),
  );
}

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
                    color: barColor, borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(santier.denumire,
                      style: ApprovalTheme.textTitle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 11, color: ApprovalTheme.textSecondary(context)),
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
                        size: 11, color: ApprovalTheme.textSecondary(context)),
                    const SizedBox(width: 2),
                    Text(
                      _formatDateRange(santier.dataIncepere, santier.dataFinalizare, AppLocalizations.of(context)),
                      style: ApprovalTheme.textSmall(context),
                    ),
                  ]),
                ]),
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

class _StatusBadge extends StatelessWidget {
  final SantierStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    return Container(
      decoration: ApprovalTheme.badgeDecoration(color),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        switch (status) {
          SantierStatus.activ     => AppLocalizations.of(context).translate('statusActiv'),
          SantierStatus.suspendat => AppLocalizations.of(context).translate('statusSuspendat'),
          SantierStatus.arhivat   => AppLocalizations.of(context).translate('statusArhivat'),
        },
        style: ApprovalTheme.badgeTextStyle(color),
      ),
    );
  }
}

class _CreateSantierSheet extends StatefulWidget {
  final User currentUser;
  final void Function(String santierId) onCreated;

  const _CreateSantierSheet({required this.currentUser, required this.onCreated});

  @override
  State<_CreateSantierSheet> createState() => _CreateSantierSheetState();
}

class _CreateSantierSheetState extends State<_CreateSantierSheet> {
  final _formKey      = GlobalKey<FormState>();
  final _denumireCtrl = TextEditingController();
  final _locatieCtrl  = TextEditingController();
  DateTime? _dataIncepere, _dataFinalizare;
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
    final first   = firstDate ?? DateTime(2000);
    final now     = DateTime.now();
    final initial0 = initial != null
        ? (initial.isBefore(first) ? first : initial)
        : (now.isBefore(first) ? first : now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial0,
      firstDate: first,
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dataIncepere != null && _dataFinalizare != null &&
        _dataFinalizare!.isBefore(_dataIncepere!)) {
      _showError(AppLocalizations.of(context).dateFinalizareError);
      return;
    }
    setState(() => _loading = true);
    try {
      final id = await SantierService.createSantier(
        denumire:       _denumireCtrl.text,
        locatie:        _locatieCtrl.text,
        dataIncepere:   _dataIncepere,
        dataFinalizare: _dataFinalizare,
        creatDeUserId:  widget.currentUser.uid,
        creatDeNume:    widget.currentUser.name,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).santierCreated),
        backgroundColor: ApprovalTheme.successColor(context),
      ));
      widget.onCreated(id);
    } on TimeoutException {
      _showError(AppLocalizations.of(context).timeoutError);
    } catch (e) {
      _showError('${AppLocalizations.of(context).eroare}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: ApprovalTheme.errorColor(context)),
  );

  @override
  Widget build(BuildContext context) {
    final l  = AppLocalizations.of(context);
    final mq = MediaQuery.of(context);
    return _BottomSheetContainer(
      maxHeightFactor: 0.9,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const _SheetHandle(),
        _SheetTitleRow(title: l.santierNou),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, mq.viewInsets.bottom + 16),
            child: Form(
              key: _formKey,
              child: Column(children: [
                _NameField(controller: _denumireCtrl),
                const SizedBox(height: 12),
                _LocationField(controller: _locatieCtrl),
                const SizedBox(height: 12),
                _DateField(
                  label: l.dataIncepere,
                  value: _dataIncepere,
                  onTap: () => _pickDate(
                    initial: _dataIncepere,
                    firstDate: null,
                    onPicked: (d) => setState(() => _dataIncepere = d),
                  ),
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: l.dataFinalizare,
                  value: _dataFinalizare,
                  onTap: () => _pickDate(
                    initial: _dataFinalizare,
                    firstDate: _dataIncepere,
                    onPicked: (d) => setState(() => _dataFinalizare = d),
                  ),
                ),
                const SizedBox(height: 20),
                _SubmitButton(loading: _loading, label: l.creaza, onPressed: _submit),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// public — used from santier_detail_page
class EditSantierSheet extends StatefulWidget {
  final Santier santier;
  final User currentUser;

  const EditSantierSheet({super.key, required this.santier, required this.currentUser});

  @override
  State<EditSantierSheet> createState() => _EditSantierSheetState();
}

class _EditSantierSheetState extends State<EditSantierSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _denumireCtrl;
  late final TextEditingController _locatieCtrl;
  DateTime? _dataIncepere, _dataFinalizare;
  bool _loading = false;

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
    if (_dataIncepere != null && _dataFinalizare != null &&
        _dataFinalizare!.isBefore(_dataIncepere!)) {
      _showError(AppLocalizations.of(context).dateFinalizareError);
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
        content: Text(AppLocalizations.of(context).santierUpdated),
        backgroundColor: ApprovalTheme.successColor(context),
      ));
    } catch (e) {
      _showError('${AppLocalizations.of(context).eroare}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: ApprovalTheme.errorColor(context)),
  );

  @override
  Widget build(BuildContext context) {
    final l  = AppLocalizations.of(context);
    final mq = MediaQuery.of(context);
    return _BottomSheetContainer(
      maxHeightFactor: 0.9,
      child: Column(children: [
        const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text(l.editSantier, style: ApprovalTheme.textTitle(context)),
            const Spacer(),
            _StatusBadge(status: widget.santier.status),
            const SizedBox(width: 8),
            IconButton(onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, mq.viewInsets.bottom + 16),
            child: _canEdit
                ? Form(
              key: _formKey,
              child: Column(children: [
                _NameField(controller: _denumireCtrl),
                const SizedBox(height: 12),
                _LocationField(controller: _locatieCtrl),
                const SizedBox(height: 12),
                _DateField(
                  label: l.dataIncepere,
                  value: _dataIncepere,
                  onTap: () => _pickDate(
                    initial: _dataIncepere,
                    firstDate: null,
                    onPicked: (d) => setState(() => _dataIncepere = d),
                  ),
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: l.dataFinalizare,
                  value: _dataFinalizare,
                  onTap: () => _pickDate(
                    initial: _dataFinalizare,
                    firstDate: _dataIncepere,
                    onPicked: (d) => setState(() => _dataFinalizare = d),
                  ),
                ),
                const SizedBox(height: 16),
                _SubmitButton(loading: _loading, label: l.save, onPressed: _save),
              ]),
            )
                : Center(
              child: Text(l.noEditPermission,
                  style: ApprovalTheme.textBody(context),
                  textAlign: TextAlign.center),
            ),
          ),
        ),
      ]),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final sf.SantiereFilter currentFilter;
  const _FilterSheet({required this.currentFilter});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SantierStatus?    _status;
  sf.DateTimeRange?      _perioadaCreare;

  @override
  void initState() {
    super.initState();
    _status         = widget.currentFilter.status;
    _perioadaCreare = widget.currentFilter.perioadaCreare;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _perioadaCreare != null
          ? DateTimeRange(start: _perioadaCreare!.start, end: _perioadaCreare!.end)
          : null,
    );
    if (picked != null) {
      setState(() => _perioadaCreare =
          sf.DateTimeRange(start: picked.start, end: picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l  = AppLocalizations.of(context);
    final mq = MediaQuery.of(context);
    return _BottomSheetContainer(
      maxHeightFactor: 0.75,
      child: Column(children: [
        const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text(l.filtruSantiere, style: ApprovalTheme.textTitle(context)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _status = null; _perioadaCreare = null;
              }),
              child: Text(l.reset),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FilterDropdown<SantierStatus>(
                label: l.translate('status'),
                value: _status,
                items: SantierStatus.values,
                itemLabel: (s) => switch (s) {
                  SantierStatus.activ     => l.translate('statusActiv'),
                  SantierStatus.suspendat => l.translate('statusSuspendat'),
                  SantierStatus.arhivat   => l.translate('statusArhivat'),
                },
                onChanged: (v) => setState(() => _status = v),
              ),
              const SizedBox(height: 12),
              Text(l.perioadaCreare, style: ApprovalTheme.textBody(context)),
              const SizedBox(height: 6),
              _DateRangeTile(
                value: _perioadaCreare,
                onTap: _pickDateRange,
                onClear: () => setState(() => _perioadaCreare = null),
              ),
            ]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + mq.viewInsets.bottom),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, sf.SantiereFilter(
                status: _status, perioadaCreare: _perioadaCreare,
              )),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium)),
              ),
              child: Text(l.applyFilter),
            ),
          ),
        ),
      ]),
    );
  }
}

// Reusable Widgets
class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label, required this.value,
    required this.items, required this.itemLabel, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
            child: Text(AppLocalizations.of(context).all, style: ApprovalTheme.textBody(context))),
        ...items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(itemLabel(item), style: ApprovalTheme.textBody(context)))),
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

class _SheetTitleRow extends StatelessWidget {
  final String title;
  const _SheetTitleRow({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      Text(title, style: ApprovalTheme.textTitle(context)),
      const Spacer(),
      IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close)),
    ]),
  );
}

class _BottomSheetContainer extends StatelessWidget {
  final double maxHeightFactor;
  final Widget child;
  const _BottomSheetContainer({required this.maxHeightFactor, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(
          maxHeight: mq.size.height * maxHeightFactor - mq.viewInsets.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: child,
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  const _NameField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      style: ApprovalTheme.textBody(context),
      decoration: ApprovalTheme.inputDecoration(context, l.denumire).copyWith(
        prefixIcon: Icon(Icons.business_outlined,
            color: ApprovalTheme.textSecondary(context), size: 20),
      ),
      validator: (v) =>
      (v == null || v.trim().length < 3) ? l.minThreeChars : null,
    );
  }
}

class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  const _LocationField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      style: ApprovalTheme.textBody(context),
      decoration: ApprovalTheme.inputDecoration(context, l.locatie).copyWith(
        prefixIcon: Icon(Icons.location_on_outlined,
            color: ApprovalTheme.textSecondary(context), size: 20),
      ),
      validator: (v) =>
      (v == null || v.trim().isEmpty) ? l.requiredField : null,
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.value, required this.onTap});

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
              borderRadius: BorderRadius.circular(ApprovalTheme.radiusSmall),
              borderSide: BorderSide(color: ApprovalTheme.borderColor(context))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ApprovalTheme.radiusSmall),
              borderSide: BorderSide(color: ApprovalTheme.borderColor(context))),
          filled: true,
          fillColor: ApprovalTheme.surfaceBackground(context),
          prefixIcon: Icon(Icons.calendar_today_outlined,
              size: 18, color: ApprovalTheme.textSecondary(context)),
          suffixIcon: Icon(Icons.arrow_drop_down,
              color: ApprovalTheme.textSecondary(context)),
        ),
        child: Text(
          value != null ? _dateFmt.format(value!) : AppLocalizations.of(context).selectDate,
          style: ApprovalTheme.textSmall(context).copyWith(
            color: value != null ? null : ApprovalTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.loading, required this.label, required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      style: ApprovalTheme.primaryButtonStyle(context),
      child: loading
          ? const SizedBox(
          height: 20, width: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label),
    ),
  );
}

class _DateRangeTile extends StatelessWidget {
  final sf.DateTimeRange? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateRangeTile({required this.value, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
                  ? '${_dateFmt.format(value!.start)} – ${_dateFmt.format(value!.end)}'
                  : AppLocalizations.of(context).oriceData,
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

// Helpers
String _formatDateRange(DateTime? start, DateTime? end, AppLocalizations l) {
  if (start == null && end == null) return l.dateUnspecified;
  if (start == null) return '– ${_dateFmt.format(end!)}';
  if (end == null)   return '${_dateFmt.format(start)} –';
  return '${_dateFmt.format(start)} – ${_dateFmt.format(end)}';
}

Color _statusColor(BuildContext context, SantierStatus status) => switch (status) {
  SantierStatus.activ     => const Color(0xFF1A6B3C),
  SantierStatus.suspendat => ApprovalTheme.errorColor(context),
  SantierStatus.arhivat   => ApprovalTheme.textSecondary(context),
};

Color _rowColor(BuildContext context, SantierStatus status) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    SantierStatus.activ     => isDark ? const Color(0xFF1B3A24) : const Color(0xFFD4EDDA),
    SantierStatus.suspendat => isDark ? const Color(0xFF3D0000) : const Color(0xFFF8D7DA),
    SantierStatus.arhivat   => isDark ? ApprovalTheme.cardBackground(context) : Colors.white,
  };
}