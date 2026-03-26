import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_settings.dart';
import 'app_localizations.dart';
import 'approval_theme.dart';
import 'models/user.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final appSettings = AppSettings();
  await appSettings.ensureInitialized();

  final currentUser = await User.loadGuest();

  runApp(MyApp(appSettings: appSettings, currentUser: currentUser));
}

class MyApp extends StatelessWidget {
  final AppSettings appSettings;
  final User currentUser;

  MyApp({super.key, AppSettings? appSettings, User? currentUser})
      : appSettings = appSettings ?? AppSettings(),
        currentUser = currentUser ?? User.guest();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appSettings,
      child: Consumer<AppSettings>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Sistem de comandă mecanizme',
            theme: ThemeData(
              colorScheme: ColorScheme.light(
                primary: ApprovalTheme.primaryAccentLight,
                secondary: ApprovalTheme.primaryAccentLight,
                primaryContainer: ApprovalTheme.primaryAccentLight.withAlpha(40),
                secondaryContainer: ApprovalTheme.primaryAccentLight.withAlpha(40),
                error: ApprovalTheme.errorColorLight,
                surface: ApprovalTheme.surfaceBackgroundLight,
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: ApprovalTheme.textPrimaryLight,
              ),
              scaffoldBackgroundColor: ApprovalTheme.surfaceBackgroundLight,
              cardColor: ApprovalTheme.cardBackgroundLight,
              dividerColor: ApprovalTheme.dividerColorLight,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.dark(
                primary: ApprovalTheme.primaryAccentDark,
                secondary: ApprovalTheme.primaryAccentDark,
                primaryContainer: ApprovalTheme.primaryAccentDark.withAlpha(40),
                secondaryContainer: ApprovalTheme.primaryAccentDark.withAlpha(40),
                error: ApprovalTheme.errorColorDark,
                surface: ApprovalTheme.surfaceBackgroundDark,
                onPrimary: Colors.black,
                onSecondary: Colors.black,
                onSurface: ApprovalTheme.textPrimaryDark,
              ),
              scaffoldBackgroundColor: ApprovalTheme.surfaceBackgroundDark,
              cardColor: ApprovalTheme.cardBackgroundDark,
              dividerColor: ApprovalTheme.dividerColorDark,
              useMaterial3: true,
            ),
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: const [
              Locale('ro', 'RO'),
              Locale('ru', 'RU'),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            debugShowCheckedModeBanner: false,
            home: HomePage(currentUser: currentUser),
          );
        },
      ),
    );
  }
}