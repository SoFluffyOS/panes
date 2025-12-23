/// Represents the size of a pane, either in pixels or as a fraction (flex).
sealed class PaneSize {
  const PaneSize();

  /// Creates a fixed size in pixels.
  factory PaneSize.pixel(double pixels) = PaneSizePixel;

  /// Creates a fractional size (flex).
  factory PaneSize.fraction(double fraction) = PaneSizeFraction;

  /// The numeric value of the size (pixels or fraction).
  double get size;
}

/// A fixed size in pixels.
class PaneSizePixel extends PaneSize {
  /// The size in pixels.
  final double pixels;

  /// Creates a [PaneSizePixel].
  const PaneSizePixel(this.pixels);

  @override
  double get size => pixels;
}

/// A fractional size (similar to flex in [Expanded]).
class PaneSizeFraction extends PaneSize {
  /// The fraction value.
  final double fraction;

  /// Creates a [PaneSizeFraction].
  const PaneSizeFraction(this.fraction);

  @override
  double get size => fraction;
}
