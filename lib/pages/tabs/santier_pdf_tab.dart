import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../../models/santier_model.dart';
import '../../models/comanda_model.dart';
import '../../app_localizations.dart';
import '../../approval_theme.dart';

import 'vehicle_pdf_tab.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SantierPdfTab
// ─────────────────────────────────────────────────────────────────────────────
//
// Preia lista de santiere + toate comenzile asociate și permite:
//   • filtrare după status santier, interval de creare, text liber
//   • selectare individuală sau în bloc
//   • previzualizare PDF per santier (iconița de preview din card)
//   • generare PDF combinat pentru selecție (buton principal)
//
// ─────────────────────────────────────────────────────────────────────────────

class SantierPdfTab extends StatefulWidget {
  final List<Santier> santiere;

  /// Toate comenzile din baza de date, nefiltrate — tab-ul le va corela
  /// intern cu fiecare santier după `comanda.santierId == santier.id`.
  final List<Comanda> comenzi;

  const SantierPdfTab({
    super.key,
    required this.santiere,
    required this.comenzi,
  });

  @override
  State<SantierPdfTab> createState() => _SantierPdfTabState();
}

class _SantierPdfTabState extends State<SantierPdfTab> {
  // ── Stare filtre ────────────────────────────────────────────────────────────
  String _searchQuery = '';
  SantierStatus? _selectedStatus; // null = toate
  DateTimeRange? _selectedDateRange;

  // ── Stare selecție ──────────────────────────────────────────────────────────
  final Set<String> _selectedIds = {};

  // ── Stare generare ──────────────────────────────────────────────────────────
  bool _isGenerating = false;

  // ── Cache font ──────────────────────────────────────────────────────────────
  pw.Font? _cachedFont;

  // ── Computed: lista filtrata ────────────────────────────────────────────────
  List<Santier> get _filtered {
    return widget.santiere.where((s) {
      // Status
      if (_selectedStatus != null && s.status != _selectedStatus) return false;

      // Interval creare
      if (_selectedDateRange != null) {
        if (s.createdAt.isBefore(_selectedDateRange!.start)) return false;
        final endOfDay = DateTime(
          _selectedDateRange!.end.year,
          _selectedDateRange!.end.month,
          _selectedDateRange!.end.day,
          23, 59, 59,
        );
        if (s.createdAt.isAfter(endOfDay)) return false;
      }

      // Text liber (denumire sau locatie sau creatDeNume)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!s.denumire.toLowerCase().contains(q) &&
            !s.locatie.toLowerCase().contains(q) &&
            !s.creatDeNume.toLowerCase().contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<Comanda> _comenziForSantier(String santierId) =>
      widget.comenzi
          .where((c) => c.santierId == santierId)
          .toList()
        ..sort((a, b) => a.dataStart.compareTo(b.dataStart));

  // ── Font ────────────────────────────────────────────────────────────────────
  Future<pw.Font> _getFont() async {
    if (_cachedFont != null) return _cachedFont!;
    final data = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    _cachedFont = pw.Font.ttf(data);
    return _cachedFont!;
  }

  // ── Guard generating ────────────────────────────────────────────────────────
  Future<T> _withGenerating<T>(Future<T> Function() action) async {
    if (_isGenerating || !mounted) return Future.error('Already generating');
    setState(() => _isGenerating = true);
    try {
      return await action();
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── Snack bar ───────────────────────────────────────────────────────────────
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // ── Selecție ────────────────────────────────────────────────────────────────
  void _toggle(String id) {
    setState(() {
      _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  // ── Preview PDF (un singur santier) ────────────────────────────────────────
  Future<void> _previewPdf(Santier s, AppLocalizations l) async {
    try {
      await _withGenerating(() async {
        final pdf = await _buildDocument([s]);
        await Printing.layoutPdf(onLayout: (_) => pdf.save());
      });
    } catch (e) {
      _showSnackBar(
        l.translate('previewError').replaceAll('{error}', e.toString()),
        ApprovalTheme.errorColor(context),
      );
    }
  }

  // ── Generare PDF pentru selecție ────────────────────────────────────────────
  Future<void> _generateSelected(
      List<Santier> selected, AppLocalizations l) async {
    try {
      await _withGenerating(() async {
        final pdf = await _buildDocument(selected);
        await Printing.layoutPdf(onLayout: (_) => pdf.save());
      });
      _showSnackBar(
        l
            .translate('generatedDocumentsInSinglePdf')
            .replaceAll('{count}', selected.length.toString()),
        ApprovalTheme.successColor(context),
      );
    } catch (e) {
      _showSnackBar(
        l.translate('pdfGenerationError').replaceAll('{error}', e.toString()),
        ApprovalTheme.errorColor(context),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD UI
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final filtered = _filtered;

    final visibleIds = filtered.map((s) => s.id).toSet();
    final allSelected =
        visibleIds.isNotEmpty && _selectedIds.containsAll(visibleIds);

    final selectedSantiere =
    filtered.where((s) => _selectedIds.contains(s.id)).toList();

    return Padding(
      padding: const EdgeInsets.all(ApprovalTheme.paddingLarge),
      child: Column(
        children: [
          _buildFiltersCard(l),
          const SizedBox(height: ApprovalTheme.marginLarge),
          _buildActionsCard(
            l: l,
            filtered: filtered,
            visibleIds: visibleIds,
            allSelected: allSelected,
            selectedSantiere: selectedSantiere,
          ),
          const SizedBox(height: ApprovalTheme.marginLarge),
          Expanded(child: _buildList(l, filtered)),
        ],
      ),
    );
  }

  // ── Filtre ──────────────────────────────────────────────────────────────────
  Widget _buildFiltersCard(AppLocalizations l) {
    return Card(
      color: ApprovalTheme.cardBackground(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
        side: BorderSide(
          color: ApprovalTheme.borderColor(context),
          width: ApprovalTheme.borderWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ApprovalTheme.paddingMedium),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: l.translate('search'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(ApprovalTheme.radiusSmall),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: ApprovalTheme.paddingSmall,
                        vertical: ApprovalTheme.paddingSmall,
                      ),
                    ),
                    onChanged: (v) {
                      setState(() => _searchQuery = v);
                      _clearSelection();
                    },
                  ),
                ),
                const SizedBox(width: ApprovalTheme.marginSmall),
                Expanded(
                  child: DropdownButtonFormField<SantierStatus?>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: l.translate('status'),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(ApprovalTheme.radiusSmall),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: ApprovalTheme.paddingSmall,
                        vertical: ApprovalTheme.paddingSmall,
                      ),
                    ),
                    items: [
                      DropdownMenuItem<SantierStatus?>(
                        value: null,
                        child: Text(l.translate('all')),
                      ),
                      ...SantierStatus.values.map(
                            (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.displayLabel),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedStatus = v);
                      _clearSelection();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: ApprovalTheme.marginSmall),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _selectedDateRange == null
                          ? l.translate('selectDateRange')
                          : '${_formatDate(_selectedDateRange!.start)} – ${_formatDate(_selectedDateRange!.end)}',
                      style: ApprovalTheme.textBody(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ApprovalTheme.paddingSmall,
                        vertical: ApprovalTheme.paddingSmall,
                      ),
                      side: BorderSide(
                          color: ApprovalTheme.borderColor(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(ApprovalTheme.radiusSmall),
                      ),
                    ),
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDateRange: _selectedDateRange,
                      );
                      if (range != null) {
                        setState(() => _selectedDateRange = range);
                        _clearSelection();
                      }
                    },
                  ),
                ),
                if (_selectedDateRange != null) ...[
                  const SizedBox(width: ApprovalTheme.marginSmall),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: l.translate('clearFilter'),
                    onPressed: () {
                      setState(() => _selectedDateRange = null);
                      _clearSelection();
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Card acțiuni ────────────────────────────────────────────────────────────
  Widget _buildActionsCard({
    required AppLocalizations l,
    required List<Santier> filtered,
    required Set<String> visibleIds,
    required bool allSelected,
    required List<Santier> selectedSantiere,
  }) {
    return Card(
      color: ApprovalTheme.cardBackground(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
        side: BorderSide(
          color: ApprovalTheme.borderColor(context),
          width: ApprovalTheme.borderWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ApprovalTheme.paddingMedium),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: filtered.isEmpty
                  ? null
                  : () {
                setState(() {
                  allSelected
                      ? _selectedIds.removeAll(visibleIds)
                      : _selectedIds.addAll(visibleIds);
                });
              },
              icon: Icon(
                allSelected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 20,
              ),
              label: Text(
                allSelected
                    ? l.translate('deselectAll')
                    : l
                    .translate('selectAll')
                    .replaceAll('{count}', filtered.length.toString()),
                style: ApprovalTheme.textBody(context),
              ),
            ),
            const Spacer(),
            if (_isGenerating)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              FilledButton.icon(
                onPressed: selectedSantiere.isEmpty
                    ? null
                    : () => _generateSelected(selectedSantiere, l),
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                label: Text(
                  selectedSantiere.isEmpty
                      ? l.translate('generatePdf')
                      : '${l.translate('pdf')} (${selectedSantiere.length})',
                  style: ApprovalTheme.buttonTextStyle,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: ApprovalTheme.primaryAccent(context),
                  padding: const EdgeInsets.symmetric(
                    horizontal: ApprovalTheme.paddingMedium,
                    vertical: ApprovalTheme.paddingMedium,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Lista santiere ──────────────────────────────────────────────────────────
  Widget _buildList(AppLocalizations l, List<Santier> filtered) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: ApprovalTheme.textSecondary(context).withOpacity(0.5),
            ),
            const SizedBox(height: ApprovalTheme.paddingLarge),
            Text(
              l.translate('noMatchingOrders'),
              style: ApprovalTheme.textTitle(context).copyWith(
                color: ApprovalTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) => _buildSantierCard(filtered[i], i, l),
    );
  }

  // ── Card santier ────────────────────────────────────────────────────────────
  Widget _buildSantierCard(Santier s, int index, AppLocalizations l) {
    final isSelected = _selectedIds.contains(s.id);
    final accent = ApprovalTheme.primaryAccent(context);
    final border = ApprovalTheme.borderColor(context);
    final comenzi = _comenziForSantier(s.id);

    return Card(
      key: ValueKey(s.id),
      margin: ApprovalTheme.cardMargin,
      color: ApprovalTheme.cardBackground(context),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSelected ? accent : border,
          width: isSelected ? 2 : ApprovalTheme.borderWidth,
        ),
        borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ApprovalTheme.paddingSmall,
          vertical: ApprovalTheme.paddingTiny,
        ),
        dense: true,
        onTap: () => _toggle(s.id),
        leading: Checkbox(
          value: isSelected,
          onChanged: (_) => _toggle(s.id),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: s.flutterColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                s.denumire,
                style: ApprovalTheme.textTitle(context).copyWith(
                  fontWeight: isSelected
                      ? ApprovalTheme.fontWeightBold
                      : ApprovalTheme.fontWeightNormal,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: ApprovalTheme.paddingTiny),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l.translate('location')}: ${s.locatie}',
                style: ApprovalTheme.textBody(context),
              ),
              Text(
                '${l.translate('createdBy')}: ${s.creatDeNume}',
                style: ApprovalTheme.textBody(context),
              ),
              if (s.dataIncepere != null)
                Text(
                  '${l.translate('startDate')}: ${_formatDate(s.dataIncepere!)}',
                  style: ApprovalTheme.textBody(context),
                ),
              Text(
                '${l.translate('orders')}: ${comenzi.length}',
                style: ApprovalTheme.textBody(context),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ApprovalTheme.paddingSmall,
                vertical: ApprovalTheme.paddingTiny + 2,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: ApprovalTheme.borderColor(context),
                  width: ApprovalTheme.borderWidth,
                ),
                borderRadius:
                BorderRadius.circular(ApprovalTheme.radiusSmall),
              ),
              child: Text(
                s.status.displayLabel,
                style: ApprovalTheme.textBody(context).copyWith(
                  fontWeight: ApprovalTheme.fontWeightBold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.preview, size: 20),
              tooltip: l.translate('previewPdf'),
              color: ApprovalTheme.primaryAccent(context),
              onPressed: () => _previewPdf(s, l),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GENERARE PDF
  // ─────────────────────────────────────────────────────────────────────────

  Future<pw.Document> _buildDocument(List<Santier> santiere) async {
    final font = await _getFont();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => _buildPageHeader(font),
        build: (ctx) {
          final widgets = <pw.Widget>[];
          for (int i = 0; i < santiere.length; i++) {
            widgets.addAll(_buildSantierWidgets(santiere[i], font));
            if (i < santiere.length - 1) {
              widgets.addAll([
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 1.5, color: PdfColors.grey400),
                pw.SizedBox(height: 10),
              ]);
            }
          }
          return widgets;
        },
      ),
    );

    return pdf;
  }

  // ── Header pagina ───────────────────────────────────────────────────────────
  pw.Widget _buildPageHeader(pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'RAPORT ȘANTIERE',
              style: pw.TextStyle(
                font: font,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

          ],
        ),
        pw.SizedBox(height: 2),
        pw.Container(height: 1, color: PdfColors.grey400),
        pw.SizedBox(height: 6),
      ],
    );
  }

  // ── Conținut per santier ────────────────────────────────────────────────────
  List<pw.Widget> _buildSantierWidgets(Santier s, pw.Font font) {
    final comenzi = _comenziForSantier(s.id);
    return [
      _buildSantierHeader(s, font),
      pw.SizedBox(height: 6),
      _buildInfoSection(s, font, comenzi.length),
      pw.SizedBox(height: 8),
      _buildComenziTable(comenzi, font),
    ];
  }

  // ── Header santier ──────────────────────────────────────────────────────────
  pw.Widget _buildSantierHeader(Santier s, pw.Font font) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 12,
          height: 12,
          decoration: pw.BoxDecoration(
            color: _hexToPdfColor(s.color),
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Text(
            s.denumire.toUpperCase(),
            style: pw.TextStyle(
              font: font,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Text(
          s.status.displayLabel.toUpperCase(),
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  // ── Secțiune info ───────────────────────────────────────────────────────────
  pw.Widget _buildInfoSection(Santier s, pw.Font font, int nrComenzi) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoRow('Locație:', s.locatie, font),
              _infoRow('Creat de:', s.creatDeNume, font),
              _infoRow('Creat la:', _formatDate(s.createdAt), font),
            ],
          ),
        ),
        pw.Expanded(
          flex: 1,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _infoRow(
                'Data începere:',
                s.dataIncepere != null ? _formatDate(s.dataIncepere!) : '-',
                font,
              ),
              _infoRow(
                'Data finalizare:',
                s.dataFinalizare != null
                    ? _formatDate(s.dataFinalizare!)
                    : '-',
                font,
              ),
              _infoRow('Nr. comenzi:', '$nrComenzi', font),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _infoRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                color: PdfColors.grey600,
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: 9),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tabel comenzi ───────────────────────────────────────────────────────────
  pw.Widget _buildComenziTable(List<Comanda> comenzi, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'COMENZI VEHICULE:',
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        if (comenzi.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              'Nu există comenzi pentru acest șantier.',
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                color: PdfColors.grey500,
              ),
            ),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(
                width: 0.3, color: PdfColors.grey400),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.0), // Model vehicul
              1: pw.FlexColumnWidth(1.2), // Clasă
              2: pw.FlexColumnWidth(1.0), // Data start
              3: pw.FlexColumnWidth(1.0), // Data final
              4: pw.FlexColumnWidth(0.9), // Status
              5: pw.FlexColumnWidth(1.4), // Creat de
            },
            children: [
              pw.TableRow(
                decoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _th('Model vehicul', font),
                  _th('Clasă', font),
                  _th('Data start', font),
                  _th('Data final', font),
                  _th('Status', font),
                  _th('Creat de', font),
                ],
              ),
              ...comenzi.map(
                    (c) => pw.TableRow(
                  children: [
                    _td(c.vehicleModel, font),
                    _td(c.vehicleClasa, font),
                    _td(_formatDate(c.dataStart), font,
                        align: pw.TextAlign.center),
                    _td(_formatDate(c.dataFinal), font,
                        align: pw.TextAlign.center),
                    _tdStatus(c.status, font),
                    _td(c.creatDeNume, font),
                  ],
                ),
              ),
            ],
          ),
        // Note comenzi (dacă există)
        ...comenzi
            .where((c) => c.note != null && c.note!.isNotEmpty)
            .map(
              (c) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Notă (${c.vehicleModel}): ',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    c.note!,
                    style: pw.TextStyle(font: font, fontSize: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Celule tabel ────────────────────────────────────────────────────────────
  pw.Widget _th(String text, pw.Font font,
      [pw.TextAlign align = pw.TextAlign.left]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _td(String text, pw.Font font,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 8),
        textAlign: align,
        maxLines: 2,
      ),
    );
  }

  pw.Widget _tdStatus(ComandaStatus status, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        status.displayLabel,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}.'
          '${d.year}';




  /// Convertește string hex ("#2196F3") → PdfColor.
  PdfColor _hexToPdfColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      final value = int.parse(clean, radix: 16);
      final r = ((value >> 16) & 0xFF) / 255.0;
      final g = ((value >> 8) & 0xFF) / 255.0;
      final b = (value & 0xFF) / 255.0;
      return PdfColor(r, g, b);
    } catch (_) {
      return PdfColors.blue700;
    }
  }
}



class CombinedPdfPage extends StatelessWidget {
  final List<Santier> santiere;
  final List<Comanda> comenzi;

  const CombinedPdfPage({
    super.key,
    required this.santiere,
    required this.comenzi,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.construction, size: 18), text: 'Șantiere'),
              Tab(icon: Icon(Icons.directions_car, size: 18), text: 'Vehicule'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SantierPdfTab(santiere: santiere, comenzi: comenzi),
                const VehiclePdfTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}