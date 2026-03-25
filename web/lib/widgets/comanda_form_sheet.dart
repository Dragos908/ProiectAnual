import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/models/comanda_model.dart';
import '/services/comanda_service.dart' hide OccupancyCalendar;
import '/models/occupancy_period.dart';
import 'occupancy_calendar.dart';
import '/approval_theme.dart';
import '../models/user.dart';

final _dateFmt = DateFormat('dd.MM.yyyy HH:mm');

// =============================================================================
// ComandaFormSheet
// =============================================================================

class ComandaFormSheet extends StatefulWidget {
  final String   santierId;
  final String   santierNume;
  final DateTime santierDataIncepere;
  final User     currentUser;
  final Comanda? existingComanda;

  /// Culoarea santierului (hex) — denormalizata in OccupancyPeriod.
  final String? santierColor;

  const ComandaFormSheet({
    super.key,
    required this.santierId,
    required this.santierNume,
    required this.santierDataIncepere,
    required this.currentUser,
    this.existingComanda,
    this.santierColor,
  });

  @override
  State<ComandaFormSheet> createState() => _ComandaFormSheetState();
}

class _ComandaFormSheetState extends State<ComandaFormSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();

  Timer?                    _debounce;
  List<VehicleSearchResult> _results   = [];
  bool                      _searching = false;
  VehicleSearchResult?      _vehicle;

  DateTime? _start;
  DateTime? _final;

  Stream<List<OccupancyPeriod>>? _occStream;

  String? _error;
  bool    _saving = false;

  // ── Init / dispose ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final c = widget.existingComanda;
    if (c != null) {
      _start           = c.dataStart;
      _final           = c.dataFinal;
      _searchCtrl.text = c.vehicleModel;
      _noteCtrl.text   = c.note ?? '';

      _vehicle = VehicleSearchResult(
        id:               c.vehicleId,
        model:            c.vehicleModel,
        clasa:            c.vehicleClasa,
        subclasa:         '',
        occupancyPeriods: [],
      );
      _occStream = ComenzaService.vehicleOccupancyStream(c.vehicleId);
    }
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Cautare ────────────────────────────────────────────────────────────────

  void _onSearchChanged() {
    _debounce?.cancel();
    if (_searchCtrl.text.trim().length < 2) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    try {
      final r = await ComenzaService.searchVehicles(_searchCtrl.text.trim());
      if (mounted) setState(() => _results = r);
    } catch (_) {}
    finally { if (mounted) setState(() => _searching = false); }
  }

  void _selectVehicle(VehicleSearchResult v) {
    setState(() {
      _vehicle         = v;
      _searchCtrl.text = v.model;
      _results         = [];
      _error           = null;
      _occStream       = ComenzaService.vehicleOccupancyStream(v.id);
    });
  }

  // ── Picker data/ora nativ ──────────────────────────────────────────────────

  Future<DateTime?> _pickDT(BuildContext ctx, {
    DateTime? initial, DateTime? firstDate,
  }) async {
    final first = firstDate ?? DateTime(2020);
    final init  = (initial != null && initial.isAfter(first))
        ? initial : first;

    final date = await showDatePicker(
      context: ctx, initialDate: init,
      firstDate: first, lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: ctx,
      initialTime: initial != null
          ? TimeOfDay(hour: initial.hour, minute: initial.minute)
          : const TimeOfDay(hour: 8, minute: 0),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ── Salvare ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_vehicle == null) {
      _setErr('Selectați un mecanism din lista de sugestii.'); return;
    }
    if (_start == null || _final == null) {
      _setErr('Selectați data+ora de start și final.'); return;
    }
    if (!_final!.isAfter(_start!)) {
      _setErr('Data final trebuie să fie după data start.'); return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

      if (widget.existingComanda == null) {
        // ── Comandă nouă ──────────────────────────────────────────────────────
        await ComenzaService.createComanda(
          santierId:           widget.santierId,
          santierNume:         widget.santierNume,
          santierDataIncepere: widget.santierDataIncepere,
          vehicleId:           _vehicle!.id,
          vehicleModel:        _vehicle!.model,
          vehicleClasa:        '${_vehicle!.clasa}·${_vehicle!.subclasa}',
          dataStart:           _start!,
          dataFinal:           _final!,
          currentUser:         widget.currentUser,
          note:                note,
          santierColor:        widget.santierColor,
        );
      } else {
        // ── Editare comandă existentă ─────────────────────────────────────────
        final c         = widget.existingComanda!;
        final oldPeriod = OccupancyPeriod(
          from:         c.dataStart,
          to:           c.dataFinal,
          rentedBy:     c.creatDeNume,
          santierId:    c.santierId,
          comenzaId:    c.id,
          status:       c.status.value,
          santierColor: widget.santierColor,
        );
        await ComenzaService.updateComandaInterval(
          comanda:           c,
          oldPeriod:         oldPeriod,
          newDataStart:      _start!,
          newDataFinal:      _final!,
          modificatDeUserId: widget.currentUser.uid,
          modificatDeNume:   widget.currentUser.name,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      // Mesaj fix pentru utilizatorul simplu
      final successMsg = widget.existingComanda != null
          ? 'Comanda a fost actualizată.'
          : 'Comanda a fost trimisă spre aprobare.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(successMsg),
        backgroundColor: ApprovalTheme.successColor(context),
      ));

    } on RezervareOverlapException catch (e) {
      _setErr(
        'Interval suprapus cu rezervarea existentă:\n'
            '${_dateFmt.format(e.conflicting.dataStart)} – '
            '${_dateFmt.format(e.conflicting.dataFinal)}'
            '${e.conflicting.creatDeNume.isNotEmpty ? '\nRezervat de: ${e.conflicting.creatDeNume}' : ''}',
      );
    }  finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setErr(String msg) => setState(() => _error = msg);

  // ── Stergere ───────────────────────────────────────────────────────────────

  Future<void> _delete() async {
    final c = widget.existingComanda!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Șterge comanda?'),
        content: const Text('Comanda va fi ștearsă și intervalul eliberat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Anulează')),
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: ApprovalTheme.errorColor(context)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Șterge')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final period = OccupancyPeriod(
        from:         c.dataStart,
        to:           c.dataFinal,
        rentedBy:     c.creatDeNume,
        santierId:    c.santierId,
        comenzaId:    c.id,
        status:       c.status.value,
        santierColor: widget.santierColor,
      );
      await ComenzaService.deleteComanda(comanda: c, period: period);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _setErr('Eroare la ștergere: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit  = widget.existingComanda != null;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize:     0.5,
      maxChildSize:     0.97,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          _Handle(),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(isEdit ? 'Editare comandă' : 'Comandă nouă',
                  style: ApprovalTheme.textTitle(context)),
              const Spacer(),
              if (isEdit)
                OutlinedButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon:  const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Șterge'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ApprovalTheme.errorColor(context),
                    side: BorderSide(
                        color: ApprovalTheme.errorColor(context)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                  ),
                ),
            ]),
          ),
          const Divider(height: 16),
          Expanded(child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Cautare mecanism ──────────────────────────────────────
                  TextFormField(
                    controller: _searchCtrl,
                    style: ApprovalTheme.textBody(context),
                    decoration: ApprovalTheme.inputDecoration(
                      context,
                      'Mecanism (tastați minim 2 caractere)',
                    ).copyWith(
                      prefixIcon: Icon(Icons.search,
                          color: ApprovalTheme.textSecondary(context),
                          size: 20),
                      suffixIcon: _searching
                          ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ApprovalTheme
                                      .primaryAccent(context))))
                          : null,
                    ),
                    validator: (_) => _vehicle == null
                        ? 'Selectați un mecanism din listă.' : null,
                  ),

                  // ── Dropdown rezultate ────────────────────────────────────
                  if (_results.isNotEmpty)
                    _SearchDropdown(
                      results:   _results,
                      dataStart: _start,
                      dataFinal: _final,
                      onSelect:  _selectVehicle,
                    )
                  else if (_searchCtrl.text.trim().length >= 2 &&
                      !_searching && _vehicle == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 16,
                            color: ApprovalTheme.errorColor(context)),
                        const SizedBox(width: 6),
                        Text(
                          'Mecanismul nu a fost găsit în baza de date.',
                          style: TextStyle(
                              color: ApprovalTheme.errorColor(context),
                              fontSize: 13),
                        ),
                      ]),
                    ),

                  const SizedBox(height: 16),

                  // ── Calendar ocupare ──────────────────────────────────────
                  if (_vehicle != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ApprovalTheme.surfaceBackground(context),
                        borderRadius: BorderRadius.circular(
                            ApprovalTheme.radiusMedium),
                        border: Border.all(
                            color: ApprovalTheme.borderColor(context),
                            width: ApprovalTheme.borderWidth),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.calendar_month_outlined,
                                size: 16,
                                color: ApprovalTheme.primaryAccent(context)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(
                                'Calendar — ${_vehicle!.model}',
                                style: ApprovalTheme.textSmall(context)
                                    .copyWith(fontWeight: FontWeight.bold))),
                          ]),
                          const SizedBox(height: 8),
                          StreamBuilder<List<OccupancyPeriod>>(
                            stream: _occStream,
                            builder: (_, snap) {
                              OccupancyPeriod? editingPeriod;
                              final c = widget.existingComanda;
                              if (c != null) {
                                editingPeriod = OccupancyPeriod(
                                  from:         c.dataStart,
                                  to:           c.dataFinal,
                                  rentedBy:     c.creatDeNume,
                                  santierId:    c.santierId,
                                  comenzaId:    c.id,
                                  status:       c.status.value,
                                  santierColor: widget.santierColor,
                                );
                              }
                              return OccupancyCalendar(
                                periods:        snap.data ?? [],
                                mode:           CalendarMode.dateTime,
                                editingPeriod:  editingPeriod,
                                initialStart:   _start,
                                initialEnd:     _final,
                                onRangeChanged: (s, e) => setState(() {
                                  _start = s; _final = e; _error = null;
                                }),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Campuri data start / final ────────────────────────────
                  _DTField(
                    label: 'Data + Ora start', value: _start,
                    onTap: () async {
                      final dt = await _pickDT(context, initial: _start);
                      if (dt != null) setState(() { _start = dt; _error = null; });
                    },
                  ),
                  const SizedBox(height: 10),
                  _DTField(
                    label: 'Data + Ora final', value: _final,
                    onTap: () async {
                      final dt = await _pickDT(context,
                          initial: _final, firstDate: _start);
                      if (dt != null) setState(() { _final = dt; _error = null; });
                    },
                  ),
                  const SizedBox(height: 10),

                  // ── Note ──────────────────────────────────────────────────
                  TextFormField(
                    controller: _noteCtrl, maxLines: 2,
                    style: ApprovalTheme.textBody(context),
                    decoration: ApprovalTheme.inputDecoration(
                      context, 'Note (opțional)',
                    ).copyWith(prefixIcon: Icon(Icons.notes_outlined,
                        color: ApprovalTheme.textSecondary(context),
                        size: 20)),
                  ),
                  const SizedBox(height: 16),

                  // ── Eroare suprapunere ────────────────────────────────────
                  if (_error != null) _ErrorBox(message: _error!),

                  // ── Submit ────────────────────────────────────────────────
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: ApprovalTheme.primaryButtonStyle(context),
                      child: _saving
                          ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : Text(isEdit
                          ? 'Actualizează'
                          : 'Trimite spre aprobare'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            )],
          )),
        ]),
      ),
    );
  }
}

// =============================================================================
// Widgets ajutatoare
// =============================================================================

class _SearchDropdown extends StatelessWidget {
  final List<VehicleSearchResult>          results;
  final DateTime?                          dataStart;
  final DateTime?                          dataFinal;
  final void Function(VehicleSearchResult) onSelect;
  const _SearchDropdown({required this.results, required this.dataStart,
    required this.dataFinal, required this.onSelect});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    decoration: BoxDecoration(
      color:        ApprovalTheme.surfaceBackground(context),
      border:       Border.all(color: ApprovalTheme.borderColor(context)),
      borderRadius: BorderRadius.circular(ApprovalTheme.radiusSmall),
    ),
    child: Column(children: results.map((v) {
      final occ      = (dataStart != null && dataFinal != null)
          ? v.isOccupied(dataStart!, dataFinal!) : false;
      final conflict = (dataStart != null && dataFinal != null)
          ? v.occupiedPeriod(dataStart!, dataFinal!) : null;
      return Opacity(
        opacity: occ ? 0.45 : 1.0,
        child: ListTile(
          enabled: !occ,
          onTap:   occ ? null : () => onSelect(v),
          leading: Icon(
            occ ? Icons.block_outlined : Icons.check_circle_outline,
            color: occ
                ? ApprovalTheme.errorColor(context)
                : Colors.green.shade600,
            size: 20,
          ),
          title: Text('${v.model}  ${v.clasa}·${v.subclasa}',
              style: ApprovalTheme.textBody(context)),
          subtitle: occ && conflict != null
              ? Text(
              'Ocupat ${_dateFmt.format(conflict.from)} – '
                  '${_dateFmt.format(conflict.to)}',
              style: TextStyle(
                  color: ApprovalTheme.errorColor(context), fontSize: 11))
              : Text('Disponibil',
              style: TextStyle(
                  color: Colors.green.shade600, fontSize: 11)),
        ),
      );
    }).toList()),
  );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ApprovalTheme.errorColor(context).withOpacity(0.08),
      borderRadius: BorderRadius.circular(ApprovalTheme.radiusSmall),
      border: Border.all(
          color: ApprovalTheme.errorColor(context).withOpacity(0.3)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.warning_amber_rounded,
          color: ApprovalTheme.errorColor(context), size: 20),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: TextStyle(
          color: ApprovalTheme.errorColor(context), fontSize: 13))),
    ]),
  );
}

class _DTField extends StatelessWidget {
  final String label; final DateTime? value; final VoidCallback onTap;
  const _DTField({required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: ApprovalTheme.textBody(context)
            .copyWith(color: ApprovalTheme.textSecondary(context)),
        border: OutlineInputBorder(borderRadius:
        BorderRadius.circular(ApprovalTheme.radiusSmall),
            borderSide: BorderSide(
                color: ApprovalTheme.borderColor(context))),
        enabledBorder: OutlineInputBorder(borderRadius:
        BorderRadius.circular(ApprovalTheme.radiusSmall),
            borderSide: BorderSide(
                color: ApprovalTheme.borderColor(context))),
        filled:    true,
        fillColor: ApprovalTheme.surfaceBackground(context),
        prefixIcon: Icon(Icons.access_time_outlined,
            size: 18, color: ApprovalTheme.textSecondary(context)),
        suffixIcon: Icon(Icons.arrow_drop_down,
            color: ApprovalTheme.textSecondary(context)),
      ),
      child: Text(
        value != null ? _dateFmt.format(value!) : 'Selectați data și ora',
        style: value != null
            ? ApprovalTheme.textBody(context)
            : ApprovalTheme.textBody(context)
            .copyWith(color: ApprovalTheme.textSecondary(context)),
      ),
    ),
  );
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 8),
      Container(width: 40, height: 4,
          decoration: BoxDecoration(
            color: ApprovalTheme.borderColor(context),
            borderRadius: BorderRadius.circular(2),
          )),
      const SizedBox(height: 12),
    ],
  );
}