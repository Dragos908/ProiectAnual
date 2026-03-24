import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/santier_model.dart';
import '../models/comanda_model.dart';
import '../app_settings.dart';
import '../app_localizations.dart';
import 'tehnica_page.dart';
import '/pages/santiere/santiere_list_page.dart';
import '/pages/tabs/santier_pdf_tab.dart';

class HomePage extends StatefulWidget {
  final User currentUser;
  const HomePage({super.key, required this.currentUser});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _visitedTabs.add(_tabController.index));
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildAppBar() {
    final l = AppLocalizations.of(context);

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.translate('appTitle'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          // Afișează numele utilizatorului dacă există, altfel nimic
          if (widget.currentUser.name.isNotEmpty)
            Text(
              widget.currentUser.name,
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => AppSettings.showSettingsDialog(context),
          icon: const Icon(Icons.settings),
          tooltip: l.translate('settings'),
        ),
        // Buton pentru schimbarea numelui utilizatorului
        IconButton(
          onPressed: () => _showChangeNameDialog(context),
          icon: const Icon(Icons.person),
          tooltip: 'Schimbă numele',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: [
          const Tab(icon: Icon(Icons.construction), text: 'Șantiere'),
          Tab(icon: const Icon(Icons.agriculture), text: l.translate('tehnica')),
          const Tab(icon: Icon(Icons.picture_as_pdf), text: 'PDF'),
        ],
      ),
    );
  }

  /// Dialog simplu pentru a seta/modifica numele utilizatorului.
  Future<void> _showChangeNameDialog(BuildContext context) async {
    final controller =
    TextEditingController(text: widget.currentUser.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nume utilizator'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Introduceți numele...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () async {
              await widget.currentUser.updateNamePersistent(controller.text.trim());
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildLazyBody(),
    );
  }

  Widget _buildLazyBody() {
    final allTabs = [
      SantiereListPage(currentUser: widget.currentUser),
      TehnicaPage(currentUser: widget.currentUser),
      _PdfDataWrapper(currentUser: widget.currentUser),
    ];

    return Stack(
      children: List.generate(allTabs.length, (i) {
        if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
        return Offstage(
          offstage: _tabController.index != i,
          child: TickerMode(
            enabled: _tabController.index == i,
            child: allTabs[i],
          ),
        );
      }),
    );
  }
}

// =============================================================================
// _PdfDataWrapper
// =============================================================================

class _PdfDataWrapper extends StatelessWidget {
  final User currentUser;

  const _PdfDataWrapper({required this.currentUser});

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  Stream<List<Santier>> get _santiereStream => _db
      .collection('santiere')
      .where('creatDeUserId', isEqualTo: currentUser.uid)
      .snapshots()
      .map((s) => s.docs.map(Santier.fromDoc).toList());

  Stream<List<Comanda>> get _comenziStream => _db
      .collection('comenzi')
      .where('creatDeUserId', isEqualTo: currentUser.uid)
      .snapshots()
      .map((s) => s.docs.map(Comanda.fromDoc).toList());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Santier>>(
      stream: _santiereStream,
      builder: (context, santierSnap) {
        return StreamBuilder<List<Comanda>>(
          stream: _comenziStream,
          builder: (context, comenziSnap) {
            if (santierSnap.connectionState == ConnectionState.waiting &&
                !santierSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (santierSnap.hasError) {
              return Center(
                child: Text('Eroare: ${santierSnap.error}'),
              );
            }

            final santiere = santierSnap.data ?? [];
            final comenzi = comenziSnap.data ?? [];

            return CombinedPdfPage(
              santiere: santiere,
              comenzi: comenzi,
            );
          },
        );
      },
    );
  }
}