import 'dart:math' as math;

import 'package:flutter/material.dart';

const colorSchemes = ['violet', 'blue', 'teal', 'green', 'rose', 'amber'];

// Each scheme rotates the violet tonal palette's hue in OKLCH, keeping lightness.
Color _rotateHue(Color color, double degrees) {
  if (degrees == 0) return color;
  double linear(double c) =>
      c <= .04045 ? c / 12.92 : math.pow((c + .055) / 1.055, 2.4).toDouble();
  final r = linear(color.r), g = linear(color.g), b = linear(color.b);
  final l = math
      .pow(.4122214708 * r + .5363325363 * g + .0514459929 * b, 1 / 3)
      .toDouble();
  final m = math
      .pow(.2119034982 * r + .6806995451 * g + .1073969566 * b, 1 / 3)
      .toDouble();
  final s = math
      .pow(.0883024619 * r + .2817188376 * g + .6299787005 * b, 1 / 3)
      .toDouble();
  final lightness = .2104542553 * l + .793617785 * m - .0040720468 * s;
  final a = 1.9779984951 * l - 2.428592205 * m + .4505937099 * s;
  final oldB = .0259040371 * l + .7827717662 * m - .808675766 * s;
  final angle = degrees * math.pi / 180;
  final rotatedA = a * math.cos(angle) - oldB * math.sin(angle);
  final rotatedB = a * math.sin(angle) + oldB * math.cos(angle);
  final ll = math
      .pow(lightness + .3963377774 * rotatedA + .2158037573 * rotatedB, 3)
      .toDouble();
  final mm = math
      .pow(lightness - .1055613458 * rotatedA - .0638541728 * rotatedB, 3)
      .toDouble();
  final ss = math
      .pow(lightness - .0894841775 * rotatedA - 1.291485548 * rotatedB, 3)
      .toDouble();
  int encode(double c) =>
      ((c <= .0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4) - .055) * 255)
          .round()
          .clamp(0, 255);
  return Color.fromARGB(
    255,
    encode(4.0767416621 * ll - 3.3077115913 * mm + .2309699292 * ss),
    encode(-1.2684380046 * ll + 2.6097574011 * mm - .3413193965 * ss),
    encode(-.0041960863 * ll - .7034186147 * mm + 1.707614701 * ss),
  );
}

ColorScheme referenceColors(bool dark, String scheme) {
  final hue =
      const {
        'violet': 0.0,
        'blue': -40.0,
        'teal': -110.0,
        'green': -165.0,
        'rose': 50.0,
        'amber': 130.0,
      }[scheme] ??
      0;
  Color c(int light, int night) =>
      _rotateHue(Color(0xFF000000 | (dark ? night : light)), hue);
  // Answer-state colors are exact sRGB tokens per scheme, not hue-rotated.
  // Dark mode swaps each container/foreground pair.
  final answerColors =
      const {
        'violet': [0xEADDFF, 0x4F378B, 0xE8DEF8, 0x4A4458],
        'blue': [0xD3E5FF, 0x004A90, 0xD7E4FD, 0x3D495A],
        'teal': [0xC0EFED, 0x005F51, 0xC9ECEA, 0x324E4B],
        'green': [0xD5ECCD, 0x355600, 0xD8EAD2, 0x404C39],
        'rose': [0xFFD8E7, 0x78245D, 0xF8DAE5, 0x56414B],
        'amber': [0xF8E0C2, 0x7A3300, 0xF3E0C9, 0x544534],
      }[scheme] ??
      const [0xEADDFF, 0x4F378B, 0xE8DEF8, 0x4A4458];
  Color answer(int index) =>
      Color(0xFF000000 | answerColors[dark ? index ^ 1 : index]);
  return ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: c(0x6750A4, 0xD0BCFF),
    onPrimary: c(0xFFFFFF, 0x381E72),
    primaryContainer: answer(0),
    onPrimaryContainer: answer(1),
    secondary: c(0x625B71, 0xCCC2DC),
    onSecondary: c(0xFFFFFF, 0x332D41),
    secondaryContainer: answer(2),
    onSecondaryContainer: answer(3),
    tertiary: c(0x7D5260, 0xEFB8C8),
    onTertiary: c(0xFFFFFF, 0x492532),
    tertiaryContainer: c(0xFFD8E4, 0x633B48),
    onTertiaryContainer: c(0x633B48, 0xFFD8E4),
    surface: c(0xFEF7FF, 0x141218),
    onSurface: c(0x1D1B20, 0xE6E0E9),
    onSurfaceVariant: c(0x49454F, 0xCAC4D0),
    surfaceDim: c(0xDED8E1, 0x141218),
    surfaceBright: c(0xFEF7FF, 0x3B383E),
    surfaceContainerLowest: c(0xFFFFFF, 0x0F0D13),
    surfaceContainerLow: c(0xF7F2FA, 0x1D1B20),
    surfaceContainer: c(0xF3EDF7, 0x211F26),
    surfaceContainerHigh: c(0xECE6F0, 0x2B2930),
    surfaceContainerHighest: c(0xE6E0E9, 0x36343B),
    outline: c(0x79747E, 0x938F99),
    outlineVariant: c(0xCAC4D0, 0x49454F),
    inverseSurface: c(0x322F35, 0xE6E0E9),
    onInverseSurface: c(0xF5EFF7, 0x322F35),
    inversePrimary: c(0xD0BCFF, 0x6750A4),
    surfaceTint: c(0x6750A4, 0xD0BCFF),
    error: Color(dark ? 0xFFF2B8B5 : 0xFFB3261E),
    onError: Color(dark ? 0xFF601410 : 0xFFFFFFFF),
    errorContainer: Color(dark ? 0xFF8C1D18 : 0xFFF9DEDC),
    onErrorContainer: Color(dark ? 0xFFF9DEDC : 0xFF852221),
  );
}

/// Roboto Flex axes of the M3 Expressive emphasized type roles (titles 700,
/// headlines 500). The optical size follows the font size; Flutter would
/// otherwise leave it at the font default.
List<FontVariation> emphasized(
  double size, {
  FontWeight weight = FontWeight.w700,
}) => [
  FontVariation.weight(weight.value.toDouble()),
  const FontVariation('wdth', 110),
  const FontVariation('GRAD', 20),
  FontVariation.opticalSize(size),
];

/// Material state layer for ink responses: [color] at 8% while hovered and
/// 10% while focused or pressed.
WidgetStateProperty<Color?> referenceStateLayer(Color color) =>
    WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused)
          ? color.withValues(alpha: .10)
          : states.contains(WidgetState.hovered)
          ? color.withValues(alpha: .08)
          : Colors.transparent,
    );

ButtonStyle referenceButtonStyle({double height = 40}) => ButtonStyle(
  // Material's adaptive default keeps the arrow cursor on desktop; show the
  // hand over everything clickable.
  mouseCursor: WidgetStateMouseCursor.clickable,
  minimumSize: WidgetStatePropertyAll(Size(40, height)),
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: height == 40 ? 16 : 24),
  ),
  textStyle: WidgetStatePropertyAll(
    TextStyle(
      fontFamily: 'Roboto Flex',
      fontFamilyFallback: const ['Noto Sans SC', 'Roboto'],
      fontSize: height == 40 ? 14 : 16,
      fontWeight: FontWeight.w500,
      letterSpacing: height == 40 ? .1 : .15,
    ),
  ),
  iconSize: WidgetStatePropertyAll(height == 40 ? 20 : 24),
  shape: WidgetStateProperty.resolveWith(
    (states) => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        states.contains(WidgetState.pressed) ? 12 : height / 2,
      ),
    ),
  ),
  animationDuration: const Duration(milliseconds: 350),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

ThemeData appTheme(bool dark, String scheme) {
  final colors = referenceColors(dark, scheme);
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    fontFamily: 'Roboto Flex',
    fontFamilyFallback: const ['Noto Sans SC', 'Roboto'],
    visualDensity: VisualDensity.standard,
    iconTheme: const IconThemeData(
      fill: 0,
      weight: 400,
      grade: 0,
      opticalSize: 24,
    ),
    filledButtonTheme: FilledButtonThemeData(style: referenceButtonStyle()),
    outlinedButtonTheme: OutlinedButtonThemeData(style: referenceButtonStyle()),
    textButtonTheme: TextButtonThemeData(style: referenceButtonStyle()),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        mouseCursor: WidgetStateMouseCursor.clickable,
        // Standard icon buttons; without this the glyphs fall back to black.
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.onSurface.withValues(alpha: .38)
              : colors.onSurfaceVariant,
        ),
        fixedSize: const WidgetStatePropertyAll(Size.square(40)),
        minimumSize: const WidgetStatePropertyAll(Size.square(40)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        iconSize: const WidgetStatePropertyAll(24),
        shape: WidgetStateProperty.resolveWith(
          (states) => RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              states.contains(WidgetState.pressed) ? 12 : 20,
            ),
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        animationDuration: const Duration(milliseconds: 350),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerHighest,
      border: const UnderlineInputBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      enabledBorder: UnderlineInputBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        borderSide: BorderSide(color: colors.onSurfaceVariant),
      ),
      focusedBorder: UnderlineInputBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    listTileTheme: ListTileThemeData(
      selectedTileColor: colors.secondaryContainer,
      selectedColor: colors.onSecondaryContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant),
  );
}
