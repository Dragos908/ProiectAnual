import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './app_localizations.dart';

class AppSettings with ChangeNotifier {
  // ==================== CONFIGURARE ====================

  static const ThemeMode _defaultThemeMode = ThemeMode.light;
  static const Locale _defaultLocale = Locale('ro', 'RO');

  static const List<Locale> supportedLocales = [
    Locale('ro', 'RO'),
    Locale('ru', 'RU'),
  ];

  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLocale = 'locale';
  static const String _themeDark = 'dark';
  static const String _localeDelimiter = '_';

  // ==================== STARE ====================

  ThemeMode _themeMode = _defaultThemeMode;
  Locale _locale = _defaultLocale;
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // ==================== INIȚIALIZARE ====================

  AppSettings() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  Future<void> ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ==================== ÎNCĂRCARE SETĂRI ====================

  Future<void> _loadSettings() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final savedTheme = prefs.getString(_keyThemeMode);
    final savedLocale = prefs.getString(_keyLocale);

    _themeMode = savedTheme == _themeDark ? ThemeMode.dark : _defaultThemeMode;
    _locale = _parseLocale(savedLocale);
    notifyListeners();
  }

  Locale _parseLocale(String? savedLocale) {
    if (savedLocale == null || !savedLocale.contains(_localeDelimiter)) {
      return _defaultLocale;
    }

    final parts = savedLocale.split(_localeDelimiter);
    if (parts.length != 2) return _defaultLocale;

    final locale = Locale(parts[0], parts[1]);
    return supportedLocales.contains(locale) ? locale : _defaultLocale;
  }

  // ==================== SALVARE SETĂRI (OPTIMIZAT) ====================

  Future<void> _saveSetting(String key, String? value, bool isDefault) async {
    final prefs = _prefs;
    if (prefs == null) return;

    if (isDefault) {
      await prefs.remove(key);
    } else if (value != null) {
      await prefs.setString(key, value);
    }
  }

  // ==================== SETĂRI PUBLICE ====================

  void setThemeMode(ThemeMode themeMode) {
    if (_themeMode == themeMode) return;
    _themeMode = themeMode;
    notifyListeners();
    _saveSetting(
      _keyThemeMode,
      themeMode == ThemeMode.dark ? _themeDark : null,
      themeMode == _defaultThemeMode,
    );
  }

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    _saveSetting(
      _keyLocale,
      '${locale.languageCode}$_localeDelimiter${locale.countryCode}',
      locale == _defaultLocale,
    );
  }

  void toggleTheme() {
    setThemeMode(_themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  // ==================== DIALOG ====================

  static void showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _SettingsDialogContent(),
    );
  }
}

// ==================== CONSTANTE UI ====================

class _UIConstants {
  static const borderRadius = BorderRadius.all(Radius.circular(16));
  static const dialogRadius = BorderRadius.all(Radius.circular(24));
  static const iconSize = 28.0;
  static const horizontalPadding = 20.0;
  static const verticalPadding = 20.0;
  static const spacing = 8.0;
  static const sectionSpacing = 12.0;
  static const dividerHeight = 40.0;
  static const headerBottomSpace = 32.0;
  static const bottomSpace = 24.0;
}

// ==================== UI DIALOG ====================

class _SettingsDialogContent extends StatelessWidget {
  const _SettingsDialogContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: _UIConstants.dialogRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogHeader(l: l),
              const SizedBox(height: _UIConstants.headerBottomSpace),
              _ThemeSection(l: l),
              const Divider(height: _UIConstants.dividerHeight, color: Colors.black12),
              _LanguageSection(l: l),
              const SizedBox(height: _UIConstants.bottomSpace),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== HEADER ====================

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l.settings,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.close,
            color: theme.colorScheme.onSurfaceVariant,
            size: 24,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ],
    );
  }
}

// ==================== SECȚIUNE TEMĂ ====================

class _ThemeSection extends StatelessWidget {
  const _ThemeSection({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection<ThemeMode>(
      title: l.theme,
      options: [
        _OptionData(Icons.wb_sunny_outlined, l.lightMode, ThemeMode.light),
        _OptionData(Icons.nightlight_outlined, l.darkMode, ThemeMode.dark),
      ],
      selector: (settings) => settings.themeMode,
      onChanged: (settings, value) => settings.setThemeMode(value),
    );
  }
}

// ==================== SECȚIUNE LIMBĂ ====================

class _LanguageSection extends StatelessWidget {
  const _LanguageSection({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection<Locale>(
      title: l.language,
      options: AppSettings.supportedLocales
          .map((locale) => _OptionData(
        Icons.language_outlined,
        _getLanguageName(locale, l),
        locale,
      ))
          .toList(),
      selector: (settings) => settings.locale,
      onChanged: (settings, value) => settings.setLocale(value),
    );
  }

  static String _getLanguageName(Locale locale, AppLocalizations l) {
    switch (locale.languageCode) {
      case 'ro':
        return l.translate('romanian');
      case 'ru':
        return l.translate('russian');
      default:
        return locale.languageCode.toUpperCase();
    }
  }
}

// ==================== DATE OPȚIUNE ====================

class _OptionData<T> {
  const _OptionData(this.icon, this.title, this.value);

  final IconData icon;
  final String title;
  final T value;
}

// ==================== SECȚIUNE GENERICĂ (ELIMINĂ DUPLICARE) ====================

class _SettingsSection<T> extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.options,
    required this.selector,
    required this.onChanged,
  });

  final String title;
  final List<_OptionData<T>> options;
  final T Function(AppSettings) selector;
  final void Function(AppSettings, T) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title),
        const SizedBox(height: _UIConstants.sectionSpacing),
        Consumer<AppSettings>(
          builder: (context, settings, _) {
            final currentValue = selector(settings);
            return Column(
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  _OptionCard<T>(
                    icon: options[i].icon,
                    title: options[i].title,
                    value: options[i].value,
                    groupValue: currentValue,
                    onChanged: (value) => onChanged(settings, value),
                  ),
                  if (i < options.length - 1)
                    const SizedBox(height: _UIConstants.spacing),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

// ==================== SECTION HEADER ====================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ==================== OPTION CARD ====================

class _OptionCard<T> extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Culori calculate o singură dată
    final activeTextColor = isDark ? const Color(0xFF0D47A1) : Colors.white;
    final bgColor = isSelected ? colorScheme.primary : Colors.transparent;
    final borderColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withOpacity(0.3);
    final textColor = isSelected ? activeTextColor : colorScheme.onSurface;
    final iconColor = isSelected ? activeTextColor : colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: _UIConstants.borderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _UIConstants.horizontalPadding,
            vertical: _UIConstants.verticalPadding,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: _UIConstants.borderRadius,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, size: _UIConstants.iconSize, color: iconColor),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, size: _UIConstants.iconSize, color: activeTextColor),
            ],
          ),
        ),
      ),
    );
  }
}