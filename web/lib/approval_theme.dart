import 'package:flutter/material.dart';

class ApprovalTheme {
  ApprovalTheme._();

  // CULORI - LIGHT MODE
  static const Color primaryAccentLight = Color(0xFF2196F3);
  static const Color successColorLight = Color(0xFF4CAF50);
  static const Color errorColorLight = Color(0xFFE53935);
  static const Color warningColorLight = Color(0xFFFF9800);

  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color borderColorLight = Color(0x33000000);
  static const Color dividerColorLight = Color(0x26000000);

  static const Color cardBackgroundLight = Colors.white;
  static const Color surfaceBackgroundLight = Color(0xFFFAFAFA);

  // CULORI - DARK MODE
  static const Color primaryAccentDark = Color(0xFF64B5F6);
  static const Color successColorDark = Color(0xFF66BB6A);
  static const Color errorColorDark = Color(0xFFEF5350);
  static const Color warningColorDark = Color(0xFFFFB74D);

  static const Color textPrimaryDark = Color(0xFFE0E0E0);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color borderColorDark = Color(0x33FFFFFF);
  static const Color dividerColorDark = Color(0x26FFFFFF);

  static const Color cardBackgroundDark = Color(0xFF1E1E1E);
  static const Color surfaceBackgroundDark = Color(0xFF121212);

  // GETTERI PENTRU CULORI DINAMICE
  static Color primaryAccent(BuildContext context) =>
      _isDark(context) ? primaryAccentDark : primaryAccentLight;

  static Color successColor(BuildContext context) =>
      _isDark(context) ? successColorDark : successColorLight;

  static Color errorColor(BuildContext context) =>
      _isDark(context) ? errorColorDark : errorColorLight;

  static Color warningColor(BuildContext context) =>
      _isDark(context) ? warningColorDark : warningColorLight;

  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? textSecondaryDark : textSecondaryLight;

  static Color borderColor(BuildContext context) =>
      _isDark(context) ? borderColorDark : borderColorLight;

  static Color dividerColor(BuildContext context) =>
      _isDark(context) ? dividerColorDark : dividerColorLight;

  static Color cardBackground(BuildContext context) =>
      _isDark(context) ? cardBackgroundDark : cardBackgroundLight;

  static Color surfaceBackground(BuildContext context) =>
      _isDark(context) ? surfaceBackgroundDark : surfaceBackgroundLight;

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // DIMENSIUNI
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;

  static const double paddingTiny = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 12.0;
  static const double paddingLarge = 16.0;

  static const double marginTiny = 4.0;
  static const double marginSmall = 6.0;
  static const double marginMedium = 8.0;
  static const double marginLarge = 12.0;

  static const double borderWidth = 1.0;
  static const double dividerWidth = 0.5;
  static const double cardElevation = 1.0;

  // TIPOGRAFIE
  static const double fontSizeTiny = 10.0;
  static const double fontSizeSmall = 11.0;
  static const double fontSizeBody = 13.0;
  static const double fontSizeTitle = 15.0;
  static const double fontSizeHeader = 14.0;

  static const FontWeight fontWeightNormal = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightBold = FontWeight.w600;

  // STILURI TEXT
  static TextStyle textTiny(BuildContext context) => TextStyle(
    fontSize: fontSizeTiny,
    color: textSecondary(context),
    fontWeight: fontWeightNormal,
  );

  static TextStyle textSmall(BuildContext context) => TextStyle(
    fontSize: fontSizeSmall,
    color: textSecondary(context),
    fontWeight: fontWeightNormal,
  );

  static TextStyle textBody(BuildContext context) => TextStyle(
    fontSize: fontSizeBody,
    color: textPrimary(context),
    fontWeight: fontWeightNormal,
  );

  static TextStyle textTitle(BuildContext context) => TextStyle(
    fontSize: fontSizeTitle,
    color: textPrimary(context),
    fontWeight: fontWeightNormal,
  );

  static TextStyle textHeader(BuildContext context) => TextStyle(
    fontSize: fontSizeHeader,
    color: textPrimary(context),
    fontWeight: fontWeightBold,
  );

  // BADGE-URI STATUS
  static BoxDecoration badgeDecoration(Color color) {
    return BoxDecoration(
      color: color.withAlpha(40),
      borderRadius: BorderRadius.circular(radiusSmall),
    );
  }

  static TextStyle badgeTextStyle(Color color) {
    return TextStyle(
      fontSize: fontSizeTiny,
      color: color,
      fontWeight: fontWeightBold,
    );
  }

  // CARD-URI
  static BoxDecoration cardDecoration(BuildContext context, {bool isSelected = false}) {
    return BoxDecoration(
      color: cardBackground(context),
      borderRadius: BorderRadius.circular(radiusMedium),
      border: Border.all(
        color: isSelected ? primaryAccent(context) : borderColor(context),
        width: isSelected ? 2 : borderWidth,
      ),
    );
  }

  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: paddingSmall,
    vertical: paddingSmall,
  );

  static const EdgeInsets cardMargin = EdgeInsets.only(bottom: marginSmall);

  // BUTOANE
  static ButtonStyle primaryButtonStyle(BuildContext context) => FilledButton.styleFrom(
    backgroundColor: successColor(context),
    padding: const EdgeInsets.symmetric(
      horizontal: paddingMedium,
      vertical: paddingMedium,
    ),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSmall),
    ),
  );

  static ButtonStyle secondaryButtonStyle(BuildContext context) => TextButton.styleFrom(
    foregroundColor: errorColor(context),
    padding: const EdgeInsets.symmetric(
      horizontal: paddingMedium,
      vertical: paddingMedium,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSmall),
    ),
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: fontSizeBody,
    fontWeight: fontWeightMedium,
  );

  // FORM FIELDS
  static InputDecoration inputDecoration(BuildContext context, String label, {bool isValid = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: textSmall(context),
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: paddingSmall,
        vertical: paddingSmall,
      ),
      counterText: '',
      isDense: true,
      suffixIcon: isValid
          ? Icon(Icons.check, color: successColor(context), size: 16)
          : null,
    );
  }

  // DIVIDER
  static Widget divider(BuildContext context) {
    return Container(
      height: dividerWidth,
      color: dividerColor(context),
    );
  }

  static Border topBorder(BuildContext context) {
    return Border(
      top: BorderSide(
        color: dividerColor(context),
        width: dividerWidth,
      ),
    );
  }

  // ANIMAȚII
  static const Duration animationDuration = Duration(milliseconds: 200);
  static const Curve animationCurve = Curves.easeInOut;
}