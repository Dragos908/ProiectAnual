// ============================================================
// MECA – Modul Adăugare Date
// Fișier combinat: toate clasele modulului într-un singur fișier
//
// Cuprins:
//   1. LocalCacheService     – cache local SharedPreferences
//   2. VehicleService        – Firestore database 'meca', colecție 'vehicule'
//   3. OperatorService       – Firestore database 'meca', colecție 'operatori'
//   4. VehicleAddTab         – Fila 1: formular adăugare vehicul
//   5. OperatorAddTab        – Fila 2: formular adăugare operator
//   6. DataEntryPage         – pagina cu TabBar (Fila 1 + Fila 2)
//   7. HomePage (actualizat) – integrare tab "Adăugare Date"
// ============================================================

// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/app_localizations.dart';
import '/approval_theme.dart';
import '/models/user.dart';

// ════════════════════════════════════════════════════════════
// 1. LOCAL CACHE SERVICE
//    Gestionează persistența ultimei adăugări per filă
//    folosind SharedPreferences (cheile nu se suprapun).
// ════════════════════════════════════════════════════════════

class LocalCacheService {
  static const String _vehicleCacheKey = 'meca_last_vehicle';
  static const String _operatorCacheKey = 'meca_last_operator';

  // ---------- Fila 1 – Vehicul ----------

  /// Salvează datele ultimului vehicul adăugat în cache local.
  /// Înlocuiește complet cache-ul anterior (remove → set).
  Future<void> saveLastVehicle(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_vehicleCacheKey);
    await prefs.setString(_vehicleCacheKey, jsonEncode(data));
  }

  /// Returnează datele ultimului vehicul din cache,
  /// sau null dacă nu există / JSON invalid.
  Future<Map<String, dynamic>?> getLastVehicle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vehicleCacheKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  // ---------- Fila 2 – Operator ----------

  /// Salvează datele ultimului operator adăugat în cache local.
  /// Cache-ul Filei 2 este complet independent de cel al Filei 1.
  Future<void> saveLastOperator(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_operatorCacheKey);
    await prefs.setString(_operatorCacheKey, jsonEncode(data));
  }

  /// Returnează datele ultimului operator din cache,
  /// sau null dacă nu există / JSON invalid.
  Future<Map<String, dynamic>?> getLastOperator() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_operatorCacheKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}

// ════════════════════════════════════════════════════════════
// 2. VEHICLE SERVICE
//    Interacțiune Firestore pentru colecția "meca".
//    ID document = Numărul de Înmatriculare.
// ════════════════════════════════════════════════════════════

class VehicleService {
  // Database-ul 'meca' (NU colecția 'meca' — 'meca' este ID-ul bazei de date)
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'meca',
  );

  CollectionReference get _vehiclesRef => _db.collection('vehicles');

  /// Verifică dacă există deja un document cu ID = [docId].
  /// Apelat DOAR când utilizatorul a introdus un nr. de înmatriculare.
  Future<bool> vehicleExists(String docId) async {
    final doc = await _vehiclesRef.doc(docId).get()
        .timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Timeout: serverul nu răspunde. Verifică conexiunea.'),
    );
    return doc.exists;
  }

  /// Creează documentul în Firestore.
  /// [docId] = nr. înmatriculare dacă a fost introdus, altfel UID generat automat.
  Future<void> addVehicle({
    required String docId,      // ID document: nr. înmatriculare SAU UID
    required String clasa,
    required String subclasa,
    required String denumireModel,
    required String tonajMarime,
    required String locatieBaza,
  }) async {
    // ┌─────────────────────────────────────────────────────────┐
    // │  CÂMPURI SALVATE ÎN FIRESTORE (database: meca,          │
    // │  colecție: vehicles, document ID: numar_inmatriculare)  │
    // │                                                         │
    // │  [ID document] ← numar_inmatriculare (doar în titlu)    │
    // │  clasa                 ← combo opțional                 │
    // │  subclasa              ← combo opțional                 │
    // │  denumire_model        ← combo opțional                 │
    // │  tonaj_marime          ← combo opțional                 │
    // │  baza                  ← text liber scris de utilizator │
    // │  forma_dezvaluire      ← fix 'baza'                     │
    // │  data_inceput_rezervare← epoch 1970 (rezervat viitor)   │
    // │  data_sfarsit_rezervare← epoch 1970 (rezervat viitor)   │
    // │  creat_la              ← serverTimestamp() Firebase     │
    // └─────────────────────────────────────────────────────────┘

    final Timestamp zeroTs = Timestamp.fromDate(DateTime(1970, 1, 1, 0, 0, 0));

    await _vehiclesRef.doc(docId).set({
      // Numărul de înmatriculare este DOAR ID-ul documentului (denumirea tabelului)
      // NU se salvează și ca câmp separat
      'clasa': clasa,
      'subclasa': subclasa,
      'denumire_model': denumireModel,
      'tonaj_marime': tonajMarime,
      'baza': locatieBaza,                // scris de utilizator
      'forma_dezvaluire': 'baza',
      'data_inceput_rezervare': zeroTs,
      'data_sfarsit_rezervare': zeroTs,
      'creat_la': FieldValue.serverTimestamp(),
    }).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Timeout: serverul nu răspunde. Verifică conexiunea.'),
    );
  }

  /// Stream unic pentru toate vehiculele.
  /// Folosit de [_VehicleAddTabState] pentru a popula dropdown-urile
  /// fără citiri Firestore redundante.
  Stream<QuerySnapshot> vehiclesStream() => _vehiclesRef.snapshots();
}

// ════════════════════════════════════════════════════════════
// 3. OPERATOR SERVICE
//    Interacțiune Firestore pentru colecția "operatori".
//    Fiecare submit = document nou cu ID generat automat.
//    Fără nicio legătură cu colecția "meca".
// ════════════════════════════════════════════════════════════

class OperatorService {
  // Același database 'meca' — operatorii sunt în colecția 'operatori'
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'meca',
  );

  CollectionReference get _operatorsRef => _db.collection('operators');

  /// Adaugă un operator nou ca document independent în Firestore.
  /// [creat_la] folosește serverTimestamp() Firebase.
  Future<void> addOperator({
    required String numeOperator,
    required String notita,
  }) async {
    await _operatorsRef.add({
      'nume_operator': numeOperator,
      'notita': notita,
      'creat_la': FieldValue.serverTimestamp(),
    }).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Timeout: serverul nu răspunde. Verifică conexiunea.'),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 4. VEHICLE ADD TAB – Fila 1
//    Formular de adăugare vehicul cu:
//    - ComboBox (Autocomplete) cu deduplicare case-insensitive
//    - Validare Nr. Înmatriculare (format XX-00-XXX)
//    - Câmp 'baza' — text liber, scris de utilizator
//    - Verificare duplicat înainte de scriere
//    - Card "Ultima Adăugare" din cache local
// ════════════════════════════════════════════════════════════

class VehicleAddTab extends StatefulWidget {
  const VehicleAddTab({super.key});

  @override
  State<VehicleAddTab> createState() => _VehicleAddTabState();
}

class _VehicleAddTabState extends State<VehicleAddTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final VehicleService _vehicleService = VehicleService();
  final LocalCacheService _cacheService = LocalCacheService();

  final TextEditingController _clasaController = TextEditingController();
  final TextEditingController _subclasaController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _tonajController = TextEditingController();
  final TextEditingController _numarController = TextEditingController();
  final TextEditingController _bazaController = TextEditingController();

  // ─── Key pentru resetarea Autocomplete ───────────────────────────────────
  // Autocomplete are controller intern propriu care NU se sincronizează cu
  // .clear() pe controller-ul extern. Soluția: incrementăm _resetCounter
  // → Flutter reconstruiește widget-ul Autocomplete de la zero → gol.
  int _resetCounter = 0;

  bool _isLoading = false;
  Map<String, dynamic>? _lastAdded;

  Map<String, List<String>> _dropdownOptions = {
    'clasa': [],
    'subclasa': [],
    'denumire_model': [],
    'tonaj_marime': [],
    'baza': [],
  };

  @override
  void initState() {
    super.initState();
    _loadCache();
    _listenToVehicles();
  }

  @override
  void dispose() {
    _clasaController.dispose();
    _subclasaController.dispose();
    _modelController.dispose();
    _tonajController.dispose();
    _numarController.dispose();
    _bazaController.dispose();
    super.dispose();
  }

  /// Ascultă stream-ul Firestore și extrage valorile unice per câmp.
  /// Deduplicarea este case-insensitive: "Baza" și "baza" → un singur item.
  /// Sortare alfabetică locală (fără orderBy Firestore).
  void _listenToVehicles() {
    _vehicleService.vehiclesStream().listen((snapshot) {
      final Map<String, Set<String>> raw = {
        'clasa': {},
        'subclasa': {},
        'denumire_model': {},
        'tonaj_marime': {},
        'baza': {},
      };

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        for (final key in raw.keys) {
          final val = data[key];
          if (val != null && val.toString().trim().isNotEmpty) {
            raw[key]!.add(val.toString().trim());
          }
        }
      }

      final deduped = <String, List<String>>{};
      for (final key in raw.keys) {
        final seen = <String, String>{};
        for (final val in raw[key]!) {
          seen.putIfAbsent(val.toLowerCase(), () => val);
        }
        deduped[key] = seen.values.toList()..sort();
      }

      if (mounted) setState(() => _dropdownOptions = deduped);
    });
  }

  Future<void> _loadCache() async {
    final cached = await _cacheService.getLastVehicle();
    if (mounted && cached != null) setState(() => _lastAdded = cached);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final numarInput = _numarController.text.replaceAll(' ', '').toUpperCase();
    final clasa = _clasaController.text.trim();
    final subclasa = _subclasaController.text.trim();
    final model = _modelController.text.trim();
    final tonaj = _tonajController.text.trim();
    final locatie = _bazaController.text.trim();

    // Dacă utilizatorul a introdus un nr. de înmatriculare → îl folosim ca ID.
    // Dacă NU → generăm un UID unic automat.
    final String docId = numarInput.isNotEmpty
        ? numarInput
        : const Uuid().v4();

    setState(() => _isLoading = true);
    try {
      // Verificăm duplicatul DOAR dacă s-a introdus un nr. de înmatriculare
      if (numarInput.isNotEmpty) {
        final exists = await _vehicleService.vehicleExists(docId);
        if (exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                AppLocalizations.of(context)
                    .translate('vehicleDuplicateError')
                    .replaceAll('{nr}', numarInput),
              ),
              backgroundColor: ApprovalTheme.errorColor(context),
            ));
          }
          return;
        }
      }

      await _vehicleService.addVehicle(
        docId: docId,
        clasa: clasa,
        subclasa: subclasa,
        denumireModel: model,
        tonajMarime: tonaj,
        locatieBaza: locatie,
      );

      final cacheData = {
        'clasa': clasa,
        'subclasa': subclasa,
        'denumire_model': model,
        'tonaj_marime': tonaj,
        // afișăm nr. înmatriculare sau 'UID auto' în cardul "Ultima adăugare"
        'numar_inmatriculare': numarInput.isNotEmpty ? numarInput : '(UID auto)',
        'baza': locatie,
        'adaugat_la': DateTime.now().toIso8601String(),
      };
      await _cacheService.saveLastVehicle(cacheData);

      if (mounted) {
        setState(() => _lastAdded = cacheData);
        _resetPartial();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).translate('vehicleAddedSuccess')),
          backgroundColor: ApprovalTheme.successColor(context),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${AppLocalizations.of(context).translate('networkError')}: $e',
          ),
          backgroundColor: ApprovalTheme.errorColor(context),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Șterge doar model, nr. înmatriculare, tonaj — după adăugare reușită
  void _resetPartial() {
    FocusScope.of(context).unfocus(); // Ascunde tastatura

    // 1. ÎNTÂI resetăm formularul (asta curăță textele roșii de eroare)
    _formKey.currentState?.reset();

    // 2. ABIA APOI golim controllerele. Astfel, ștergerea rămâne definitivă.
    _modelController.clear();
    _tonajController.clear();
    _numarController.clear();

    // 3. Reconstruim elementele Autocomplete
    setState(() => _resetCounter++);
  }

  // Șterge TOATE câmpurile — butonul "Șterge tot"
  void _resetAll() {
    FocusScope.of(context).unfocus();

    // 1. Resetăm formularul primul
    _formKey.currentState?.reset();

    // 2. Curățăm agresiv toate controllerele
    _clasaController.clear();
    _subclasaController.clear();
    _modelController.clear();
    _tonajController.clear();
    _numarController.clear();
    _bazaController.clear();

    // 3. Reconstruim widget-urile
    setState(() {
      _resetCounter++;
    });
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ApprovalTheme.paddingLarge),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _combo(l.translate('vehicleClass'), _clasaController, 'clasa'),
            const SizedBox(height: ApprovalTheme.marginLarge),
            _combo(l.translate('vehicleSubclass'), _subclasaController, 'subclasa'),
            const SizedBox(height: ApprovalTheme.marginLarge),
            _combo(l.translate('vehicleModel'), _modelController, 'denumire_model', required: true),
            const SizedBox(height: ApprovalTheme.marginLarge),
            _combo(l.translate('vehicleTonnage'), _tonajController, 'tonaj_marime'),
            const SizedBox(height: ApprovalTheme.marginLarge),
            _plateField(l),
            const SizedBox(height: ApprovalTheme.marginLarge),
            _combo(l.translate('locatieBaza'), _bazaController, 'baza', required: true),
            const SizedBox(height: ApprovalTheme.paddingLarge * 1.5),
            _submitBtn(l),
            if (_lastAdded != null) ...[
              const SizedBox(height: ApprovalTheme.paddingLarge),
              _lastAddedCard(l),
            ],
          ],
        ),
      ),
    );
  }

  /// Widget ComboBox: Autocomplete cu opțiuni din Firestore +
  /// posibilitate de text liber. Prefix icon după tipul câmpului.
  Widget _combo(
      String label,
      TextEditingController extCtrl,
      String fieldKey, {
        bool required = false,
      }) {
    final options = _dropdownOptions[fieldKey] ?? [];

    final IconData prefixIcon = switch (fieldKey) {
      'clasa'          => Icons.category_outlined,
      'subclasa'       => Icons.label_outline,
      'denumire_model' => Icons.directions_car_outlined,
      'tonaj_marime'   => Icons.scale_outlined,
      'baza'           => Icons.location_on_outlined,
      _                => Icons.text_fields_outlined,
    };

    return Autocomplete<String>(
      // Key unic per câmp + _resetCounter → rebuild complet la reset
      key: ValueKey('$fieldKey-$_resetCounter'),
      optionsBuilder: (tv) => tv.text.isEmpty
          ? options
          : options.where((o) => o.toLowerCase().contains(tv.text.toLowerCase())),
      onSelected: (v) => extCtrl.text = v,
      fieldViewBuilder: (ctx, fieldCtrl, focusNode, onSubmitted) {
        // Sincronizare unidirecțională: extCtrl → fieldCtrl (la init)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (fieldCtrl.text != extCtrl.text) {
            fieldCtrl.text = extCtrl.text;
          }
        });
        // Sincronizare: fieldCtrl → extCtrl (la tastare)
        fieldCtrl.addListener(() {
          if (extCtrl.text != fieldCtrl.text) extCtrl.text = fieldCtrl.text;
        });

        return TextFormField(
          controller: fieldCtrl,
          focusNode: focusNode,
          style: ApprovalTheme.textBody(ctx),
          decoration: ApprovalTheme.inputDecoration(ctx, label).copyWith(
            prefixIcon: Icon(prefixIcon,
                color: ApprovalTheme.textSecondary(ctx), size: 20),
            suffixIcon: Icon(Icons.arrow_drop_down,
                color: ApprovalTheme.textSecondary(ctx), size: 20),
          ),
          validator: (v) => required && (v == null || v.trim().isEmpty)
              ? AppLocalizations.of(ctx).translate('requiredField')
              : null,
        );
      },
      optionsViewBuilder: (ctx, onSelected, opts) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 2,
          color: ApprovalTheme.surfaceBackground(ctx),
          borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: opts.length,
              itemBuilder: (_, i) {
                final opt = opts.elementAt(i);
                return InkWell(
                  onTap: () => onSelected(opt),
                  borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ApprovalTheme.paddingMedium,
                      vertical: ApprovalTheme.paddingSmall,
                    ),
                    child: Text(opt, style: ApprovalTheme.textBody(ctx)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Câmp Nr. Înmatriculare: OPȚIONAL, litere mari automat.
  /// Dacă e gol → ID document = UID generat automat.
  /// Dacă e completat → verificăm să nu existe deja în Firestore.
  Widget _plateField(AppLocalizations l) {
    return TextFormField(
      controller: _numarController,
      style: ApprovalTheme.textBody(context),
      textCapitalization: TextCapitalization.characters,
      decoration: ApprovalTheme.inputDecoration(
        context,
        '${l.translate('licensePlate')} (${l.translate('optional')})',
      ).copyWith(
        prefixIcon: Icon(Icons.badge_outlined,
            color: ApprovalTheme.textSecondary(context), size: 20),
      ),
      onChanged: (v) {
        final clean = v.toUpperCase().replaceAll(' ', '');
        if (v != clean) {
          _numarController.value = _numarController.value.copyWith(
            text: clean,
            selection: TextSelection.collapsed(offset: clean.length),
          );
        }
      },
    );
  }



  Widget _submitBtn(AppLocalizations l) {
    return Row(
      children: [
        // ── Buton principal: Adaugă Vehicul ──
        Expanded(
          flex: 3,
          child: FilledButton(
            style: ApprovalTheme.primaryButtonStyle(context),
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : Text(l.translate('addVehicle'), style: ApprovalTheme.buttonTextStyle),
          ),
        ),
        const SizedBox(width: 10),
        // ── Buton secundar: Șterge Tot ──
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: ApprovalTheme.errorColor(context),
              side: BorderSide(color: ApprovalTheme.errorColor(context)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
              ),
            ),
            onPressed: _isLoading ? null : _resetAll,
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: const Text('Șterge tot'),
          ),
        ),
      ],
    );
  }

  /// Card cu datele ultimei adăugări reușite.
  /// Stocat exclusiv în SharedPreferences, nu în Firestore.
  Widget _lastAddedCard(AppLocalizations l) {
    final d = _lastAdded!;
    return Container(
      decoration: BoxDecoration(
        color: ApprovalTheme.surfaceBackground(context),
        borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
        border: Border.all(
          color: ApprovalTheme.borderColor(context),
          width: ApprovalTheme.borderWidth,
        ),
      ),
      padding: const EdgeInsets.all(ApprovalTheme.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.translate('lastAdded'), style: ApprovalTheme.textTitle(context)),
          const SizedBox(height: 8),
          Divider(color: ApprovalTheme.borderColor(context), height: 1),
          const SizedBox(height: 8),
          _row(l.translate('vehicleClass'), d['clasa'] ?? ''),
          _row(l.translate('vehicleSubclass'), d['subclasa'] ?? ''),
          _row(l.translate('vehicleModel'), d['denumire_model'] ?? ''),
          _row(l.translate('vehicleTonnage'), d['tonaj_marime'] ?? ''),
          _row(l.translate('licensePlate'), d['numar_inmatriculare'] ?? ''),
          _row(l.translate('locatieBaza'), d['baza'] ?? ''),
          if ((d['adaugat_la'] ?? '').isNotEmpty)
            _row(l.translate('addedAt'), _fmtDate(d['adaugat_la'])),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text('$label:', style: ApprovalTheme.textSmall(context)),
        ),
        Expanded(child: Text(value, style: ApprovalTheme.textBody(context))),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════
// 5. OPERATOR ADD TAB – Fila 2
//    Complet independentă de Fila 1.
//    Câmpuri: Nume Operator (obligatoriu) + Notiță (opțional).
//    Fiecare submit = document nou în colecția "operatori".
//    Card "Ultima Adăugare" din cache local independent.
// ════════════════════════════════════════════════════════════

class OperatorAddTab extends StatefulWidget {
  const OperatorAddTab({super.key});

  @override
  State<OperatorAddTab> createState() => _OperatorAddTabState();
}

class _OperatorAddTabState extends State<OperatorAddTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final OperatorService _operatorService = OperatorService();
  final LocalCacheService _cacheService = LocalCacheService();

  final TextEditingController _numeController = TextEditingController();
  final TextEditingController _notitaController = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic>? _lastAdded;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  @override
  void dispose() {
    _numeController.dispose();
    _notitaController.dispose();
    super.dispose();
  }

  Future<void> _loadCache() async {
    final cached = await _cacheService.getLastOperator();
    if (mounted && cached != null) setState(() => _lastAdded = cached);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final nume = _numeController.text.trim();
    final notita = _notitaController.text.trim();

    setState(() => _isLoading = true);
    try {
      await _operatorService.addOperator(numeOperator: nume, notita: notita);

      final cacheData = {
        'nume_operator': nume,
        'notita': notita,
        'adaugat_la': DateTime.now().toIso8601String(),
      };
      await _cacheService.saveLastOperator(cacheData);

      if (mounted) {
        setState(() => _lastAdded = cacheData);
        _numeController.clear();
        _notitaController.clear();
        _formKey.currentState?.reset();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            AppLocalizations.of(context).translate('operatorAddedSuccess'),
          ),
          backgroundColor: ApprovalTheme.successColor(context),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${AppLocalizations.of(context).translate('networkError')}: $e',
          ),
          backgroundColor: ApprovalTheme.errorColor(context),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ApprovalTheme.paddingLarge),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.translate('operatorTabDescription'),
              style: ApprovalTheme.textSmall(context),
            ),
            const SizedBox(height: ApprovalTheme.paddingLarge),
            TextFormField(
              controller: _numeController,
              style: ApprovalTheme.textBody(context),
              textCapitalization: TextCapitalization.words,
              decoration: ApprovalTheme.inputDecoration(
                context,
                l.translate('operatorName'),
              ).copyWith(
                prefixIcon: Icon(Icons.person_outline,
                    color: ApprovalTheme.textSecondary(context), size: 20),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l.translate('requiredField')
                  : null,
            ),
            const SizedBox(height: ApprovalTheme.marginLarge),
            TextFormField(
              controller: _notitaController,
              style: ApprovalTheme.textBody(context),
              maxLines: 4,
              decoration: ApprovalTheme.inputDecoration(
                context,
                '${l.translate('operatorNote')} (${l.translate('optional')})',
              ).copyWith(
                prefixIcon: Icon(Icons.notes_outlined,
                    color: ApprovalTheme.textSecondary(context), size: 20),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: ApprovalTheme.paddingLarge * 1.5),
            FilledButton(
              style: ApprovalTheme.primaryButtonStyle(context),
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : Text(l.translate('addOperator'),
                  style: ApprovalTheme.buttonTextStyle),
            ),
            if (_lastAdded != null) ...[
              const SizedBox(height: ApprovalTheme.paddingLarge),
              _lastAddedCard(l),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lastAddedCard(AppLocalizations l) {
    final d = _lastAdded!;
    return Container(
      decoration: BoxDecoration(
        color: ApprovalTheme.surfaceBackground(context),
        borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
        border: Border.all(
          color: ApprovalTheme.borderColor(context),
          width: ApprovalTheme.borderWidth,
        ),
      ),
      padding: const EdgeInsets.all(ApprovalTheme.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.translate('lastAdded'), style: ApprovalTheme.textTitle(context)),
          const SizedBox(height: 8),
          Divider(color: ApprovalTheme.borderColor(context), height: 1),
          const SizedBox(height: 8),
          _row(l.translate('operatorName'), d['nume_operator'] ?? ''),
          if ((d['notita'] ?? '').isNotEmpty)
            _row(l.translate('operatorNote'), d['notita']),
          if ((d['adaugat_la'] ?? '').isNotEmpty)
            _row(l.translate('addedAt'), _fmtDate(d['adaugat_la'])),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text('$label:', style: ApprovalTheme.textSmall(context)),
        ),
        Expanded(child: Text(value, style: ApprovalTheme.textBody(context))),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════
// 6. DATA ENTRY PAGE
//    Pagina principală a modulului. Conține un TabBar cu 2 file:
//      - Fila 1: VehicleAddTab
//      - Fila 2: OperatorAddTab
//    Schimbarea filei NU resetează starea celeilalte file
//    (AutomaticKeepAliveClientMixin pe fiecare tab).
//    Accesibilă doar pentru Admin și Operator (rol).
// ════════════════════════════════════════════════════════════

class DataEntryPage extends StatefulWidget {
  final User currentUser;
  const DataEntryPage({super.key, required this.currentUser});

  @override
  State<DataEntryPage> createState() => _DataEntryPageState();
}

class _DataEntryPageState extends State<DataEntryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    // NU folosim Scaffold imbricat – DataEntryPage este deja copilul unui
    // TabBarView din HomePage. Un Scaffold suplimentar ar produce AppBar
    // dublu și probleme de navigare. Folosim Column + Expanded.
    return Column(
      children: [
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: ApprovalTheme.primaryAccent(context),
            unselectedLabelColor: ApprovalTheme.textSecondary(context),
            indicatorColor: ApprovalTheme.primaryAccent(context),
            tabs: [
              Tab(
                icon: const Icon(Icons.directions_car_outlined),
                text: l.translate('tabVehicle'),
              ),
              Tab(
                icon: const Icon(Icons.person_add_outlined),
                text: l.translate('tabOperator'),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              VehicleAddTab(),
              OperatorAddTab(),
            ],
          ),
        ),
      ],
    );
  }
}