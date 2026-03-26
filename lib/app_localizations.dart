import 'package:flutter/material.dart';

class AppLocalizations {
  static const LocalizationsDelegate<AppLocalizations> delegate =
  _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  final Map<String, String> _localizedStrings;

  AppLocalizations(this._localizedStrings);

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  // Metode helper pentru texte comune
  String get appTitle => translate('appTitle');
  String get settings => translate('settings');
  String get save => translate('save');
  String get cancel => translate('cancel');
  String get close => translate('close');
  String get theme => translate('theme');
  String get language => translate('language');
  String get lightMode => translate('lightMode');
  String get darkMode => translate('darkMode');
  String get myOrders => translate('myOrders');
  String get allOrders => translate('allOrders');
  String get approval => translate('approval');
  String get statistics => translate('statistics');
  String get newOrder => translate('newOrder');
  String get logout => translate('logout');
  String get invalidTOTP => translate('invalidTOTP');
  String get inviteCodeGenerated => translate('inviteCodeGenerated');
  String get codeCopied => translate('codeCopied');
  String get orderAdded => translate('orderAdded');
  String get statusUpdated => translate('statusUpdated');
  String get orderUpdated => translate('orderUpdated');
  String get hours => translate('hours');
  String get adminPanel => translate('adminPanel');
  String get generateInviteCode => translate('generateInviteCode');
  String get generateInviteCodeDescription => translate('generateInviteCodeDescription');
  String get generatingCode => translate('generatingCode');
  String get generateWithTOTP => translate('generateWithTOTP');
  String get userStatistics => translate('userStatistics');
  String get noPendingOrders => translate('noPendingOrders');
  String get pendingOrdersCount => translate('pendingOrdersCount');
  String get approveRejectOrders => translate('approveRejectOrders');
  String get nucomenzi => translate('nucomenzi');
  String get initializing => translate('initializing');
  String get checkingConnection => translate('checkingConnection');
  String get noInternetConnection => translate('noInternetConnection');
  String get redirecting => translate('redirecting');
  String get checkingAuth => translate('checkingAuth');
  String get emailNotVerified => translate('emailNotVerified');
  String get loadingData => translate('loadingData');
  String get missingData => translate('missingData');
  String get welcome => translate('welcome');
  String get connectionError => translate('connectionError');
  String get santiere => translate('santiere');
  String get options => translate('options');
  String get changeName => translate('changeName');
  String get userName => translate('userName');
  String get enterName => translate('enterName');

  // Rezervare / Comanda
  String get vehicleNotFound        => translate('vehicleNotFound');
  String get intervalSuprapus       => translate('intervalSuprapus');
  String get searchVehicle          => translate('searchVehicle');
  String get selectVehicle          => translate('selectVehicle');
  String get noVehicleSelected      => translate('noVehicleSelected');
  String get comandaCreated         => translate('comandaCreated');
  String get comandaDeleted         => translate('comandaDeleted');
  String get comandaIntervalUpdated => translate('comandaIntervalUpdated');
  String get overlapError           => translate('overlapError');
  String get statusPending          => translate('statusPending');
  String get statusAprobat          => translate('statusAprobat');
  String get statusRespins          => translate('statusRespins');

  // Santier
  String get createSantier    => translate('createSantier');
  String get santierCreated   => translate('santierCreated');
  String get santierUpdated   => translate('santierUpdated');
  String get denumire         => translate('denumire');
  String get locatie          => translate('locatie');
  String get dataIncepere     => translate('dataIncepere');
  String get dataFinalizare   => translate('dataFinalizare');
  String get colorSantier     => translate('colorSantier');

  // Getters for keys already in maps (used across pages)
  String get eroare           => translate('eroare');
  String get editSantier      => translate('editSantier');
  String get reset            => translate('reset');
  String get perioadaCreare   => translate('perioadaCreare');
  String get applyFilter      => translate('applyFilter');
  String get all              => translate('all');
  String get requiredField    => translate('requiredField');
  String get dateUnspecified  => translate('dateUnspecified');
  String get oriceData        => translate('oriceData');
  String get selectDate       => translate('selectDate');
  // SantiereListPage
  String get santiereActivi       => translate('santiereActivi');
  String get santiereSuspendati   => translate('santiereSuspendati');
  String get santiereArhivati     => translate('santiereArhivati');
  String get noSantiere           => translate('noSantiere');
  String get santierNou           => translate('santierNou');
  String get loadError            => translate('loadError');
  String get dateFinalizareError  => translate('dateFinalizareError');
  String get timeoutError         => translate('timeoutError');
  String get noEditPermission     => translate('noEditPermission');
  String get filtruSantiere       => translate('filtruSantiere');
  String get minThreeChars        => translate('minThreeChars');
  String get creaza               => translate('creaza');

  // ComandaFormSheet
  String get selectMecanism          => translate('selectMecanism');
  String get selectDateTimeStartEnd  => translate('selectDateTimeStartEnd');
  String get finalAfterStart         => translate('finalAfterStart');
  String get comandaActualizata      => translate('comandaActualizata');
  String get comandaTrimisaAprobare  => translate('comandaTrimisaAprobare');
  String get intervalSuprapusCu      => translate('intervalSuprapusCu');
  String get rezervatDe              => translate('rezervatDe');
  String get deleteError             => translate('deleteError');
  String get mechanismHint           => translate('mechanismHint');
  String get selectMechanismFromList => translate('selectMechanismFromList');
  String get mechanismNotFound       => translate('mechanismNotFound');
  String get calendarLabel           => translate('calendarLabel');
  String get noteOptional            => translate('noteOptional');
  String get actualizeaza            => translate('actualizeaza');
  String get trimiteSpreAprobare     => translate('trimiteSpreAprobare');
  String get selectDateAndTime       => translate('selectDateAndTime');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ro', 'ru'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final Map<String, String> localizedStrings;

    switch (locale.languageCode) {
      case 'ru':
        localizedStrings = _ruLocalizedStrings;
        break;
      case 'ro':
      default:
        localizedStrings = _roLocalizedStrings;
    }

    return AppLocalizations(localizedStrings);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;

  static final Map<String, String> _roLocalizedStrings = {
    'simpleUser': 'Utilizator Simplu',
    'operator': 'Operator',
    'admin': 'Administrator',
    'appTitle': 'Sistem de comandă',
    'login': 'Autentificare',
    'logout': 'Deconectare',
    'settings': 'Setări',
    'save': 'Salvează',
    'cancel': 'Anulează',
    'close': 'Închide',
    'theme': 'Temă',
    'language': 'Limbă',
    'lightMode': 'Mod Lumină',
    'darkMode': 'Mod Întuneric',
    'myOrders': 'Comenzile Mele',
    'allOrders': 'Toate Comenzile',
    'approval': 'Aprobare',
    'statistics': 'Statistici',
    'newOrder': 'Comandă Nouă',
    'licensePlate': 'Număr Înmatriculare',
    'object': 'Obiect',
    'date': 'Dată',
    'time': 'Oră',
    'notes': 'Notițe',
    'urgent': 'Urgent',
    'pending': 'În Așteptare',
    'approved': 'Aprobat',
    'completed': 'Finalizat',
    'rejected': 'Respins',
    'search': 'Căutare',
    'filters': 'Filtre',
    'advancedFilters': 'Filtre Avansate',
    'fromDate': 'De la data',
    'toDate': 'Până la data',
    'fromTime': 'De la ora',
    'toTime': 'Până la ora',
    'username': 'Utilizator',
    'user': 'Utilizator',
    'all': 'Toate',
    'clearFilters': 'Șterge Filtrele',
    'mechanismType': 'Tip Mecanism',
    'units': 'Unități',
    'addMechanism': 'Adaugă Mecanism',
    'photos': 'Poze',
    'addPhoto': 'Adaugă Poză',
    'takePicture': 'Fă o Poză',
    'orderDetails': 'Detalii Comandă',
    'editOrder': 'Editare Comandă',
    'addOrder': 'Adaugă Comandă',
    'delete': 'Șterge',
    'confirm': 'Confirmă',
    'requiredField': 'Câmp obligatoriu',
    'invalidFormat': 'Format invalid',
    'allStatus': 'Toate Stările',

    // Settings
    'romanian': 'Română',
    'russian': 'Rusă',

    'hours': 'ore',

    // Admin panel
    'adminPanel': 'Panou Administrator',
    'generateInviteCode': 'Generează Cod Invitație',
    'inviteCode': 'Cod Invitație',
    'expires': 'Expiră',
    'generateWithTOTP': 'Generează cu TOTP',
    'copyCode': 'Copiază Cod',
    'totpVerification': 'Verificare TOTP',
    'enterTOTP': 'Introdu codul din Google Authenticator',
    'expectedCode': 'Cod așteptat (DEMO)',
    'totpCode': 'Cod TOTP',
    'verify': 'Verifică',
    'generatingCode': 'Se generează codul...',

    // Mechanism types
    'engine': 'Motor',
    'pump': 'Pompă',
    'transmission': 'Transmisie',

    // Success messages
    'invalidTOTP': 'Cod TOTP invalid!',
    'inviteCodeGenerated': 'Cod invitație generat cu succes!',
    'codeCopied': 'Cod copiat în clipboard!',
    'orderAdded': 'Comandă adăugată cu succes!',
    'statusUpdated': 'Status actualizat!',
    'orderUpdated': 'Comandă actualizată!',

    'generateInviteCodeDescription': 'Generează un cod pentru a permite altor persoane să se înregistreze în aplicație.',
    'userStatistics': 'Statistici Utilizatori',

    'pendingOrdersCount': 'comenzi în așteptare',
    'approveRejectOrders': 'Aprobă sau respinge comenzile',
    'noPendingOrders': 'Nu există comenzi în așteptare',

    'nucomenzi': 'Nu s-au găsit comenzi',

    'generalStatistics': 'Statistici Generale',
    'orderStatusDistribution': 'Distribuție Status Comenzi',

    'pdfTab': 'PDF',
    'status': 'Status',
    'dateRange': 'Interval dată',
    'selectDateRange': 'Selectează interval',
    'generateAllPdfs': 'Generează toate PDF-urile',
    'noMatchingOrders': 'Nu există comenzi care să se potrivească',
    'mechanisms': 'Mecanisme',
    'previewPdf': 'Previzualizare PDF',
    'downloadPdf': 'Descarcă PDF',

    //approval_card
    'rejectOrder': 'Respinge comanda',
    'confirmRejectOrder': 'Ești sigur că vrei să respingi comanda?',
    'reject': 'Respinge',
    'approve': 'Aprobă',
    'workHours': 'Ore de lucru',

    //approval_form
    'fillAllFields': 'Completează toate câmpurile obligatorii pentru toate mecanismele',
    'fillMechanismData': 'Completează datele mecanismelor',
    'selectTime': 'Selectează ora',
    'peregon': 'Peregon',
    'yes': 'DA',
    'no': 'NU',

    //filters_card
    'searchHint': 'Caută după obiect, note sau tip mecanism...',
    'selectDate': 'Selectează dată',

    //order_card
    'noMechanisms': 'Fără mecanisme',
    'mechanismsShort': 'mecanizme',
    'more': 'mai mult',

    //orde_form_bottom_sheet
    'objectExample': 'ex: Livada de mere',
    'enterObjectName': 'Introdu denumirea obiectului',
    'photosOptional': 'Poze (opțional)',
    'photo': 'Poza',
    'mechanismTypes': 'Tipuri de mecanisme',
    'mechTypeHint': 'ex: Motor, Transmisie',
    'selectHours': 'Selectează orele',
    'edit': 'Editează',
    'urgentOrderSubtitle': 'Afișează comanda ca fiind prioritară',
    'optional': 'opțional',

    // Mesaje de eroare
    'fillTypeUnitsHours': 'Completează tipul, numărul de unități și orele',
    'unitsGreaterThanZero': 'Numărul de unități trebuie să fie mai mare decât 0',
    'hoursGreaterThanZero': 'Numărul de ore trebuie să fie mai mare decât 0',
    'addAtLeastOneMechanism': 'Trebuie să adaugi cel puțin un tip de mecanism',

    'chooseSource': 'Alege Sursa',
    'scanDocument': 'Scanează Document',
    'detectEdges': 'Detectare margini (PDF/Poză)',
    'pickGallery': 'Alege din Galerie',
    'noteHint': 'ex: notă importantă!',
    'addMechanismOrPhotoError': 'Adaugă cel puțin un mecanism SAU o poză!',
    'fillRequiredFields': 'Te rog completează câmpurile obligatorii!',

    'urgentOrder': 'Comandă Urgentă',
    'invalidMinutes': 'Minutele trebuie să fie între 00 și 59!',

    'secureApproval': 'Aprobare Securizată',
    'approveSecure': 'Aprobă Secur',

    'searchObject': 'Caută obiect/comandă',
    'allCommands': 'Toate comenzile',
    'onlyUrgent': 'Doar urgente',
    'onlyNonUrgent': 'Doar non-urgente',
    'creator': 'Creator',
    'allCreators': 'Toți creatorii',
    'allObjects': 'Toate obiectele',
    'allMechanismTypes': 'Toate tipurile',
    'priority': 'Prioritate',
    'number': 'Nr.',
    'selectAll': 'Selectează toate ({count})',
    'deselectAll': 'Deselectează toate',
    'generatePdf': 'Generează PDF',
    'generatedPdf': 'PDF generat',
    'pdfError': 'Eroare la generarea PDF',
    'previewError': 'Eroare la previzualizare: {error}',
    'noOrdersSelected': 'Nu au fost selectate comenzi',
    'totalOrders': 'Total comenzi',
    'totalMechanisms': 'Total mecanisme',

    "searchMechanismOrder": "Caută mecanism/comandă",
    "pdf": "PDF",
    "generatedDocumentsInSinglePdf": "Generate {count} documente într-un singur PDF",
    "pdfGeneratedFor": "PDF generat pentru {name}",
    "pdfGenerationError": "Eroare la generarea PDF: {error}",
    "invalidOrderNoId": "Invalid order fara ID",

    'account': 'Cont',

    'initializing': 'Inițializare...',
    'checkingConnection': 'Verificare conexiune...',
    'noInternetConnection': 'Fără conexiune la internet',
    'redirecting': 'Redirecționare...',
    'checkingAuth': 'Verificare autentificare...',
    'emailNotVerified': 'Email neverificat',
    'loadingData': 'Încărcare date...',
    'missingData': 'Date lipsă',
    'welcome': 'Bun venit!',
    'connectionError': 'Eroare de conectare',

    'mfaRequired': 'Verificare MFA Necesară',
    'mfaDescription': 'Această operațiune necesită verificare multi-factor pentru securitate sporită.',
    'mfaInstructions': 'Apăsați "Verifică" pentru a confirma identitatea prin MFA.',
    'mfaVerificationFailed': 'Verificarea MFA a eșuat',
    'mfaVerified': 'MFA verificat cu succes',
    'codeOptions': 'Opțiuni Cod',
    'codeTooShort': 'Codul trebuie să aibă minim 6 caractere',
    'generate': 'Generează',

    // Modul Adăugare Date
    'dataEntry': 'Adăugare Date',
    'dataEntryPageTitle': 'Adăugare Date',
    'tabVehicle': 'Vehicul',
    'tabOperator': 'Operator / Notițe',

    // Fila 1 – Vehicul
    'vehicleClass': 'Clasă',
    'vehicleSubclass': 'Subclasă',
    'vehicleModel': 'Denumire Model',
    'vehicleTonnage': 'Tonaj / Mărime',
    'vehicleBase': 'Bază (Locație)',
    'formaDezvuire': 'Forma Dezvaluire',
    'locatieBaza': 'Locație Bază',
    'addVehicle': 'Adaugă Vehicul',
    'vehicleAddedSuccess': 'Vehiculul a fost adăugat cu succes',
    'vehicleDuplicateError': 'Vehiculul cu numărul {nr} deja există',
    'invalidPlateFormat': 'Format invalid (ex: AB-12-XYZ)',
    'lastAdded': 'Ultima Adăugare',
    'addedAt': 'Adăugat la',
    'networkError': 'Eroare de rețea',

    // Fila 2 – Operator
    'operatorTabDescription': 'Fiecare operator adăugat constituie un grup separat în baza de date.',
    'operatorName': 'Nume Operator',
    'operatorNote': 'Notiță',
    'addOperator': 'Adaugă Operator',
    'operatorAddedSuccess': 'Operatorul a fost adăugat cu succes',


    "statusLaBaza":         "La Bază",
    "statusInSantier":      "În Șantier",
    "statusLaReparatie":    "La Reparație",
    "noVehicles":           "Nu există vehicule.",
    "filter":               "Filtru",
    "filterVehicles":       "Filtrează tehnica",
    "applyFilter":          "Aplică filtrul",
    "class":                "Clasă",
    "subclass":             "Subclasă",
    "model":                "Model",
    "plate":                "Nr. Înmatriculare",
    "tonnage":              "Tonaj",
    "yearMade":             "An fabricație",
    "chassisSeries":        "Serie șasiu",
    "observations":         "Observații",
    "details":              "Detalii",
    "operators":            "Operatori",
    "technicalData":        "Date tehnice",
    "occupancyCalendar":    "Calendar ocupare",
    "addPeriod":            "Adaugă perioadă",
    "noPeriods":            "Nicio perioadă de ocupare.",
    "noOperators":          "Niciun operator asignat.",
    "occupancyPeriod":      "Perioadă de ocupare",
    "selectPeriod":         "Selectează intervalul",
    "editVehicle":          "Editează tehnica",
    "editData":             "Editează date",
    "confirmDelete":        "Confirmare ștergere",
    "deleteVehicleMsg":     "Ești sigur că vrei să ștergi",

    // santier_pdf_tab vehicle_pdf_tab
    "tehnica":              "Tehnică",
    "location":             "Locație",
    "base":                 "Bază",
    "createdBy":            "Creat de",
    "orders":               "Comenzi",
    "startDate":            "Data început",

    // home_page
    'santiere':             'Șantiere',
    'options':              'Opțiuni',
    'changeName':           'Schimbă numele',
    'userName':             'Nume utilizator',
    'enterName':            'Introduceți numele...',

    // santier_detail_page
    'santierNotFound':      'Șantierul nu a fost găsit.',
    'newComanda':           'Comandă nouă',
    'editSantier':          'Editează șantier',
    'eroare':               'Eroare',
    'noComandaSantier':     'Nicio comandă pentru acest șantier.',
    'editComanda':          'Editează comanda',
    'start':                'Start',
    'end':                  'Final',
    'createdAt':            'Creat la',
    'motivRespingere':      'Motiv respingere',
    'dateUnspecified':      'Dată nespecificată',
    'activ':                'Activ',
    'planificat':           'Planificat',
    'asteptare':            'Așteptare',

    // vehicle_pdf_tab
    'noVehiclesFound':      'Niciun vehicul găsit.',
    'searchVehicleHint':    'Caută model / nr. înmatriculare...',
    'perioadeActive':       'Perioade active',
    'reset':                'Resetează',

    // comanda_form_sheet
    'deleteComandaTitle':   'Șterge comanda?',
    'deleteComandaContent': 'Comanda va fi ștearsă și intervalul eliberat.',
    'dateTimeStart':        'Data + Ora start',
    'dateTimeEnd':          'Data + Ora final',
    'occupied':             'Ocupat',
    'available':            'Disponibil',

    // occupancy_calendar
    'noExactTime':          'Fără oră exactă',
    'reservations':         'Rezervări',
    'dayShort':             'Zi',
    'inAsteptare':          'În așteptare',
    'aprobat':              'Aprobat',
    'santierFallback':      'Șantier',
    'jan': 'Ianuarie', 'feb': 'Februarie', 'mar': 'Martie',
    'apr': 'Aprilie',  'may': 'Mai',       'jun': 'Iunie',
    'jul': 'Iulie',    'aug': 'August',    'sep': 'Septembrie',
    'oct': 'Octombrie','nov': 'Noiembrie', 'dec': 'Decembrie',

    // santier_pdf_tab
    'filterPdf':            'Filtru PDF',
    'perioadaCreare':       'Perioadă creare',
    'vehicule':             'Vehicule',
    'oriceData':            'Orice dată',
    'statusActiv':          'Activ',
    'statusSuspendat':      'Suspendat',
    'statusArhivat':        'Arhivat',

    // rezervare_service / comanda_service
    'vehicleNotFound':        'Vehiculul nu mai există în baza de date.',
    'intervalSuprapus':       'Interval suprapus',
    'searchVehicle':          'Caută vehicul',
    'selectVehicle':          'Selectează vehiculul',
    'noVehicleSelected':      'Niciun vehicul selectat',
    'comandaCreated':         'Comanda a fost creată cu succes.',
    'comandaDeleted':         'Comanda a fost ștearsă.',
    'comandaIntervalUpdated': 'Intervalul comenzii a fost actualizat.',
    'overlapError':           'Vehiculul este deja rezervat în acest interval.',
    'statusPending':          'În așteptare',
    'statusAprobat':          'Aprobat',
    'statusRespins':          'Respins',

    // santier_service
    'createSantier':    'Crează Șantier',
    'santierCreated':   'Șantierul a fost creat cu succes.',
    'santierUpdated':   'Șantierul a fost actualizat.',
    'denumire':         'Denumire',
    'locatie':          'Locație',
    'dataIncepere':     'Data începere',
    'dataFinalizare':   'Data finalizare',
    'colorSantier':     'Culoare șantier',

    // santiere_list_page
    'santiereActivi':      'Activi',
    'santiereSuspendati':  'Suspendați',
    'santiereArhivati':    'Arhivați',
    'noSantiere':          'Nu există șantiere.',
    'santierNou':          'Șantier nou',
    'loadError':           'Eroare la încărcare',
    'dateFinalizareError': 'Data finalizare trebuie să fie >= data începere.',
    'timeoutError':        'Timeout — verificați conexiunea și încercați din nou.',
    'noEditPermission':    'Nu ai permisiunea de a edita acest șantier.',
    'filtruSantiere':      'Filtru șantiere',
    'minThreeChars':       'Minim 3 caractere.',
    'creaza':              'Creează',

    // comanda_form_sheet
    'selectMecanism':          'Selectați un mecanism din lista de sugestii.',
    'selectDateTimeStartEnd':  'Selectați data+ora de start și final.',
    'finalAfterStart':         'Data final trebuie să fie după data start.',
    'comandaActualizata':      'Comanda a fost actualizată.',
    'comandaTrimisaAprobare':  'Comanda a fost trimisă spre aprobare.',
    'intervalSuprapusCu':      'Interval suprapus cu rezervarea existentă:',
    'rezervatDe':              'Rezervat de',
    'deleteError':             'Eroare la ștergere',
    'mechanismHint':           'Mecanism (tastați minim 2 caractere)',
    'selectMechanismFromList': 'Selectați un mecanism din listă.',
    'mechanismNotFound':       'Mecanismul nu a fost găsit în baza de date.',
    'calendarLabel':           'Calendar',
    'noteOptional':            'Note (opțional)',
    'actualizeaza':            'Actualizează',
    'trimiteSpreAprobare':     'Trimite spre aprobare',
    'selectDateAndTime':       'Selectați data și ora',
  };

  static final Map<String, String> _ruLocalizedStrings = {
    'simpleUser': 'Простой Пользователь',
    'operator': 'Оператор',
    'admin': 'Администратор',
    'appTitle': 'Система Заказов',
    'login': 'Авторизация',
    'logout': 'Выйти',
    'settings': 'Настройки',
    'save': 'Сохранить',
    'cancel': 'Отмена',
    'close': 'Закрыть',
    'theme': 'Тема',
    'language': 'Язык',
    'lightMode': 'Светлый режим',
    'darkMode': 'Тёмный режим',
    'myOrders': 'Мои Заказы',
    'allOrders': 'Все Заказы',
    'approval': 'Утверждение',
    'statistics': 'Статистика',
    'newOrder': 'Новый Заказ',
    'licensePlate': 'Номерной Знак',
    'object': 'Объект',
    'date': 'Дата',
    'time': 'Время',
    'notes': 'Заметки',
    'urgent': 'Срочно',
    'pending': 'В Ожидании',
    'approved': 'Одобрено',
    'completed': 'Завершено',
    'rejected': 'Отклонено',
    'search': 'Поиск',
    'filters': 'Фильтры',
    'advancedFilters': 'Расширенные Фильтры',
    'fromDate': 'С даты',
    'toDate': 'По дату',
    'fromTime': 'С времени',
    'toTime': 'До времени',
    'username': 'Пользователь',
    'user': 'Пользователь',
    'all': 'Все',
    'clearFilters': 'Очистить Фильтры',
    'mechanismType': 'Тип Механизма',
    'units': 'Единицы',
    'addMechanism': 'Добавить Механизм',
    'photos': 'Фотографии',
    'addPhoto': 'Добавить Фото',
    'takePicture': 'Сделать Фото',
    'orderDetails': 'Детали Заказа',
    'editOrder': 'Редактировать Заказ',
    'addOrder': 'Добавить Заказ',
    'delete': 'Удалить',
    'confirm': 'Подтвердить',
    'requiredField': 'Обязательное поле',
    'invalidFormat': 'Неверный формат',
    'allStatus': 'Все Статусы',
    'hours': 'часы',

    // Settings
    'romanian': 'Румынский',
    'russian': 'Русский',

    // Admin panel
    'adminPanel': 'Панель Администратора',
    'generateInviteCode': 'Сгенерировать Код Приглашения',
    'inviteCode': 'Код Приглашения',
    'expires': 'Истекает',
    'generateWithTOTP': 'Сгенерировать с TOTP',
    'copyCode': 'Скопировать Код',
    'totpVerification': 'Проверка TOTP',
    'enterTOTP': 'Введите код из Google Authenticator',
    'expectedCode': 'Ожидаемый код (ДЕМО)',
    'totpCode': 'Код TOTP',
    'verify': 'Проверить',
    'generatingCode': 'Генерация кода...',

    // Mechanism types
    'engine': 'Двигатель',
    'pump': 'Насос',
    'transmission': 'Трансмиссия',

    // Success messages
    'invalidTOTP': 'Неверный код TOTP!',
    'inviteCodeGenerated': 'Код приглашения успешно сгенерирован!',
    'codeCopied': 'Код скопирован в буфер обмена!',
    'orderAdded': 'Заказ успешно добавлен!',
    'statusUpdated': 'Статус обновлен!',
    'orderUpdated': 'Заказ обновлен!',

    'generateInviteCodeDescription': 'Генерируйте код, чтобы позволить другим людям зарегистрироваться в приложении.',
    'userStatistics': 'Статистика Пользователей',

    'pendingOrdersCount': 'заказов в ожидании',
    'approveRejectOrders': 'Одобрите или отклоните заказы',
    'noPendingOrders': 'Нет заказов в ожидании',

    'nucomenzi': 'Заказы не найдены.',

    'generalStatistics': 'Общая Статистика',
    'orderStatusDistribution': 'Распределение Статусов Заказов',

    'pdfTab': 'PDF',
    'status': 'Статус',
    'dateRange': 'Диапазон дат',
    'selectDateRange': 'Выберите диапазон',
    'generateAllPdfs': 'Сгенерировать все PDF',
    'noMatchingOrders': 'Нет подходящих заказов',
    'mechanisms': 'Механизмы',
    'previewPdf': 'Предпросмотр PDF',
    'downloadPdf': 'Скачать PDF',

    //approval_card
    'rejectOrder': 'Отклонить заказ',
    'confirmRejectOrder': 'Вы уверены, что хотите отклонить заказ?',
    'reject': 'Отклонить',
    'approve': 'Одобрить',
    'workHours': 'Рабочие часы',

    //approval_form
    'fillAllFields': 'Заполните все обязательные поля для всех механизмов',
    'fillMechanismData': 'Заполните данные механизмов',
    'selectTime': 'Выберите время',
    'peregon': 'Перегон',
    'yes': 'ДА',
    'no': 'НЕТ',

    //filters_card
    'searchHint': 'Поиск по объекту, заметкам или типу механизма...',
    'selectDate': 'Выберите дату',

    //order_card
    'noMechanisms': 'Без механизмов',
    'mechanismsShort': 'механизм',
    'more': 'еще',

    //orde_form_bottom_sheet
    'objectExample': 'напр: Яблоневый сад',
    'enterObjectName': 'Введите название объекта',
    'photosOptional': 'Фотографии (опционально)',
    'photo': 'Фото',
    'mechanismTypes': 'Типы механизмов',
    'mechTypeHint': 'напр: Двигатель, Трансмиссия',
    'selectHours': 'Выберите часы',
    'edit': 'Редактировать',
    'urgentOrderSubtitle': 'Показать заказ как приоритетный',
    'optional': 'опционально',

    'fillTypeUnitsHours': 'Заполните тип, количество единиц и часы',
    'unitsGreaterThanZero': 'Количество единиц должно быть больше 0',
    'hoursGreaterThanZero': 'Количество часов должно быть больше 0',
    'addAtLeastOneMechanism': 'Необходимо добавить хотя бы один тип механизма',

    'chooseSource': 'Выберите источник',
    'scanDocument': 'Сканировать документ',
    'detectEdges': 'Обнаружение краев (PDF/Фото)',
    'pickGallery': 'Выбрать из галереи',
    'noteHint': 'напр: важное примечание!',
    'addMechanismOrPhotoError': 'Добавьте хотя бы один механизм ИЛИ фото!',
    'fillRequiredFields': 'Пожалуйста, заполните обязательные поля!',
    'urgentOrder': 'Срочный заказ',
    'invalidMinutes': 'Минуты должны быть от 00 до 59!',

    'secureApproval': 'Безопасное одобрение',
    'approveSecure': 'Одобрить Безопасный',

    'searchObject': 'Поиск объекта/заказа',
    'allCommands': 'Все заказы',
    'onlyUrgent': 'Только срочные',
    'onlyNonUrgent': 'Только несрочные',
    'creator': 'Создатель',
    'allCreators': 'Все создатели',
    'allObjects': 'Все объекты',
    'allMechanismTypes': 'Все типы',
    'priority': 'Приоритет',
    'number': '№',
    'selectAll': 'Выбрать все ({count})',
    'deselectAll': 'Снять выделение',
    'generatePdf': 'Сгенерировать PDF',
    'generatedPdf': 'PDF сгенерирован',
    'pdfError': 'Ошибка генерации PDF',
    'previewError': 'Ошибка предпросмотра: {error}',
    'noOrdersSelected': 'Не выбраны заказы',
    'totalOrders': 'Всего заказов',
    'totalMechanisms': 'Всего механизмов',

    "searchMechanismOrder": "Поиск механизма/заказа",
    "pdf": "PDF",
    "generatedDocumentsInSinglePdf": "Создано {count} документов в одном PDF",
    "pdfGeneratedFor": "PDF создан для {name}",
    "pdfGenerationError": "Ошибка генерации PDF: {error}",
    "invalidOrderNoId": "Недействительный заказ без ID",

    'account': 'Аккаунт',

    'initializing': 'Инициализация...',
    'checkingConnection': 'Проверка соединения...',
    'noInternetConnection': 'Нет подключения к интернету',
    'redirecting': 'Переадресация...',
    'checkingAuth': 'Проверка авторизации...',
    'emailNotVerified': 'Email не подтвержден',
    'loadingData': 'Загрузка данных...',
    'missingData': 'Данные отсутствуют',
    'welcome': 'Добро пожаловать!',
    'connectionError': 'Ошибка подключения',

    'mfaRequired': 'MFA Verification Required',
    'mfaDescription': 'This operation requires multi-factor verification for enhanced security.',
    'mfaInstructions': 'Press "Verify" to confirm your identity through MFA.',
    'mfaVerificationFailed': 'MFA verification failed',
    'mfaVerified': 'MFA verified successfully',
    'codeOptions': 'Code Options',
    'codeTooShort': 'Code must be at least 6 characters',
    'generate': 'Generate',

    // Modul Adăugare Date
    'dataEntry': 'Добавление Данных',
    'dataEntryPageTitle': 'Добавление Данных',
    'tabVehicle': 'Транспорт',
    'tabOperator': 'Оператор / Заметки',

    // Fila 1 – Vehicul
    'vehicleClass': 'Класс',
    'vehicleSubclass': 'Подкласс',
    'vehicleModel': 'Название Модели',
    'vehicleTonnage': 'Тоннаж / Размер',
    'vehicleBase': 'База (Местоположение)',
    'formaDezvuire': 'Форма Раскрытия',
    'locatieBaza': 'Местоположение Базы',
    'addVehicle': 'Добавить Транспорт',
    'vehicleAddedSuccess': 'Транспортное средство успешно добавлено',
    'vehicleDuplicateError': 'Транспортное средство с номером {nr} уже существует',
    'invalidPlateFormat': 'Неверный формат (напр: AB-12-XYZ)',
    'lastAdded': 'Последнее Добавление',
    'addedAt': 'Добавлено в',
    'networkError': 'Ошибка сети',

    // Fila 2 – Operator
    'operatorTabDescription': 'Каждый добавленный оператор составляет отдельную группу в базе данных.',
    'operatorName': 'Имя Оператора',
    'operatorNote': 'Заметка',
    'addOperator': 'Добавить Оператора',
    'operatorAddedSuccess': 'Оператор успешно добавлен',

    //Vehicule / Tehnică
    "statusLaBaza":         "На Базе",
    "statusInSantier":      "На Стройке",
    "statusLaReparatie":    "На Ремонте",
    "noVehicles":           "Транспортных средств нет.",
    "filter":               "Фильтр",
    "filterVehicles":       "Фильтр техники",
    "applyFilter":          "Применить фильтр",
    "class":                "Класс",
    "subclass":             "Подкласс",
    "model":                "Модель",
    "plate":                "Гос. номер",
    "tonnage":              "Тоннаж",
    "yearMade":             "Год выпуска",
    "chassisSeries":        "Серия шасси",
    "observations":         "Наблюдения",
    "details":              "Детали",
    "operators":            "Операторы",
    "technicalData":        "Технические данные",
    "occupancyCalendar":    "Календарь занятости",
    "addPeriod":            "Добавить период",
    "noPeriods":            "Нет периодов занятости.",
    "noOperators":          "Операторы не назначены.",
    "occupancyPeriod":      "Период занятости",
    "selectPeriod":         "Выберите интервал",
    "editVehicle":          "Редактировать технику",
    "editData":             "Редактировать данные",
    "confirmDelete":        "Подтверждение удаления",
    "deleteVehicleMsg":     "Вы уверены, что хотите удалить",

    // santier_pdf_tab vehicle_pdf_tab
    "tehnica":              "Техника",
    "location":             "Местоположение",
    "base":                 "База",
    "createdBy":            "Создан",
    "orders":               "Заказы",
    "startDate":            "Дата начала",

    // home_page
    'santiere':             'Стройки',
    'options':              'Опции',
    'changeName':           'Изменить имя',
    'userName':             'Имя пользователя',
    'enterName':            'Введите имя...',

    // santier_detail_page
    'santierNotFound':      'Стройка не найдена.',
    'newComanda':           'Новый заказ',
    'editSantier':          'Редактировать стройку',
    'eroare':               'Ошибка',
    'noComandaSantier':     'Нет заказов для этой стройки.',
    'editComanda':          'Редактировать заказ',
    'start':                'Начало',
    'end':                  'Конец',
    'createdAt':            'Создано',
    'motivRespingere':      'Причина отклонения',
    'dateUnspecified':      'Дата не указана',
    'activ':                'Активный',
    'planificat':           'Запланировано',
    'asteptare':            'В ожидании',

    // vehicle_pdf_tab
    'noVehiclesFound':      'Транспортных средств не найдено.',
    'searchVehicleHint':    'Поиск по модели / гос. номеру...',
    'perioadeActive':       'Активные периоды',
    'reset':                'Сбросить',

    // comanda_form_sheet
    'deleteComandaTitle':   'Удалить заказ?',
    'deleteComandaContent': 'Заказ будет удалён и интервал освобождён.',
    'dateTimeStart':        'Дата + Время начала',
    'dateTimeEnd':          'Дата + Время конца',
    'occupied':             'Занято',
    'available':            'Доступно',

    // occupancy_calendar
    'noExactTime':          'Без точного времени',
    'reservations':         'Резервации',
    'dayShort':             'День',
    'inAsteptare':          'В ожидании',
    'aprobat':              'Одобрен',
    'santierFallback':      'Стройка',
    'jan': 'Январь',   'feb': 'Февраль',  'mar': 'Март',
    'apr': 'Апрель',   'may': 'Май',      'jun': 'Июнь',
    'jul': 'Июль',     'aug': 'Август',   'sep': 'Сентябрь',
    'oct': 'Октябрь',  'nov': 'Ноябрь',   'dec': 'Декабрь',

    // santier_pdf_tab
    'filterPdf':            'Фильтр PDF',
    'perioadaCreare':       'Период создания',
    'vehicule':             'Транспорт',
    'oriceData':            'Любая дата',
    'statusActiv':          'Активный',
    'statusSuspendat':      'Приостановлен',
    'statusArhivat':        'Архивирован',

    // rezervare_service / comanda_service
    'vehicleNotFound':        'Транспортное средство больше не существует в базе данных.',
    'intervalSuprapus':       'Перекрывающийся интервал',
    'searchVehicle':          'Поиск транспорта',
    'selectVehicle':          'Выберите транспорт',
    'noVehicleSelected':      'Транспорт не выбран',
    'comandaCreated':         'Заказ успешно создан.',
    'comandaDeleted':         'Заказ удалён.',
    'comandaIntervalUpdated': 'Интервал заказа обновлён.',
    'overlapError':           'Транспорт уже забронирован в этом интервале.',
    'statusPending':          'В ожидании',
    'statusAprobat':          'Одобрен',
    'statusRespins':          'Отклонён',

    // santier_service
    'createSantier':    'Создать Стройку',
    'santierCreated':   'Стройка успешно создана.',
    'santierUpdated':   'Стройка обновлена.',
    'denumire':         'Наименование',
    'locatie':          'Местоположение',
    'dataIncepere':     'Дата начала',
    'dataFinalizare':   'Дата завершения',
    'colorSantier':     'Цвет стройки',

    // santiere_list_page
    'santiereActivi':      'Активные',
    'santiereSuspendati':  'Приостановленные',
    'santiereArhivati':    'Архивированные',
    'noSantiere':          'Нет строек.',
    'santierNou':          'Новая стройка',
    'loadError':           'Ошибка загрузки',
    'dateFinalizareError': 'Дата завершения должна быть >= даты начала.',
    'timeoutError':        'Тайм-аут — проверьте соединение и попробуйте снова.',
    'noEditPermission':    'У вас нет прав на редактирование этой стройки.',
    'filtruSantiere':      'Фильтр строек',
    'minThreeChars':       'Минимум 3 символа.',
    'creaza':              'Создать',

    // comanda_form_sheet
    'selectMecanism':          'Выберите механизм из списка подсказок.',
    'selectDateTimeStartEnd':  'Выберите дату+время начала и конца.',
    'finalAfterStart':         'Дата конца должна быть после даты начала.',
    'comandaActualizata':      'Заказ обновлён.',
    'comandaTrimisaAprobare':  'Заказ отправлен на согласование.',
    'intervalSuprapusCu':      'Пересечение с существующей резервацией:',
    'rezervatDe':              'Забронировано',
    'deleteError':             'Ошибка удаления',
    'mechanismHint':           'Механизм (введите минимум 2 символа)',
    'selectMechanismFromList': 'Выберите механизм из списка.',
    'mechanismNotFound':       'Механизм не найден в базе данных.',
    'calendarLabel':           'Календарь',
    'noteOptional':            'Заметка (опционально)',
    'actualizeaza':            'Обновить',
    'trimiteSpreAprobare':     'Отправить на согласование',
    'selectDateAndTime':       'Выберите дату и время',
  };
}