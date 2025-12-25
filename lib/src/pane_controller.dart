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

  /// Stores the size a pane had before it was auto-hidden.
  /// This is used to restore the size when the pane is shown again.
  final Map<String, double> _autoHideRestoreSizes = {};

  /// Tracks panes that were auto-hidden during an active drag.
  /// Maps pane ID to the current virtual position.
  /// Used by getPixelSize() to return correct position for delta calculations.
  final Map<String, double> _pendingRevealPanes = {};

  /// Tracks the lowest point reached during drag-to-reveal.
  /// Used to measure reverse drag delta for reveal threshold.
  final Map<String, double> _lowestRevealPoint = {};

  /// Tracks panes that were revealed via drag-to-reveal during the current drag.
  /// These panes skip auto-hide logic until the drag ends to prevent flickering.
  final Set<String> _revealedDuringDrag = {};

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
  ///
  /// If the pane was auto-hidden, restores it to its pre-hide size.
  void show(String id) {
    if (_visibilityOverrides[id] == true) return;
    _visibilityOverrides[id] = true;

    // Restore size if this pane was auto-hidden
    final restoreSize = _autoHideRestoreSizes.remove(id);
    if (restoreSize != null) {
      _currentPixelSizes[id] = restoreSize;
    }

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

  /// Saves the current size of the pane before a drag operation.
  ///
  /// This should be called when a resize drag starts on a pane with auto-hide
  /// enabled. If the pane is later auto-hidden during the drag, this size
  /// will be restored when the pane is shown again.
  /// Also initializes reveal tracking for hidden panes (edge drag to reveal).
  void savePreDragSize(String id) {
    final entry = _entries.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Pane $id not found'),
    );
    if (entry.autoHide) {
      // If pane is hidden, initialize for edge-drag-to-reveal
      if (!isVisible(id)) {
        _pendingRevealPanes[id] = 0; // Start from 0 (hidden state)
        _lowestRevealPoint[id] = 0;
      } else {
        _autoHideRestoreSizes[id] =
            _currentPixelSizes[id] ?? entry.initialSize.size;
      }
    }
  }

  /// Clears the saved pre-drag size when a resize drag ends without auto-hide.
  void clearPreDragSize(String id) {
    // Clear pending reveal state - drag has ended
    _pendingRevealPanes.remove(id);
    _lowestRevealPoint.remove(id);
    _revealedDuringDrag.remove(id);
    // Only clear restore size if the pane is still visible (not auto-hidden)
    if (isVisible(id)) {
      _autoHideRestoreSizes.remove(id);
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

        // Drag-to-reveal: if pane was auto-hidden during this drag and user
        // is dragging in reverse direction by at least threshold amount, show it.
        // getPixelSize() returns _pendingRevealPanes for correct delta calculation.
        if (_pendingRevealPanes.containsKey(id) && !isVisible(id)) {
          final lowestPoint = _lowestRevealPoint[id] ?? size;

          // Track the lowest point - if user continues dragging to close
          if (size < lowestPoint) {
            _lowestRevealPoint[id] = size;
          }

          final double threshold = switch (entry.autoHideThreshold) {
            PaneSizePixel(:final pixels) => pixels,
            PaneSizeFraction(:final fraction) => fraction * min,
            null => switch (entry.minSize) {
              PaneSizePixel(:final pixels) => pixels,
              _ => 20.0,
            },
          };

          // Check if user has dragged back by threshold amount from lowest point
          final currentLowest = _lowestRevealPoint[id] ?? lowestPoint;
          final reverseDelta = size - currentLowest;

          if (reverseDelta >= threshold) {
            _pendingRevealPanes.remove(id);
            _lowestRevealPoint.remove(id);
            _revealedDuringDrag.add(id);
            _visibilityOverrides[id] = true;
            _currentPixelSizes[id] = size.clamp(min, max);
            notifyListeners();
            return;
          }

          // Always update current position for next delta calculation
          _pendingRevealPanes[id] = size;
          return;
        }

        // Clear the revealed flag once size exceeds min - allows re-hide
        if (_revealedDuringDrag.contains(id) && size >= min) {
          _revealedDuringDrag.remove(id);
        }

        // Auto-Hide Logic (skip for panes just revealed via drag-to-reveal)
        if (entry.autoHide && !_revealedDuringDrag.contains(id)) {
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
              // Mark for potential drag-to-reveal
              _pendingRevealPanes[id] = size;
              _lowestRevealPoint[id] = size; // Initialize lowest point
              hide(id);
              return;
            }
            // Visual stays at min, but we track the intended size
            size = min;
          } else {
            // Reset tracking when user drags back above minSize
            _pendingAutoHideSizes.remove(id);
            if (size < threshold) {
              // Mark for potential drag-to-reveal
              _pendingRevealPanes[id] = size;
              _lowestRevealPoint[id] = size; // Initialize lowest point
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
  ///
  /// Also clears any pending auto-hide state and saved restore sizes.
  void resetSize(String id) {
    _currentPixelSizes.remove(id);
    _currentFractionalSizes.remove(id);
    _pendingAutoHideSizes.remove(id);
    _autoHideRestoreSizes.remove(id);
    _pendingRevealPanes.remove(id);
    _lowestRevealPoint.remove(id);
    _revealedDuringDrag.remove(id);
    notifyListeners();
  }

  /// Resets all pane sizes to their initial configurations.
  ///
  /// Also clears any pending auto-hide state and saved restore sizes.
  void resetAll() {
    _currentPixelSizes.clear();
    _currentFractionalSizes.clear();
    _pendingAutoHideSizes.clear();
    _autoHideRestoreSizes.clear();
    _pendingRevealPanes.clear();
    _lowestRevealPoint.clear();
    _revealedDuringDrag.clear();
    notifyListeners();
  }

  /// Gets the current pixel size override for the pane [id], if any.
  ///
  /// When auto-hide is tracking a drag below minSize, returns the pending
  /// (intended) size so that resize calculations accumulate correctly.
  /// When pane is hidden and in pending reveal state, returns the virtual
  /// position for correct drag delta calculation.
  double? getPixelSize(String id) {
    // Return virtual position for hidden panes awaiting reveal
    final revealSize = _pendingRevealPanes[id];
    if (revealSize != null && !isVisible(id)) {
      return revealSize;
    }
    return _pendingAutoHideSizes[id] ?? _currentPixelSizes[id];
  }

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
