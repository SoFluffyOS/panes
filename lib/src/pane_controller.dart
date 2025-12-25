import 'package:flutter/foundation.dart';
import 'package:panes/src/pane_entry.dart';
import 'package:panes/src/pane_size.dart';

/// Manages the state (size, visibility, maximization) of panes.
class PaneController extends ChangeNotifier {
  final List<PaneEntry> _entries;

  final Map<String, double> _currentPixelSizes = {};
  final Map<String, double> _currentFractionalSizes = {};
  final Map<String, double> _pendingAutoHideSizes = {};
  final Map<String, bool> _visibilityOverrides = {};

  /// Creates a [PaneController] with the given list of [entries].
  PaneController({required List<PaneEntry> entries}) : _entries = entries;

  /// The list of pane entries managed by this controller.
  List<PaneEntry> get entries => List.unmodifiable(_entries);

  /// Returns true if the pane with the given [id] is effectively visible.
  bool isVisible(String id) {
    return _visibilityOverrides[id] ??
        _entries
            .firstWhere(
              (e) => e.id == id,
              orElse: () => throw Exception('Pane $id not found'),
            )
            .visible;
  }

  /// Hides the pane with the given [id].
  void hide(String id) {
    if (_visibilityOverrides[id] == false) return;
    _visibilityOverrides[id] = false;
    notifyListeners();
  }

  /// Shows the pane with the given [id].
  void show(String id) {
    if (_visibilityOverrides[id] == true) return;
    _visibilityOverrides[id] = true;
    notifyListeners();
  }

  /// Toggles the visibility of the pane with the given [id].
  void toggle(String id) {
    if (isVisible(id)) {
      hide(id);
    } else {
      show(id);
    }
  }

  /// Updates the size of the pane with the given [id].
  ///
  /// Handles auto-hide logic for pixel sizes and enforces min/max constraints.
  void updateSize(String id, PaneSize newSize) {
    switch (newSize) {
      case PaneSizePixel(:final pixels):
        var size = pixels;
        if (size < 0) {
          size = 0;
        }

        final entry = _entries.firstWhere(
          (e) => e.id == id,
          orElse: () => throw Exception('Pane $id not found'),
        );

        // Enforce min/max
        double min = 0.0;
        if (entry.minSize case PaneSizePixel(pixels: final p)) {
          min = p;
        }

        double max = double.infinity;
        if (entry.maxSize case PaneSizePixel(pixels: final p)) {
          max = p;
        }

        // Auto-Hide Logic
        if (entry.autoHide) {
          // Calculate threshold in pixels
          final double threshold = switch (entry.autoHideThreshold) {
            PaneSizePixel(:final pixels) => pixels,
            PaneSizeFraction(:final fraction) => fraction * min, // fraction of minSize
            null => switch (entry.minSize) {
              PaneSizePixel(:final pixels) => pixels,
              _ => 20.0,
            },
          };

          // Track intended size for detecting when user drags past threshold
          // even though visual size stays at minSize
          if (size < min) {
            _pendingAutoHideSizes[id] = size;
            if (size < threshold) {
              _pendingAutoHideSizes.remove(id);
              hide(id);
              return;
            }
            // Visual stays at min, but we track the intended size
            size = min;
          } else {
            // Reset tracking when user drags back above minSize
            _pendingAutoHideSizes.remove(id);
            if (size < threshold) {
              hide(id);
              return;
            }
          }
        } else {
          if (size < min) size = min;
        }

        if (size > max) size = max;

        _currentPixelSizes[id] = size;

      case PaneSizeFraction(:final fraction):
        var frac = fraction;
        if (frac.isNaN || frac.isInfinite) {
          // Prevent bad values
          return;
        }
        if (frac < 0) frac = 0;

        _currentFractionalSizes[id] = frac;
    }
    notifyListeners();
  }

  // Maximize / Restore
  String? _maximizedPaneId;

  /// The ID of the currently maximized pane, if any.
  String? get maximizedPaneId => _maximizedPaneId;

  /// Returns true if any pane is currently maximized.
  bool get isMaximized => _maximizedPaneId != null;

  /// Maximizes the pane with the given [id].
  void maximize(String id) {
    if (_entries.any((e) => e.id == id)) {
      _maximizedPaneId = id;
      notifyListeners();
    }
  }

  /// Restores the maximized pane to its previous state.
  void restore() {
    if (_maximizedPaneId != null) {
      _maximizedPaneId = null;
      notifyListeners();
    }
  }

  /// Toggles between maximized and restored state for the pane with the given [id].
  void toggleMaximize(String id) {
    if (_maximizedPaneId == id) {
      restore();
    } else {
      maximize(id);
    }
  }

  /// Resets the size of the pane with the given [id] to its initial configuration.
  void resetSize(String id) {
    _currentPixelSizes.remove(id);
    _currentFractionalSizes.remove(id);
    notifyListeners();
  }

  /// Resets all pane sizes to their initial configurations.
  void resetAll() {
    _currentPixelSizes.clear();
    _currentFractionalSizes.clear();
    notifyListeners();
  }

  /// Gets the current pixel size override for the pane [id], if any.
  ///
  /// When auto-hide is tracking a drag below minSize, returns the pending
  /// (intended) size so that resize calculations accumulate correctly.
  double? getPixelSize(String id) =>
      _pendingAutoHideSizes[id] ?? _currentPixelSizes[id];

  /// Gets the visual pixel size for display purposes.
  ///
  /// Unlike [getPixelSize], this always returns the clamped display size,
  /// ignoring any pending auto-hide tracking.
  double? getVisualPixelSize(String id) => _currentPixelSizes[id];

  /// Gets the current fractional size override for the pane [id], if any.
  double? getFractionalSize(String id) => _currentFractionalSizes[id];

  /// Saves the current controller state (sizes and visibility) to a map.
  Map<String, dynamic> save() {
    return {
      'pixelSizes': _currentPixelSizes,
      'fractionalSizes': _currentFractionalSizes,
      'overrides': Map<String, dynamic>.from(
        _visibilityOverrides,
      ),
    };
  }

  /// Loads the controller state from a map.
  void load(Map<String, dynamic> data) {
    if (data.containsKey('pixelSizes')) {
      final map = data['pixelSizes'] as Map;
      _currentPixelSizes.clear();
      map.forEach((k, v) {
        if (v is num) _currentPixelSizes[k.toString()] = v.toDouble();
      });
    }
    if (data.containsKey('fractionalSizes')) {
      final map = data['fractionalSizes'] as Map;
      _currentFractionalSizes.clear();
      map.forEach((k, v) {
        if (v is num) _currentFractionalSizes[k.toString()] = v.toDouble();
      });
    }
    // Visibility overrides not yet strictly used for structure changes but
    // if we add them later:
    if (data.containsKey('overrides')) {
      final map = data['overrides'] as Map;
      _visibilityOverrides.clear();
      map.forEach((k, v) {
        if (v is bool) _visibilityOverrides[k.toString()] = v;
      });
    }
    notifyListeners();
  }
}
