import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './app_localizations.dart';

class AppSettings with ChangeNotifier {
  static const ThemeMode _defaultThemeMode = ThemeMode.light;
  static const Locale    _defaultLocale    = Locale('ro', 'RO');

  static const List<Locale> supportedLocales = [
    Locale('ro', 'RO'),
    Locale('ru', 'RU'),
  ];

  static const String _keyThemeMode    = 'theme_mode';
  static const String _keyLocale       = 'locale';
  static const String _localeDelimiter = '_';

  ThemeMode _themeMode = _defaultThemeMode;
  Locale    _locale    = _defaultLocale;
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  Locale    get locale    => _locale;
  bool      get isDarkMode => _themeMode == ThemeMode.dark;

  AppSettings() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  Future<void> ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  void _loadSettings() {
    final prefs = _prefs;
    if (prefs == null) return;

    final savedTheme  = prefs.getString(_keyThemeMode);
    final savedLocale = prefs.getString(_keyLocale);

    _themeMode = savedTheme == 'dark' ? ThemeMode.dark : _defaultThemeMode;
    _locale    = _parseLocale(savedLocale);
    notifyListeners();
  }

  Locale _parseLocale(String? saved) {
    if (saved == null || !saved.contains(_localeDelimiter)) return _defaultLocale;
    final parts = saved.split(_localeDelimiter);
    if (parts.length != 2) return _defaultLocale;
    final locale = Locale(parts[0], parts[1]);
    return supportedLocales.contains(locale) ? locale : _defaultLocale;
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _save(_keyThemeMode, mode == ThemeMode.dark ? 'dark' : null, mode == _defaultThemeMode);
  }

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    _save(
      _keyLocale,
      '${locale.languageCode}$_localeDelimiter${locale.countryCode}',
      locale == _defaultLocale,
    );
  }

  void toggleTheme() =>
      setThemeMode(_themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);

  Future<void> _save(String key, String? value, bool isDefault) async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (isDefault) {
      await prefs.remove(key);
    } else if (value != null) {
      await prefs.setString(key, value);
    }
  }

  static void showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _SettingsDialog(),
    );
  }
}

//UI Constants
class _UI {
  static const radius       = BorderRadius.all(Radius.circular(16));
  static const dialogRadius = BorderRadius.all(Radius.circular(24));
  static const iconSize     = 28.0;
  static const hPad         = 20.0;
  static const vPad         = 20.0;
  static const spacing      = 8.0;
  static const sectionGap   = 12.0;
}

//Dialog
class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: _UI.dialogRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogHeader(l: l),
              const SizedBox(height: 32),
              _ThemeSection(l: l),
              const Divider(height: 40, color: Colors.black12),
              _LanguageSection(l: l),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final AppLocalizations l;
  const _DialogHeader({required this.l});

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
          icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ],
    );
  }
}

class _ThemeSection extends StatelessWidget {
  final AppLocalizations l;
  const _ThemeSection({required this.l});

  @override
  Widget build(BuildContext context) => _SettingsSection<ThemeMode>(
    title: l.theme,
    options: [
      _Option(Icons.wb_sunny_outlined,    l.lightMode, ThemeMode.light),
      _Option(Icons.nightlight_outlined,  l.darkMode,  ThemeMode.dark),
    ],
    selector:  (s) => s.themeMode,
    onChanged: (s, v) => s.setThemeMode(v),
  );
}

class _LanguageSection extends StatelessWidget {
  final AppLocalizations l;
  const _LanguageSection({required this.l});

  @override
  Widget build(BuildContext context) => _SettingsSection<Locale>(
    title: l.language,
    options: AppSettings.supportedLocales
        .map((locale) => _Option(Icons.language_outlined, _langName(locale, l), locale))
        .toList(),
    selector:  (s) => s.locale,
    onChanged: (s, v) => s.setLocale(v),
  );

  static String _langName(Locale locale, AppLocalizations l) => switch (locale.languageCode) {
    'ro' => l.translate('romanian'),
    'ru' => l.translate('russian'),
    _    => locale.languageCode.toUpperCase(),
  };
}

class _Option<T> {
  const _Option(this.icon, this.title, this.value);
  final IconData icon;
  final String title;
  final T value;
}

class _SettingsSection<T> extends StatelessWidget {
  final String title;
  final List<_Option<T>> options;
  final T Function(AppSettings) selector;
  final void Function(AppSettings, T) onChanged;

  const _SettingsSection({
    required this.title,
    required this.options,
    required this.selector,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: _UI.sectionGap),
        Consumer<AppSettings>(
          builder: (context, settings, _) {
            final current = selector(settings);
            return Column(
              children: [
                for (int i = 0; i < options.length; i++) ...[
                  _OptionCard<T>(
                    icon:       options[i].icon,
                    title:      options[i].title,
                    value:      options[i].value,
                    groupValue: current,
                    onChanged:  (v) => onChanged(settings, v),
                  ),
                  if (i < options.length - 1) const SizedBox(height: _UI.spacing),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OptionCard<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected   = value == groupValue;
    final theme        = Theme.of(context);
    final isDark       = theme.brightness == Brightness.dark;
    final activeText   = isDark ? const Color(0xFF0D47A1) : Colors.white;
    final bgColor      = isSelected ? theme.colorScheme.primary : Colors.transparent;
    final borderColor  = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant.withOpacity(0.3);
    final textColor    = isSelected ? activeText : theme.colorScheme.onSurface;
    final iconColor    = isSelected ? activeText : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: _UI.radius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: _UI.hPad, vertical: _UI.vPad),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: _UI.radius,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, size: _UI.iconSize, color: iconColor),
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
              if (isSelected) Icon(Icons.check_circle, size: _UI.iconSize, color: activeText),
            ],
          ),
        ),
      ),
    );
  }
}