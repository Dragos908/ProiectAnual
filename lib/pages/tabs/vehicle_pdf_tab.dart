import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../../models/vehicle.dart';
import '../../app_localizations.dart';
import '../../approval_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VehiclePdfTab
//
// Afișează lista completă de vehicule/mecanizme din Firestore.
// Permite:
//   • filtrare după clasă, subclasă, status, search text
//   • selectare individuală sau în bloc
//   • previzualizare PDF per vehicul (iconița preview)
//   • generare PDF combinat pentru selecție (buton principal)
//
// PDF-ul conține pentru fiecare vehicul:
//   - header cu model + nr. înmatriculare
//   - tabel cu date tehnice (clasă, subclasă, tonaj, bază, an, șasiu)
//   - status curent
//   - tabel perioade de ocupare (dacă există)
//   - observații (dacă există)
// ─────────────────────────────────────────────────────────────────────────────

class VehiclePdfTab extends StatefulWidget {
  const VehiclePdfTab({super.key});

  @override
  State<VehiclePdfTab> createState() => _VehiclePdfTabState();
}

class _VehiclePdfTabState extends State<VehiclePdfTab> {
  // ── Firestore ────────────────────────────────────────────────────────────────
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── Stare filtre ─────────────────────────────────────────────────────────────
  String _searchQuery = '';
  VehicleStatus? _selectedStatus; // null = toate
  String _selectedClasa = 'Toate';
  String _selectedSubclasa = 'Toate';

  // ── Stare selecție ───────────────────────────────────────────────────────────
  final Set<String> _selectedIds = {};

  // ── Stare generare ───────────────────────────────────────────────────────────
  bool _isGenerating = false;

  // ── Cache font ───────────────────────────────────────────────────────────────
  pw.Font? _cachedFont;

  // ── Stream vehicule ──────────────────────────────────────────────────────────
  late final Stream<List<Vehicle>> _stream = _db
      .collection('vehicles')
      .snapshots()
      .map((s) => s.docs.map(Vehicle.fromFirestore).toList()
    ..sort((a, b) {
      final c = a.clasa.compareTo(b.clasa);
      if (c != 0) return c;
      return a.model.compareTo(b.model);
    }));

  // ── Filtrare locală ──────────────────────────────────────────────────────────
  List<Vehicle> _filter(List<Vehicle> all) {
    return all.where((v) {
      if (_selectedStatus != null && v.status != _selectedStatus) return false;
      if (_selectedClasa != 'Toate' && v.clasa != _selectedClasa) return false;
      if (_selectedSubclasa != 'Toate' && v.subclasa != _selectedSubclasa) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!v.model.toLowerCase().contains(q) &&
            !v.idMeca.toLowerCase().contains(q) &&
            !v.clasa.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<String> _uniqueClase(List<Vehicle> all) {
    final sorted = all.map((v) => v.clasa).where((c) => c.isNotEmpty).toSet().toList()..sort();
    return ['Toate', ...sorted];
  }

  List<String> _uniqueSubclase(List<Vehicle> all) {
    final sorted = all.map((v) => v.subclasa).where((s) => s.isNotEmpty).toSet().toList()..sort();
    return ['Toate', ...sorted];
  }

  // ── Font ─────────────────────────────────────────────────────────────────────
  Future<pw.Font> _getFont() async {
    if (_cachedFont != null) return _cachedFont!;
    final data = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    _cachedFont = pw.Font.ttf(data);
    return _cachedFont!;
  }

  // ── Guard generating ─────────────────────────────────────────────────────────
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _toggle(String id) => setState(() {
    _selectedIds.contains(id)
        ? _selectedIds.remove(id)
        : _selectedIds.add(id);
  });

  void _clearSelection() => setState(() => _selectedIds.clear());

  // ── Preview PDF ──────────────────────────────────────────────────────────────
  Future<void> _previewPdf(Vehicle v) async {
    try {
      await _withGenerating(() async {
        final pdf = await _buildDocument([v]);
        await Printing.layoutPdf(onLayout: (_) => pdf.save());
      });
    } catch (e) {
      _showSnackBar('Eroare preview: $e', ApprovalTheme.errorColor(context));
    }
  }

  // ── Generare selecție ────────────────────────────────────────────────────────
  Future<void> _generateSelected(List<Vehicle> selected) async {
    try {
      await _withGenerating(() async {
        final pdf = await _buildDocument(selected);
        await Printing.layoutPdf(onLayout: (_) => pdf.save());
      });
      _showSnackBar(
        'PDF generat pentru ${selected.length} vehicul(e).',
        ApprovalTheme.successColor(context),
      );
    } catch (e) {
      _showSnackBar(
        'Eroare generare PDF: $e',
        ApprovalTheme.errorColor(context),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD UI
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Vehicle>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Eroare: ${snap.error}'));
        }

        final all = snap.data ?? [];
        final filtered = _filter(all);
        final visibleIds = filtered.map((v) => v.idMeca).toSet();
        final allSelected =
            visibleIds.isNotEmpty && _selectedIds.containsAll(visibleIds);
        final selectedVehicles =
        filtered.where((v) => _selectedIds.contains(v.idMeca)).toList();

        return Padding(
          padding: const EdgeInsets.all(ApprovalTheme.paddingLarge),
          child: Column(
            children: [
              _buildSearchRow(all),
              const SizedBox(height: ApprovalTheme.marginLarge),
              _buildActionsCard(
                filtered: filtered,
                visibleIds: visibleIds,
                allSelected: allSelected,
                selected: selectedVehicles,
              ),
              const SizedBox(height: ApprovalTheme.marginLarge),
              Expanded(child: _buildList(filtered, selectedVehicles)),
            ],
          ),
        );
      },
    );
  }

  // ── Rând search + buton filtru ───────────────────────────────────────────────
  Widget _buildSearchRow(List<Vehicle> all) {
    final filterActive = _selectedStatus != null ||
        _selectedClasa != 'Toate' ||
        _selectedSubclasa != 'Toate';
    final filterCount =
        (_selectedStatus != null ? 1 : 0) +
            (_selectedClasa != 'Toate' ? 1 : 0) +
            (_selectedSubclasa != 'Toate' ? 1 : 0);

    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Caută model / nr. înmatriculare...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ApprovalTheme.radiusSmall),
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
        Stack(
          clipBehavior: Clip.none,
          children: [
            OutlinedButton(
              onPressed: () => _openFilterSheet(all),
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
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.07)
                    : Colors.transparent,
                padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(ApprovalTheme.radiusSmall),
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
                    filterActive ? 'Filtru ($filterCount)' : 'Filtru',
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
    );
  }

  // ── Deschide filtrul ──────────────────────────────────────────────────────────
  Future<void> _openFilterSheet(List<Vehicle> all) async {
    final clase = _uniqueClase(all);
    final subclase = _uniqueSubclase(all);
    if (!clase.contains(_selectedClasa)) _selectedClasa = 'Toate';
    if (!subclase.contains(_selectedSubclasa)) _selectedSubclasa = 'Toate';

    final result = await showModalBottomSheet<_VehicleFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VehicleFilterSheet(
        current: _VehicleFilter(
          status: _selectedStatus,
          clasa: _selectedClasa,
          subclasa: _selectedSubclasa,
        ),
        allClase: clase,
        allSubclase: subclase,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedStatus   = result.status;
        _selectedClasa    = result.clasa;
        _selectedSubclasa = result.subclasa;
        _clearSelection();
      });
    }
  }


  // ── Card acțiuni ─────────────────────────────────────────────────────────────
  Widget _buildActionsCard({
    required List<Vehicle> filtered,
    required Set<String> visibleIds,
    required bool allSelected,
    required List<Vehicle> selected,
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
                    ? AppLocalizations.of(context).translate('deselectAll')
                    : AppLocalizations.of(context)
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
                onPressed:
                selected.isEmpty ? null : () => _generateSelected(selected),
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                label: Text(
                  selected.isEmpty
                      ? AppLocalizations.of(context).translate('generatePdf')
                      : '${AppLocalizations.of(context).translate('pdf')} (${selected.length})',
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

  // ── Lista vehicule ───────────────────────────────────────────────────────────
  Widget _buildList(List<Vehicle> filtered, List<Vehicle> selected) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.agriculture,
                size: 64,
                color: ApprovalTheme.textSecondary(context).withOpacity(0.5)),
            const SizedBox(height: ApprovalTheme.paddingLarge),
            Text(
              'Niciun vehicul găsit.',
              style: ApprovalTheme.textTitle(context)
                  .copyWith(color: ApprovalTheme.textSecondary(context)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) => _buildVehicleCard(filtered[i]),
    );
  }

  // ── Card vehicul ─────────────────────────────────────────────────────────────
  Widget _buildVehicleCard(Vehicle v) {
    final isSelected = _selectedIds.contains(v.idMeca);
    final accent = ApprovalTheme.primaryAccent(context);
    final border = ApprovalTheme.borderColor(context);
    final l = AppLocalizations.of(context);

    final statusText = l.translate(v.status.translationKey);
    final activePeriods =
        v.occupancyPeriods.where((p) => !p.isPending).length;

    return Card(
      key: ValueKey(v.idMeca),
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
        onTap: () => _toggle(v.idMeca),
        leading: Checkbox(
          value: isSelected,
          onChanged: (_) => _toggle(v.idMeca),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        title: Text(
          v.model.isNotEmpty ? v.model : v.idMeca,
          style: ApprovalTheme.textTitle(context).copyWith(
            fontWeight: isSelected
                ? ApprovalTheme.fontWeightBold
                : ApprovalTheme.fontWeightNormal,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: ApprovalTheme.paddingTiny),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (v.idMeca.isNotEmpty)
                Text(
                  'Nr. înmatriculare: ${v.idMeca}',
                  style: ApprovalTheme.textBody(context),
                ),
              if (v.clasa.isNotEmpty)
                Text(
                  '${l.translate('class')}: ${v.clasa}'
                      '${v.subclasa.isNotEmpty ? ' · ${v.subclasa}' : ''}',
                  style: ApprovalTheme.textBody(context),
                ),
              if (v.tonajMarime.isNotEmpty)
                Text(
                  '${l.translate('tonnage')}: ${v.tonajMarime}',
                  style: ApprovalTheme.textBody(context),
                ),
              if (activePeriods > 0)
                Text(
                  'Perioade active: $activePeriods',
                  style: ApprovalTheme.textBody(context),
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge status — alb/negru, fără culoare
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
                statusText,
                style: ApprovalTheme.textBody(context).copyWith(
                  fontWeight: ApprovalTheme.fontWeightBold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.preview, size: 20),
              tooltip: l.translate('previewPdf'),
              color: ApprovalTheme.primaryAccent(context),
              onPressed: () => _previewPdf(v),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // GENERARE PDF
  // ─────────────────────────────────────────────────────────────────────────────

  Future<Map<String, List<_RezervareInfo>>> _loadRezervari(
      List<Vehicle> vehicles) async {
    final result = <String, List<_RezervareInfo>>{};
    for (final v in vehicles) {
      final snap = await _db
          .collection('rezervari')
          .where('vehicleId', isEqualTo: v.idMeca)
          .get();
      result[v.idMeca] = snap.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        DateTime ts(dynamic val) =>
            val is Timestamp ? val.toDate() : DateTime(1970);
        return _RezervareInfo(
          santierNume: (d['santierNume'] ?? d['santierId'] ?? '-').toString(),
          dataStart: ts(d['dataStart']),
          dataFinal: ts(d['dataFinal']),
          status: (d['status'] ?? 'pending').toString(),
          creatDeNume: (d['creatDeNume'] ?? '-').toString(),
        );
      }).toList()
        ..sort((a, b) => a.dataStart.compareTo(b.dataStart));
    }
    return result;
  }

  Future<pw.Document> _buildDocument(List<Vehicle> vehicles) async {
    final font = await _getFont();
    final rezervari = await _loadRezervari(vehicles);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (_) => _pdfPageHeader(font),
        build: (_) {
          final widgets = <pw.Widget>[];
          for (int i = 0; i < vehicles.length; i++) {
            widgets.addAll(_buildVehicleWidgets(
                vehicles[i], font, rezervari[vehicles[i].idMeca] ?? []));
            if (i < vehicles.length - 1) {
              widgets.addAll([
                pw.SizedBox(height: 18),
                pw.Divider(thickness: 1.2, color: PdfColors.grey400),
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

  pw.Widget _pdfPageHeader(pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'RAPORT MECANIZME / VEHICULE',
              style: pw.TextStyle(
                font: font,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Generat: ${_fmtDate(DateTime.now())}',
              style: pw.TextStyle(
                  font: font, fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Container(height: 1, color: PdfColors.grey400),
        pw.SizedBox(height: 6),
      ],
    );
  }

  // ── Conținut per vehicul ─────────────────────────────────────────────────────
  List<pw.Widget> _buildVehicleWidgets(
      Vehicle v, pw.Font font, List<_RezervareInfo> rezervari) {
    return [
      _pdfVehicleHeader(v, font),
      pw.SizedBox(height: 6),
      _pdfTehnicSection(v, font),
      pw.SizedBox(height: 8),
      _pdfSantierTable(rezervari, font),
      if (v.observatii != null && v.observatii!.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        _pdfObservatii(v.observatii!, font),
      ],
    ];
  }

  // ── Header vehicul ───────────────────────────────────────────────────────────
  pw.Widget _pdfVehicleHeader(Vehicle v, pw.Font font) {
    final modelLabel =
    v.model.isNotEmpty ? v.model.toUpperCase() : v.idMeca.toUpperCase();
    final nrLabel = v.idMeca.isNotEmpty ? '  ·  ${v.idMeca}' : '';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Text(
            '$modelLabel$nrLabel',
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Text(
          _translateVehicleStatus(v.status).toUpperCase(),
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

  // ── Secțiune date tehnice ────────────────────────────────────────────────────
  pw.Widget _pdfTehnicSection(Vehicle v, pw.Font font) {
    final col1 = <Map<String, String>>[
      if (v.clasa.isNotEmpty) {'l': 'Clasă:', 'v': v.clasa},
      if (v.subclasa.isNotEmpty) {'l': 'Subclasă:', 'v': v.subclasa},
      if (v.tonajMarime.isNotEmpty) {'l': 'Tonaj:', 'v': v.tonajMarime},
      if (v.locatieBaza.isNotEmpty) {'l': 'Bază:', 'v': v.locatieBaza},
    ];
    final col2 = <Map<String, String>>[
      if (v.anFabricatie != null)
        {'l': 'An fabricație:', 'v': '${v.anFabricatie}'},
      if (v.serieSasiu != null && v.serieSasiu!.isNotEmpty)
        {'l': 'Serie șasiu:', 'v': v.serieSasiu!},
      {
        'l': 'Perioade ocupare:',
        'v': '${v.occupancyPeriods.length}',
      },
    ];

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children:
            col1.map((e) => _pdfInfoRow(e['l']!, e['v']!, font)).toList(),
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children:
            col2.map((e) => _pdfInfoRow(e['l']!, e['v']!, font)).toList(),
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfInfoRow(String label, String value, pw.Font font) {
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
                  font: font, fontSize: 9, color: PdfColors.grey600),
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

  // ── Tabel șantiere (din rezervari) ─────────────────────────────────
  pw.Widget _pdfSantierTable(List<_RezervareInfo> rezervari, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SANTIERE / PERIOADE:',
          style: pw.TextStyle(
              font: font, fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        if (rezervari.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              'Nu există șantiere înregistrate pentru acest vehicul.',
              style: pw.TextStyle(
                  font: font, fontSize: 9, color: PdfColors.grey500),
            ),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.5),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.0),
              4: pw.FlexColumnWidth(1.3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _th('Șantier', font),
                  _th('De la', font),
                  _th('Până la', font),
                  _th('Status', font),
                  _th('Creat de', font),
                ],
              ),
              ...rezervari.map((r) => pw.TableRow(
                children: [
                  _td(r.santierNume, font),
                  _td(_fmtDate(r.dataStart), font, align: pw.TextAlign.center),
                  _td(_fmtDate(r.dataFinal), font, align: pw.TextAlign.center),
                  _tdStatus(r.status, font),
                  _td(r.creatDeNume, font),
                ],
              )),
            ],
          ),
      ],
    );
  }

  pw.Widget _tdStatus(String status, pw.Font font) {
    final label = status == 'aprobat' ? 'Aprobat'
        : status == 'respins' ? 'Respins' : 'In asteptare';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(label,
          style: pw.TextStyle(
              font: font, fontSize: 8, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center),
    );
  }

  // ── Observații ───────────────────────────────────────────────────────────────
  pw.Widget _pdfObservatii(String obs, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'OBSERVAȚII:',
          style: pw.TextStyle(
              font: font, fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 3),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(obs, style: pw.TextStyle(font: font, fontSize: 9)),
        ),
      ],
    );
  }

  // ── Celule tabel ─────────────────────────────────────────────────────────────
  pw.Widget _th(String text, pw.Font font,
      [pw.TextAlign align = pw.TextAlign.left]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style:
        pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold),
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

  // ── Helpers ──────────────────────────────────────────────────────────────────
  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _translateVehicleStatus(VehicleStatus s) {
    switch (s) {
      case VehicleStatus.laBase:
        return 'La Bază';
      case VehicleStatus.inSantier:
        return 'În Șantier';
      case VehicleStatus.laReparatie:
        return 'La Reparație';
    }
  }
}

// ── Model intern pentru datele din rezervari ─────────────────────────────────
class _RezervareInfo {
  final String santierNume;
  final DateTime dataStart;
  final DateTime dataFinal;
  final String status;
  final String creatDeNume;

  const _RezervareInfo({
    required this.santierNume,
    required this.dataStart,
    required this.dataFinal,
    required this.status,
    required this.creatDeNume,
  });
}

// =============================================================================
// _VehicleFilter — date returnate de bottom sheet
// =============================================================================

class _VehicleFilter {
  final VehicleStatus? status;
  final String clasa;
  final String subclasa;

  const _VehicleFilter({
    required this.status,
    required this.clasa,
    required this.subclasa,
  });
}

// =============================================================================
// _VehicleFilterSheet — bottom sheet identic ca design cu _PdfFilterSheet
// =============================================================================

class _VehicleFilterSheet extends StatefulWidget {
  final _VehicleFilter current;
  final List<String> allClase;
  final List<String> allSubclase;

  const _VehicleFilterSheet({
    required this.current,
    required this.allClase,
    required this.allSubclase,
  });

  @override
  State<_VehicleFilterSheet> createState() => _VehicleFilterSheetState();
}

class _VehicleFilterSheetState extends State<_VehicleFilterSheet> {
  late VehicleStatus? _status;
  late String _clasa;
  late String _subclasa;

  @override
  void initState() {
    super.initState();
    _status   = widget.current.status;
    _clasa    = widget.current.clasa;
    _subclasa = widget.current.subclasa;
  }

  // Subclasele se filtrează după clasa selectată (dacă există o clasă selectată)
  List<String> get _filteredSubclase => widget.allSubclase;

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
        // ── Handle ───────────────────────────────────────────────────────────
        Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ApprovalTheme.borderColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
        ]),

        // ── Header ───────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('Filtru vehicule', style: ApprovalTheme.textTitle(context)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _status   = null;
                _clasa    = 'Toate';
                _subclasa = 'Toate';
              }),
              child: const Text('Resetează'),
            ),
          ]),
        ),
        const Divider(height: 1),

        // ── Conținut scrollabil ───────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Status dropdown — identic cu _FilterDropdown din santiere_list_page
                DropdownButtonFormField<VehicleStatus?>(
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
                    DropdownMenuItem<VehicleStatus?>(
                      value: null,
                      child: Text('Toate',
                          style: ApprovalTheme.textBody(context)),
                    ),
                    DropdownMenuItem(
                      value: VehicleStatus.laBase,
                      child: Text('La Bază',
                          style: ApprovalTheme.textBody(context)),
                    ),
                    DropdownMenuItem(
                      value: VehicleStatus.inSantier,
                      child: Text('În Șantier',
                          style: ApprovalTheme.textBody(context)),
                    ),
                    DropdownMenuItem(
                      value: VehicleStatus.laReparatie,
                      child: Text('La Reparație',
                          style: ApprovalTheme.textBody(context)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _status = v),
                ),

                const SizedBox(height: 12),

                // ── Clasă ────────────────────────────────────────────────────
                DropdownButtonFormField<String>(
                  value: _clasa,
                  decoration: InputDecoration(
                    labelText: 'Clasă',
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
                  items: widget.allClase
                      .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c,
                        style: ApprovalTheme.textBody(context)),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _clasa    = v ?? 'Toate';
                    _subclasa = 'Toate';
                  }),
                ),

                const SizedBox(height: 12),

                // ── Subclasă ─────────────────────────────────────────────────
                DropdownButtonFormField<String>(
                  value: _filteredSubclase.contains(_subclasa)
                      ? _subclasa
                      : 'Toate',
                  decoration: InputDecoration(
                    labelText: 'Subclasă',
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
                  items: _filteredSubclase
                      .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s,
                        style: ApprovalTheme.textBody(context)),
                  ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _subclasa = v ?? 'Toate'),
                ),
              ],
            ),
          ),
        ),

        // ── Buton Aplică ─────────────────────────────────────────────────────
        Padding(
          padding:
          EdgeInsets.fromLTRB(16, 8, 16, 16 + mq.viewInsets.bottom),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _VehicleFilter(
                  status: _status,
                  clasa: _clasa,
                  subclasa: _subclasa,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(ApprovalTheme.radiusMedium),
                ),
              ),
              child: const Text('Aplică filtrul'),
            ),
          ),
        ),
      ]),
    );
  }
}