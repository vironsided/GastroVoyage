/// Real passport proportions (width × height per page, in arbitrary units).
class PassportDimensions {
  PassportDimensions._();

  static const double pageWidth = 9;
  static const double pageHeight = 13.5;
  static const double binding = 0.35;

  /// Open spread: two pages side by side.
  static double get spreadWidth => pageWidth * 2 + binding;
  static double get spreadHeight => pageHeight;
  static double get aspectRatio => spreadWidth / spreadHeight;

  /// Base logical size before [FittedBox] scales to fit the screen.
  static const double unit = 28;

  static double get spreadLogicalWidth => spreadWidth * unit;
  static double get spreadLogicalHeight => spreadHeight * unit;
}
