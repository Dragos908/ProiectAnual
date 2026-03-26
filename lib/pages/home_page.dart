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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final l = AppLocalizations.of(context);
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.translate('appTitle'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          if (widget.currentUser.name.isNotEmpty)
            Text(widget.currentUser.name, style: const TextStyle(fontSize: 12)),
        ],
      ),
      actions: [_buildAppBarActions(l)],
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(icon: const Icon(Icons.construction), text: l.translate('santiere')),  // era: 'Șantiere'
          Tab(icon: const Icon(Icons.agriculture), text: l.translate('tehnica')),
          const Tab(icon: Icon(Icons.picture_as_pdf), text: 'PDF'),
        ],
      ),
    );
  }

  Widget _buildAppBarActions(AppLocalizations l) {
    final isNarrow = MediaQuery.of(context).size.width < 360;

    if (isNarrow) {
      return PopupMenuButton<_AppBarAction>(
        icon: const Icon(Icons.more_vert),
        tooltip: l.translate('options'),                          // era: 'Opțiuni'
        onSelected: (action) => switch (action) {
          _AppBarAction.settings   => AppSettings.showSettingsDialog(context),
          _AppBarAction.changeName => _showChangeNameDialog(),
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _AppBarAction.settings,
            child: Row(children: [
              const Icon(Icons.settings, size: 20),
              const SizedBox(width: 10),
              Text(l.translate('settings')),
            ]),
          ),
          PopupMenuItem(
            value: _AppBarAction.changeName,
            child: Row(children: [
              const Icon(Icons.person, size: 20),
              const SizedBox(width: 10),
              Text(l.translate('changeName')),                    // era: 'Schimbă numele'
            ]),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => AppSettings.showSettingsDialog(context),
          icon: const Icon(Icons.settings),
          tooltip: l.translate('settings'),
        ),
        IconButton(
          onPressed: _showChangeNameDialog,
          icon: const Icon(Icons.person),
          tooltip: l.translate('changeName'),                     // era: 'Schimbă numele'
        ),
      ],
    );
  }

  Future<void> _showChangeNameDialog() async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: widget.currentUser.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.translate('userName')),                     // era: 'Nume utilizator'
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l.translate('enterName'),                   // era: 'Introduceți numele...'
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.translate('cancel')),                   // era: 'Anulează'
          ),
          FilledButton(
            onPressed: () async {
              await widget.currentUser.updateNamePersistent(controller.text.trim());
              setState(() {});
              Navigator.pop(ctx);
            },
            child: Text(l.translate('save')),                     // era: 'Salvează'
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final tabs = [
      SantiereListPage(currentUser: widget.currentUser),
      TehnicaPage(currentUser: widget.currentUser),
      _PdfDataWrapper(currentUser: widget.currentUser),
    ];

    return Stack(
      children: List.generate(tabs.length, (i) {
        if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
        return Offstage(
          offstage: _tabController.index != i,
          child: TickerMode(
            enabled: _tabController.index == i,
            child: tabs[i],
          ),
        );
      }),
    );
  }
}

enum _AppBarAction { settings, changeName }

// PDF Data Wrapper
class _PdfDataWrapper extends StatelessWidget {
  final User currentUser;
  const _PdfDataWrapper({required this.currentUser});

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  Stream<List<Santier>> get _santiereStream => _db
      .collection('santiere')
      .snapshots()
      .map((s) => s.docs.map(Santier.fromDoc).toList());

  Stream<List<Comanda>> get _comenziStream => _db
      .collection('comenzi')
      .where('creatDeUserId', isEqualTo: currentUser.uid)
      .snapshots()
      .map((s) => s.docs.map(Comanda.fromDoc).toList());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                child: Text('${l.translate('eroare')}: ${santierSnap.error}'), // era: 'Eroare: ...'
              );
            }
            return CombinedPdfPage(
              santiere: santierSnap.data ?? [],
              comenzi:  comenziSnap.data ?? [],
            );
          },
        );
      },
    );
  }
}