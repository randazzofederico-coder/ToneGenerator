/// UI dimension scale system.
/// All channel card and control sizes derive from this scale factor.
/// Future settings screen will allow changing [scaleFactor].
class UIScale {
  /// Scale factor: 1.0 = default, 0.8 = compact, 1.2 = spacious
  final double scaleFactor;

  const UIScale({this.scaleFactor = 1.0});

  // --- Fonts ---
  double get fontTiny => 8 * scaleFactor;
  double get fontSmall => 10 * scaleFactor;
  double get fontBody => 12 * scaleFactor;
  double get fontMedium => 13 * scaleFactor;
  double get fontTitle => 15 * scaleFactor;
  double get fontLarge => 18 * scaleFactor;

  // --- Spacing ---
  double get spacingXs => 2 * scaleFactor;
  double get spacingSm => 4 * scaleFactor;
  double get spacingMd => 8 * scaleFactor;
  double get spacingLg => 12 * scaleFactor;

  // --- Channel card ---
  double get cardPaddingH => 10 * scaleFactor;
  double get cardPaddingV => 8 * scaleFactor;
  double get cardRadius => 10 * scaleFactor;
  double get accentWidth => 3 * scaleFactor;

  // --- Badge ---
  double get badgeSize => 22 * scaleFactor;
  double get badgeFont => 11 * scaleFactor;

  // --- Toggle chips ---
  double get chipSize => 22 * scaleFactor;
  double get chipFont => 10 * scaleFactor;
  double get chipRadius => 5 * scaleFactor;

  // --- Knobs ---
  double get knobWidth => 42 * scaleFactor;
  double get knobHeight => 46 * scaleFactor;
  double get knobDiameter => 26 * scaleFactor;

  // --- Slider ---
  double get sliderTrackHeight => 4 * scaleFactor;
  double get sliderThumbRadius => 7 * scaleFactor;

  // --- Waveform segments ---
  double get waveformIconSize => 14 * scaleFactor;
  double get waveformPadH => 8 * scaleFactor;
  double get waveformPadV => 4 * scaleFactor;

  // --- Piano ---
  double get pianoWhiteKeyWidth => 36 * scaleFactor;
  double get pianoWhiteKeyHeight => 90 * scaleFactor;
  double get pianoBlackKeyWidth => 22 * scaleFactor;
  double get pianoBlackKeyHeight => 56 * scaleFactor;
  double get pianoBarHeight => 36 * scaleFactor;
}

/// Default scale instance — will eventually come from Provider/settings
const defaultUIScale = UIScale();
