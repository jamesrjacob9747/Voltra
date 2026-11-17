import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design/tokens.dart';

/// Fixed brand colours. Screens that are always navy (live session, impact, welcome) use these
/// directly; everything else reads [VoltraPalette] through `context.vc` so it follows the theme.
class VoltraColors {
  static const navy = Color(0xFF0E1A2B);
  static const navyRaised = Color(0xFF17283E);
  static const onNavySoft = Color(0xFFB8C4D0);
  static const green = Color(0xFF2FD27F);
  static const darkGreen = Color(0xFF0B7A45);
  static const amber = Color(0xFFB57A00);
  static const grey = Color(0xFF6B7480);
  static const background = Color(0xFFF5F6F1);
  static const card = Color(0xFFFCFCFA);
  static const border = Color(0xFFDDE1DA);
  static const ink = Color(0xFF1C2633);
  static const muted = Color(0xFF4A5563);
}

/// Theme-aware colours that Material's [ColorScheme] has no slot for.
@immutable
class VoltraPalette extends ThemeExtension<VoltraPalette> {
  const VoltraPalette({
    required this.brand,
    required this.onBrand,
    required this.brandTint,
    required this.success,
    required this.warning,
    required this.warningTint,
    required this.danger,
    required this.info,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.background,
    required this.card,
    required this.raised,
    required this.border,
    required this.skeleton,
    required this.skeletonShine,
  });

  /// Main action colour: buttons, selected states, links.
  final Color brand;
  final Color onBrand;

  /// Soft brand wash for highlighted cards and chips.
  final Color brandTint;
  final Color success;
  final Color warning;
  final Color warningTint;
  final Color danger;

  /// "You are here" and neutral informational accents.
  final Color info;

  /// Primary, secondary and tertiary text.
  final Color ink;
  final Color muted;
  final Color faint;
  final Color background;
  final Color card;

  /// A surface one step above [card]: sheets, tiles inside cards.
  final Color raised;
  final Color border;
  final Color skeleton;
  final Color skeletonShine;

  static const light = VoltraPalette(
    brand: VoltraColors.darkGreen,
    onBrand: Colors.white,
    brandTint: Color(0xFFE3F4EA),
    success: VoltraColors.darkGreen,
    warning: VoltraColors.amber,
    warningTint: Color(0xFFFBF1DA),
    danger: Color(0xFFB3261E),
    info: Color(0xFF2F6FED),
    ink: VoltraColors.ink,
    muted: VoltraColors.muted,
    faint: Color(0xFF8A93A0),
    background: VoltraColors.background,
    card: Colors.white,
    raised: Color(0xFFF0F2EC),
    border: VoltraColors.border,
    skeleton: Color(0xFFE6E9E2),
    skeletonShine: Color(0xFFF6F7F3),
  );

  static const dark = VoltraPalette(
    brand: VoltraColors.green,
    onBrand: Color(0xFF04210F),
    brandTint: Color(0xFF12331F),
    success: VoltraColors.green,
    warning: Color(0xFFE8C547),
    warningTint: Color(0xFF3A2F0E),
    danger: Color(0xFFFF8A80),
    info: Color(0xFF7AA7FF),
    ink: Color(0xFFF1F4F8),
    muted: VoltraColors.onNavySoft,
    faint: Color(0xFF8391A3),
    background: Color(0xFF0A131F),
    card: Color(0xFF121E2E),
    raised: Color(0xFF1A2A3F),
    border: Color(0xFF26364A),
    skeleton: Color(0xFF1A2A3F),
    skeletonShine: Color(0xFF26384F),
  );

  @override
  VoltraPalette copyWith() => this;

  @override
  VoltraPalette lerp(VoltraPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return VoltraPalette(
      brand: c(brand, other.brand),
      onBrand: c(onBrand, other.onBrand),
      brandTint: c(brandTint, other.brandTint),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      warningTint: c(warningTint, other.warningTint),
      danger: c(danger, other.danger),
      info: c(info, other.info),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      faint: c(faint, other.faint),
      background: c(background, other.background),
      card: c(card, other.card),
      raised: c(raised, other.raised),
      border: c(border, other.border),
      skeleton: c(skeleton, other.skeleton),
      skeletonShine: c(skeletonShine, other.skeletonShine),
    );
  }
}

extension VoltraThemeContext on BuildContext {
  /// The Voltra palette for the current theme: `context.vc.muted`.
  VoltraPalette get vc => Theme.of(this).extension<VoltraPalette>()!;
}

/// Plus Jakarta Sans, bundled in assets/fonts.
const voltraFontFamily = 'PlusJakartaSans';

/// Follows the phone's light or dark setting; Profile → Appearance overrides it for this
/// run of the app (the choice is not saved between launches).
final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

/// Status and navigation bar icons that suit a background of the given brightness.
SystemUiOverlayStyle overlayFor(Brightness background) {
  final icons = background == Brightness.dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    statusBarBrightness: background,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
  );
}

/// App bar for the screens that are dark in both themes (live session, impact, scan).
AppBar darkAppBar(String title, {Color background = VoltraColors.navy}) => AppBar(
  title: Text(title),
  backgroundColor: background,
  foregroundColor: Colors.white,
  systemOverlayStyle: overlayFor(Brightness.dark),
  titleTextStyle: const TextStyle(
    fontFamily: voltraFontFamily,
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  ),
);

ThemeData buildTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final p = dark ? VoltraPalette.dark : VoltraPalette.light;

  final scheme = ColorScheme.fromSeed(seedColor: VoltraColors.darkGreen, brightness: brightness).copyWith(
    primary: p.brand,
    onPrimary: p.onBrand,
    primaryContainer: p.brandTint,
    onPrimaryContainer: p.ink,
    secondary: p.brand,
    onSecondary: p.onBrand,
    secondaryContainer: p.brandTint,
    onSecondaryContainer: p.ink,
    error: p.danger,
    surface: p.background,
    onSurface: p.ink,
    onSurfaceVariant: p.muted,
    surfaceContainerLowest: p.card,
    surfaceContainerLow: p.card,
    surfaceContainer: p.card,
    surfaceContainerHigh: p.raised,
    surfaceContainerHighest: p.raised,
    outline: p.faint,
    outlineVariant: p.border,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(brightness: brightness, colorScheme: scheme, fontFamily: voltraFontFamily);
  final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink);

  const buttonText = TextStyle(
    fontFamily: voltraFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );
  const buttonShape = RoundedRectangleBorder(borderRadius: Radii.control);
  OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: Radii.control,
    borderSide: BorderSide(color: color, width: width),
  );

  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.background,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      bodySmall: text.bodySmall?.copyWith(color: p.muted),
    ),
    // One motion language for every pushed page: a short horizontal shared-axis slide.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.horizontal),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: overlayFor(brightness),
      titleTextStyle: TextStyle(
        fontFamily: voltraFontFamily,
        color: p.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.card,
        side: BorderSide(color: p.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.brand,
        foregroundColor: p.onBrand,
        disabledBackgroundColor: p.raised,
        disabledForegroundColor: p.faint,
        minimumSize: const Size.fromHeight(54),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: p.border),
        shape: buttonShape,
        textStyle: buttonText.copyWith(fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.brand,
        minimumSize: const Size(0, 44),
        shape: buttonShape,
        textStyle: buttonText.copyWith(fontSize: 15),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.brand,
      foregroundColor: p.onBrand,
      elevation: 3,
      extendedTextStyle: buttonText.copyWith(fontFamily: voltraFontFamily),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.card,
      selectedColor: p.brandTint,
      checkmarkColor: p.brand,
      side: BorderSide(color: p.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(fontFamily: voltraFontFamily, color: p.ink, fontWeight: FontWeight.w600, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 14),
      border: inputBorder(p.border),
      enabledBorder: inputBorder(p.border),
      focusedBorder: inputBorder(p.brand, 1.6),
      errorBorder: inputBorder(p.danger),
      focusedErrorBorder: inputBorder(p.danger, 1.6),
      labelStyle: TextStyle(color: p.muted),
      hintStyle: TextStyle(color: p.faint),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      modalBackgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.border,
      shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: Radii.card),
      titleTextStyle: TextStyle(fontFamily: voltraFontFamily, color: p.ink, fontSize: 19, fontWeight: FontWeight.w800),
      contentTextStyle: TextStyle(fontFamily: voltraFontFamily, color: p.muted, fontSize: 15, height: 1.4),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? p.raised : VoltraColors.navy,
      contentTextStyle: const TextStyle(fontFamily: voltraFontFamily, color: Colors.white, fontWeight: FontWeight.w600),
      shape: const RoundedRectangleBorder(borderRadius: Radii.control),
      insetPadding: const EdgeInsets.all(Gap.lg),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.brandTint,
      height: 68,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: voltraFontFamily,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: states.contains(WidgetState.selected) ? p.brand : p.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? p.brand : p.muted, size: 24),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(iconColor: p.muted, textColor: p.ink),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.brand, linearTrackColor: p.raised),
    sliderTheme: SliderThemeData(activeTrackColor: p.brand, thumbColor: p.brand, inactiveTrackColor: p.raised),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.brand : p.raised),
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onBrand : p.faint),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: p.brandTint,
        selectedForegroundColor: p.ink,
        foregroundColor: p.muted,
        side: BorderSide(color: p.border),
      ),
    ),
  );
}
