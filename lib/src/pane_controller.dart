import 'package:flutter/foundation.dart';
import 'package:panes/src/auto_hide_state.dart';
import 'package:panes/src/pane_entry.dart';
import 'package:panes/src/pane_size.dart';
import 'package:panes/src/resize_calculator.dart';

/// Manages the state (size, visibility, maximization) of panes.
class PaneController extends ChangeNotifier {
  final List<PaneEntry> _entries;

  /// Core size storage.
  final Map<String, double> _pixelSizes = {};
  final Map<String, double> _fractionalSizes = {};
  final Map<String, bool> _visibilityOverrides = {};

  /// Auto-hide state per pane (replaces scattered maps).
  final Map<String, AutoHideState> _autoHideStates = {};

  /// Tracks virtual position when dragging past bounds.
  /// Used to implement "dead zone" behavior where reversing doesn't resize
  /// until the virtual position comes back within bounds.
  final Map<String, double> _maxOvershootPositions = {};
  final Map<String, double> _minUndershootPositions = {};

  /// Whether a resize drag is currently in progress.
  bool _isResizing = false;

  /// Creates a [PaneController] with the given list of [entries].
  PaneController({required List<PaneEntry> entries}) : _entries = entries;

  /// The list of pane entries managed by this controller.
  List<PaneEntry> get entries => List.unmodifiable(_entries);

  /// Whether a resize drag is currently in progress.
  bool get isResizing => _isResizing;

  // ---------------------------------------------------------------------------
  // Visibility
  // ---------------------------------------------------------------------------

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

    // Restore size from auto-hide state if available
    if (_autoHideStates[id] case AutoHideHidden(:final restoreSize?) ||
        AutoHidePendingReveal(:final restoreSize)) {
      _pixelSizes[id] = restoreSize;
      _autoHideStates[id] = AutoHideVisible(pixelSize: restoreSize);
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

  // ---------------------------------------------------------------------------
  // Resize Operations
  // ---------------------------------------------------------------------------

  /// Called when a resize drag starts.
  ///
  /// Initializes tracking state for auto-hide panes.
  void beginResize(String paneId, {String? adjacentPaneId}) {
    _isResizing = true;

    _initializeResizeState(paneId);
    if (adjacentPaneId != null) {
      _initializeResizeState(adjacentPaneId);
    }

    notifyListeners();
  }

  void _initializeResizeState(String id) {
    final entry = _getEntry(id);
    if (!entry.autoHide) return;

    final currentSize = _pixelSizes[id] ?? entry.initialSize.size;
    _autoHideStates[id] = AutoHideBehavior.initializeDragState(
      isVisible: isVisible(id),
      currentSize: currentSize,
      entry: entry,
    );
  }

  /// Called when a resize drag ends.
  ///
  /// Cleans up tracking state.
  void endResize(String paneId, {String? adjacentPaneId}) {
    _isResizing = false;

    _finalizeResizeState(paneId);
    if (adjacentPaneId != null) {
      _finalizeResizeState(adjacentPaneId);
    }

    notifyListeners();
  }

  void _finalizeResizeState(String id) {
    // Clear bound tracking
    _maxOvershootPositions.remove(id);
    _minUndershootPositions.remove(id);

    // Finalize auto-hide state if present
    final state = _autoHideStates[id];
    if (state == null) return;

    _autoHideStates[id] = AutoHideBehavior.finalizeDragState(
      currentState: state,
      isVisible: isVisible(id),
    );
  }

  /// Main entry point for resize operations.
  ///
  /// Handles pixel panes, fractional panes, and auto-hide behavior.
  /// All constraint enforcement happens here.
  void resize({
    required String paneId,
    required double delta,
    required double containerSize,
    required double resizerThickness,
    String? adjacentPaneId,
  }) {
    if (delta == 0) return;

    final entry = _getEntry(paneId);
    final context = ResizeCalculator.buildContext(
      entries: _entries,
      containerSize: containerSize,
      resizerThickness: resizerThickness,
      getCurrentPixelSize: _getPixelSizeForCalculation,
      getCurrentFraction: (id) => _fractionalSizes[id],
    );

    // Determine if this is a pixel or fractional resize
    final isPixelPane =
        _pixelSizes[paneId] != null || entry.initialSize is PaneSizePixel;

    if (isPixelPane) {
      _resizePixelPane(paneId, entry, delta, context);
    } else if (adjacentPaneId != null) {
      // Check if adjacent pane is pixel-sized
      final adjacentEntry = _getEntry(adjacentPaneId);
      final isAdjacentPixel = _pixelSizes[adjacentPaneId] != null ||
          adjacentEntry.initialSize is PaneSizePixel;

      if (isAdjacentPixel) {
        // Resize the adjacent pixel pane with negative delta
        _resizePixelPane(adjacentPaneId, adjacentEntry, -delta, context);
      } else {
        // Both are fractional
        _resizeFractionalPanes(
          paneId,
          entry,
          adjacentPaneId,
          adjacentEntry,
          delta,
          context,
        );
      }
    }

    notifyListeners();
  }

  void _resizePixelPane(
    String id,
    PaneEntry entry,
    double delta,
    ResizeContext context,
  ) {
    // Use virtual position if we're in overshoot/undershoot, otherwise actual size
    final currentSize = _maxOvershootPositions[id] ??
        _minUndershootPositions[id] ??
        _getPixelSizeForCalculation(id) ??
        entry.initialSize.size;
    final requestedSize = currentSize + delta;

    final minSize = ResizeCalculator.getMinPixels(entry, context);
    final maxSize = ResizeCalculator.getMaxPixels(entry, context);

    // Handle max overshoot - track virtual position, clamp display to max
    if (requestedSize > maxSize) {
      _maxOvershootPositions[id] = requestedSize;
      _minUndershootPositions.remove(id);
      _pixelSizes[id] = maxSize;
      if (entry.autoHide) {
        _autoHideStates[id] = AutoHideVisible(pixelSize: maxSize);
      }
      return;
    }

    // Handle min undershoot for non-auto-hide panes
    // (auto-hide panes have their own below-min tracking)
    if (!entry.autoHide && requestedSize < minSize) {
      _minUndershootPositions[id] = requestedSize;
      _maxOvershootPositions.remove(id);
      _pixelSizes[id] = minSize;
      return;
    }

    // Within bounds - clear tracking and proceed
    _maxOvershootPositions.remove(id);
    _minUndershootPositions.remove(id);

    if (entry.autoHide) {
      _handleAutoHideResize(id, entry, requestedSize, context);
    } else {
      _handleConstrainedResize(id, entry, requestedSize, context);
    }
  }

  void _handleConstrainedResize(
    String id,
    PaneEntry entry,
    double requestedSize,
    ResizeContext context,
  ) {
    final minSize = ResizeCalculator.getMinPixels(entry, context);
    final maxSize = ResizeCalculator.getMaxPixels(entry, context);
    final clampedSize = requestedSize.clamp(minSize, maxSize);
    _pixelSizes[id] = clampedSize;
  }

  void _handleAutoHideResize(
    String id,
    PaneEntry entry,
    double requestedSize,
    ResizeContext context,
  ) {
    final currentState = _autoHideStates[id] ?? const AutoHideVisible();

    final result = AutoHideBehavior.processResize(
      currentState: currentState,
      requestedSize: requestedSize,
      entry: entry,
      context: context,
      isVisible: isVisible(id),
    );

    switch (result) {
      case AutoHideResultUpdated(:final newState, :final newSize):
        _autoHideStates[id] = newState;
        _pixelSizes[id] = newSize;

      case AutoHideResultHide(:final newState):
        _autoHideStates[id] = newState;
        _visibilityOverrides[id] = false;

      case AutoHideResultReveal(
          :final newState,
          :final revealSize,
          :final requestedSize
        ):
        _autoHideStates[id] = newState;
        _visibilityOverrides[id] = true;
        _pixelSizes[id] = revealSize;

        // If reveal was clamped to minSize, track undershoot so the divider
        // stays aligned with the mouse until virtual position catches up
        if (requestedSize < revealSize) {
          _minUndershootPositions[id] = requestedSize;
        }

      case AutoHideResultNoChange(:final newState):
        _autoHideStates[id] = newState;
    }
  }

  void _resizeFractionalPanes(
    String id1,
    PaneEntry entry1,
    String id2,
    PaneEntry entry2,
    double deltaPixels,
    ResizeContext context,
  ) {
    final currentFrac1 = _fractionalSizes[id1] ?? entry1.initialSize.size;
    final currentFrac2 = _fractionalSizes[id2] ?? entry2.initialSize.size;

    final (newFrac1, newFrac2) = ResizeCalculator.applyFractionalDelta(
      currentFraction1: currentFrac1,
      currentFraction2: currentFrac2,
      deltaPixels: deltaPixels,
      entry1: entry1,
      entry2: entry2,
      context: context,
    );

    _fractionalSizes[id1] = newFrac1;
    _fractionalSizes[id2] = newFrac2;
  }

  // ---------------------------------------------------------------------------
  // Size Queries
  // ---------------------------------------------------------------------------

  /// Gets the pixel size for resize calculations.
  ///
  /// For auto-hide panes being dragged, returns the virtual position.
  double? _getPixelSizeForCalculation(String id) {
    final state = _autoHideStates[id];
    if (state != null) {
      return state.calculationSize ?? _pixelSizes[id];
    }
    return _pixelSizes[id];
  }

  /// Gets the current pixel size override for the pane [id], if any.
  ///
  /// When auto-hide is tracking a drag below minSize, returns the pending
  /// (intended) size so that resize calculations accumulate correctly.
  double? getPixelSize(String id) {
    return _getPixelSizeForCalculation(id);
  }

  /// Gets the visual pixel size for display purposes.
  ///
  /// Unlike [getPixelSize], this always returns the clamped display size,
  /// ignoring any pending auto-hide tracking.
  double? getVisualPixelSize(String id) => _pixelSizes[id];

  /// Gets the current fractional size override for the pane [id], if any.
  double? getFractionalSize(String id) => _fractionalSizes[id];

  // ---------------------------------------------------------------------------
  // Maximize / Restore
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Resets the size of the pane with the given [id] to its initial configuration.
  void resetSize(String id) {
    _pixelSizes.remove(id);
    _fractionalSizes.remove(id);
    _autoHideStates.remove(id);
    _maxOvershootPositions.remove(id);
    _minUndershootPositions.remove(id);
    notifyListeners();
  }

  /// Resets all pane sizes to their initial configurations.
  void resetAll() {
    _pixelSizes.clear();
    _fractionalSizes.clear();
    _autoHideStates.clear();
    _maxOvershootPositions.clear();
    _minUndershootPositions.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Legacy API (for backward compatibility during migration)
  // ---------------------------------------------------------------------------

  /// @Deprecated: Use [resize] instead.
  void updateSize(String id, PaneSize newSize) {
    switch (newSize) {
      case PaneSizePixel(:final pixels):
        var size = pixels;
        if (size < 0) size = 0;
        _pixelSizes[id] = size;

      case PaneSizeFraction(:final fraction):
        var frac = fraction;
        if (frac.isNaN || frac.isInfinite) return;
        if (frac < 0) frac = 0;
        _fractionalSizes[id] = frac;
    }
    notifyListeners();
  }

  /// @Deprecated: Use [beginResize] instead.
  void savePreDragSize(String id) {
    _initializeResizeState(id);
  }

  /// @Deprecated: Use [endResize] instead.
  void clearPreDragSize(String id) {
    _finalizeResizeState(id);
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Saves the current controller state (sizes and visibility) to a map.
  Map<String, dynamic> save() {
    return {
      'pixelSizes': Map<String, double>.from(_pixelSizes),
      'fractionalSizes': Map<String, double>.from(_fractionalSizes),
      'overrides': Map<String, bool>.from(_visibilityOverrides),
    };
  }

  /// Loads the controller state from a map.
  void load(Map<String, dynamic> data) {
    // Clear all state
    _autoHideStates.clear();

    if (data.containsKey('pixelSizes')) {
      final map = data['pixelSizes'] as Map;
      _pixelSizes.clear();
      map.forEach((k, v) {
        if (v is num) _pixelSizes[k.toString()] = v.toDouble();
      });
    }
    if (data.containsKey('fractionalSizes')) {
      final map = data['fractionalSizes'] as Map;
      _fractionalSizes.clear();
      map.forEach((k, v) {
        if (v is num) _fractionalSizes[k.toString()] = v.toDouble();
      });
    }
    if (data.containsKey('overrides')) {
      final map = data['overrides'] as Map;
      _visibilityOverrides.clear();
      map.forEach((k, v) {
        if (v is bool) _visibilityOverrides[k.toString()] = v;
      });
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  PaneEntry _getEntry(String id) {
    return _entries.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Pane $id not found'),
    );
  }
}
