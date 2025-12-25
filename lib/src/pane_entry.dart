import 'package:flutter/foundation.dart';
import 'package:panes/src/pane_size.dart';

/// Configuration for a single pane within a [PaneController].
@immutable
class PaneEntry {
  /// Unique identifier for this pane.
  final String id;

  /// Whether the pane is initially visible.
  final bool visible;

  /// The initial size of the pane.
  final PaneSize initialSize;

  /// The minimum size of the pane.
  final PaneSize? minSize;

  /// The maximum size of the pane.
  final PaneSize? maxSize;

  /// Whether the pane should automatically hide when resized below a threshold.
  final bool autoHide;

  /// The threshold for auto-hiding.
  ///
  /// Can be a pixel value or a fraction. If null, defaults to [minSize]
  /// (or 20.0 pixels if minSize is also not set).
  final PaneSize? autoHideThreshold;

  /// Creates a [PaneEntry].
  const PaneEntry({
    required this.id,
    this.visible = true,
    required this.initialSize,
    this.minSize,
    this.maxSize,
    this.autoHide = false,
    this.autoHideThreshold,
  });

  /// Creates a copy of this entry with the given fields replaced with new values.
  PaneEntry copyWith({
    String? id,
    bool? visible,
    PaneSize? initialSize,
    PaneSize? minSize,
    PaneSize? maxSize,
    bool? autoHide,
    PaneSize? autoHideThreshold,
  }) {
    return PaneEntry(
      id: id ?? this.id,
      visible: visible ?? this.visible,
      initialSize: initialSize ?? this.initialSize,
      minSize: minSize ?? this.minSize,
      maxSize: maxSize ?? this.maxSize,
      autoHide: autoHide ?? this.autoHide,
      autoHideThreshold: autoHideThreshold ?? this.autoHideThreshold,
    );
  }
}
