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

// =============================================================================
// CombinedPdfPage — tab switcher cu OutlinedButton identic cu home_page
// =============================================================================

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
    return _CombinedPdfPageBody(santiere: santiere, comenzi: comenzi);
  }
}

class _CombinedPdfPageBody extends StatefulWidget {
  final List<Santier> santiere;
  final List<Comanda> comenzi;

  const _CombinedPdfPageBody({
    required this.santiere,
    required this.comenzi,
  });

  @override
  State<_CombinedPdfPageBody> createState() => _CombinedPdfPageBodyState();
}

class _CombinedPdfPageBodyState extends State<_CombinedPdfPageBody> {
  int _currentTab = 0;

  static const _tabs = [
    _TabDef(icon: Icons.construction,   label: 'Șantiere'),
    _TabDef(icon: Icons.directions_car, label: 'Vehicule'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Tab switcher — OutlinedButton, identic cu home_page ──────────────
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final isSelected = _currentTab == i;
              final color = isSelected
                  ? Theme.of(context).colorScheme.primary
                  : ApprovalTheme.textSecondary(context);

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentTab = i),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: color, width: isSelected ? 2.0 : 1.4),
                      foregroundColor: color,
                      backgroundColor: isSelected
                          ? color.withOpacity(0.07)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            ApprovalTheme.radiusSmall),
                      ),
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tab.icon, size: 16, color: color),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 13,
                              color: color,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // ── Conținut tab ─────────────────────────────────────────────────────
        Expanded(
          child: IndexedStack(
            index: _currentTab,
            children: [
              SantierPdfTab(
                  santiere: widget.santiere, comenzi: widget.comenzi),
              const VehiclePdfTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabDef {
  final IconData icon;
  final String label;
  const _TabDef({required this.icon, required this.label});
}

// =============================================================================
// SantierPdfTab
// =============================================================================

class SantierPdfTab extends StatefulWidget {
  final List<Santier> santiere;
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
  SantierStatus? _selectedStatus;
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
      if (_selectedStatus != null && s.status != _selectedStatus) return false;
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

  Future<T> _withGenerating<T>(Future<T> Function() action) async {
    if (_isGenerating || !mounted) return Future.error('Already generating');
    setState(() => _isGenerating = true);
    try {
      return await action();
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _toggle(String id) {
    setState(() {
      _selectedIds.contains(id)
          ? _selectedIds.remove(id)
          : _selectedIds.add(id);
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

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

  // ── Deschide filtrul ────────────────────────────────────────────────────────
  void _openFilterSheet(AppLocalizations l) async {
    final result = await showModalBottomSheet<_PdfFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PdfFilterSheet(
        current: _PdfFilter(
          status: _selectedStatus,
          dateRange: _selectedDateRange,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedStatus    = result.status;
        _selectedDateRange = result.dateRange;
        _clearSelection();
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD UI
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final filtered = _filtered;

    final visibleIds    = filtered.map((s) => s.id).toSet();
    final allSelected   = visibleIds.isNotEmpty &&
        _selectedIds.containsAll(visibleIds);
    final selectedSantiere =
    filtered.where((s) => _selectedIds.contains(s.id)).toList();

    final filterActive =
        _selectedStatus != null || _selectedDateRange != null;
    final int filterCount =
        (_selectedStatus != null ? 1 : 0) +
            (_selectedDateRange != null ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.all(ApprovalTheme.paddingLarge),
      child: Column(
        children: [
          // ── Rând 1: search + buton filtru ────────────────────────────────
          Row(
            children: [
              Expanded(
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
              const SizedBox(width: 8),
              // Buton filtru — identic cu _FilterButton din santiere_list_page
              Stack(
                clipBehavior: Clip.none,
                children: [
                  OutlinedButton(
                    onPressed: () => _openFilterSheet(l),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: filterActive
                            ? Theme.of(context).colorScheme.primary
                            : ApprovalTheme.textSecondary(context),
                        width: 1.4,
                      ),
                      foregroundColor: filterActive
                          ? Theme.of(context).colorScheme.primary
                          : ApprovalTheme.textSecondary(context),
                      backgroundColor: filterActive
                          ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.07)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            ApprovalTheme.radiusSmall),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 16,
                          color: filterActive
                              ? Theme.of(context).colorScheme.primary
                              : ApprovalTheme.textSecondary(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          filterActive
                              ? 'Filtru ($filterCount)'
                              : 'Filtru',
                          style: TextStyle(
                            fontSize: 12,
                            color: filterActive
                                ? Theme.of(context).colorScheme.primary
                                : ApprovalTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (filterActive)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: ApprovalTheme.marginLarge),

          // ── Rând 2: selectează tot + buton PDF ───────────────────────────
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
    final accent     = ApprovalTheme.primaryAccent(context);
    final border     = ApprovalTheme.borderColor(context);
    final comenzi    = _comenziForSantier(s.id);

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

  // =============================================================================
  // GENERARE PDF
  // =============================================================================

  Future<pw.Document> _buildDocument(List<Santier> santiere) async {
    final font = await _getFont();
    final pdf  = pw.Document();

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
            border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.0),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.0),
              3: pw.FlexColumnWidth(1.0),
              4: pw.FlexColumnWidth(0.9),
              5: pw.FlexColumnWidth(1.4),
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

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}.'
          '${d.year}';

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

// =============================================================================
// _PdfFilter — model date filtru
// =============================================================================

class _PdfFilter {
  final SantierStatus? status;
  final DateTimeRange? dateRange;
  const _PdfFilter({this.status, this.dateRange});
}

// =============================================================================
// _PdfFilterSheet — bottom sheet cu status chips + perioadă, identic santiere
// =============================================================================

class _PdfFilterSheet extends StatefulWidget {
  final _PdfFilter current;
  const _PdfFilterSheet({required this.current});

  @override
  State<_PdfFilterSheet> createState() => _PdfFilterSheetState();
}

class _PdfFilterSheetState extends State<_PdfFilterSheet> {
  late SantierStatus? _status;
  DateTimeRange?      _dateRange;

  @override
  void initState() {
    super.initState();
    _status    = widget.current.status;
    _dateRange = widget.current.dateRange;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
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
        // Handle
        Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: ApprovalTheme.borderColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
        ]),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('Filtru PDF', style: ApprovalTheme.textTitle(context)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _status    = null;
                _dateRange = null;
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

                // ── Status dropdown — identic cu _FilterDropdown din santiere_list_page
                DropdownButtonFormField<SantierStatus?>(
                  value: _status,
                  decoration: InputDecoration(
                    labelText: 'Status',
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
                    DropdownMenuItem<SantierStatus?>(
                      value: null,
                      child: Text('Toate',
                          style: ApprovalTheme.textBody(context)),
                    ),
                    ...SantierStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.displayLabel,
                          style: ApprovalTheme.textBody(context)),
                    )),
                  ],
                  onChanged: (v) => setState(() => _status = v),
                ),

                const SizedBox(height: 16),

                // ── Perioadă creare
                Text('Perioadă creare', style: ApprovalTheme.textBody(context)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDateRange,
                  borderRadius:
                  BorderRadius.circular(ApprovalTheme.radiusSmall),
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
                          _dateRange != null
                              ? '${_fmtDate(_dateRange!.start)} – ${_fmtDate(_dateRange!.end)}'
                              : 'Orice dată',
                          style: ApprovalTheme.textBody(context).copyWith(
                            color: _dateRange != null
                                ? null
                                : ApprovalTheme.textSecondary(context),
                          ),
                        ),
                      ),
                      if (_dateRange != null)
                        GestureDetector(
                          onTap: () => setState(() => _dateRange = null),
                          child: Icon(Icons.close,
                              size: 16,
                              color: ApprovalTheme.textSecondary(context)),
                        ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + mq.viewInsets.bottom),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _PdfFilter(status: _status, dateRange: _dateRange),
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
// _StatusChip — OutlinedButton cu selected state, identic în toate paginile
// =============================================================================

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: color, width: selected ? 2.0 : 1.4),
      foregroundColor: color,
      backgroundColor:
      selected ? color.withOpacity(0.12) : Colors.transparent,
      padding:
      const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(ApprovalTheme.radiusSmall)),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    ),
  );
}