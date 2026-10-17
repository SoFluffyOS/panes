import 'package:flutter/material.dart';
import 'package:panes/src/multi_pane.dart';
import 'package:panes/src/pane_controller.dart';
import 'package:panes/src/pane_entry.dart';
import 'package:panes/src/pane_size.dart';

export 'package:panes/src/pane_entry.dart' show ResizeBehavior;

/// Represents the different panes in an [IdeLayout].
enum IdePane {
  /// The left sidebar pane.
  left('left'),

  /// The right sidebar pane.
  right('right'),

  /// The bottom pane (terminal, logs, etc.).
  bottom('bottom'),

  /// The main center/editor area.
  center('center'),

  /// The center container pane that holds the editor and bottom panel.
  centerContainer('centerContainer');

  /// The string identifier for this pane.
  final String id;

  const IdePane(this.id);
}

/// How the bottom panel of an [IdeLayout] is laid out relative to the side panes.
enum IdeBottomLayout {
  /// The bottom panel sits between the left and right panes, under the editor.
  ///
  /// ```text
  /// ┌──────┬────────┬───────┐
  /// │      │ editor │       │
  /// │ left ├────────┤ right │
  /// │      │ bottom │       │
  /// └──────┴────────┴───────┘
  /// ```
  contained,

  /// The bottom panel spans the full width, under both side panes.
  ///
  /// ```text
  /// ┌──────┬────────┬───────┐
  /// │ left │ editor │ right │
  /// ├──────┴────────┴───────┤
  /// │        bottom         │
  /// └───────────────────────┘
  /// ```
  fullWidth,

  /// The bottom panel extends under the left pane; the right pane spans the
  /// full height.
  ///
  /// ```text
  /// ┌──────┬────────┬───────┐
  /// │ left │ editor │       │
  /// ├──────┴────────┤ right │
  /// │    bottom     │       │
  /// └───────────────┴───────┘
  /// ```
  extendLeft,

  /// The bottom panel extends under the right pane; the left pane spans the
  /// full height.
  ///
  /// ```text
  /// ┌──────┬────────┬───────┐
  /// │      │ editor │ right │
  /// │ left ├────────┴───────┤
  /// │      │     bottom     │
  /// └──────┴────────────────┘
  /// ```
  extendRight,
}

/// A controller for the [IdeLayout] widget.
///
/// Manages the state and visibility of the standard IDE-like panes:
/// left, right, center (editor), and bottom.
///
/// Which [PaneController] holds the left and right panes depends on
/// [bottomLayout]; use [controllerOf] to look it up rather than assuming
/// [rootController].
class IdeController extends ChangeNotifier {
  /// The controller for the outer horizontal axis.
  ///
  /// Holds `left | centerContainer | right` for [IdeBottomLayout.contained]
  /// and [IdeBottomLayout.fullWidth], `centerContainer | right` for
  /// [IdeBottomLayout.extendLeft], and `left | centerContainer` for
  /// [IdeBottomLayout.extendRight].
  late final PaneController rootController;

  /// The controller for the vertical axis (Editor | Bottom).
  late final PaneController centerController;

  /// The controller for the horizontal row above the bottom panel when the
  /// bottom panel extends under a side pane.
  ///
  /// Holds `left | centerContainer` for [IdeBottomLayout.extendLeft],
  /// `centerContainer | right` for [IdeBottomLayout.extendRight], and is
  /// empty otherwise.
  late final PaneController topController;

  IdeBottomLayout _bottomLayout;

  /// Creates an [IdeController] with customizable panel settings.
  ///
  /// All size parameters accept [PaneSize] values, which can be either
  /// [PaneSize.pixel] for fixed pixel sizes or [PaneSize.fraction] for
  /// proportional sizes.
  IdeController({
    IdeBottomLayout bottomLayout = IdeBottomLayout.contained,

    // Left panel configuration
    PaneSize? leftSize,
    PaneSize? leftMinSize,
    PaneSize? leftMaxSize,
    bool leftAutoHide = true,
    PaneSize? leftAutoHideThreshold,
    bool leftVisible = true,
    ResizeBehavior? leftResizeBehavior,

    // Right panel configuration
    PaneSize? rightSize,
    PaneSize? rightMinSize,
    PaneSize? rightMaxSize,
    bool rightAutoHide = true,
    PaneSize? rightAutoHideThreshold,
    bool rightVisible = false,
    ResizeBehavior? rightResizeBehavior,

    // Bottom panel configuration
    PaneSize? bottomSize,
    PaneSize? bottomMinSize,
    PaneSize? bottomMaxSize,
    bool bottomAutoHide = true,
    PaneSize? bottomAutoHideThreshold,
    bool bottomVisible = false,
    ResizeBehavior? bottomResizeBehavior,
  }) : _bottomLayout = bottomLayout {
    final entries = {
      IdePane.left: PaneEntry(
        id: IdePane.left.id,
        initialSize: leftSize ?? PaneSize.pixel(250),
        minSize: leftMinSize ?? PaneSize.pixel(100),
        maxSize: leftMaxSize,
        autoHide: leftAutoHide,
        autoHideThreshold: leftAutoHideThreshold ?? PaneSize.fraction(0.5),
        visible: leftVisible,
        resizeBehavior: leftResizeBehavior,
      ),
      IdePane.centerContainer: _centerContainerEntry,
      IdePane.right: PaneEntry(
        id: IdePane.right.id,
        initialSize: rightSize ?? PaneSize.pixel(300),
        minSize: rightMinSize ?? PaneSize.pixel(200),
        maxSize: rightMaxSize,
        autoHide: rightAutoHide,
        autoHideThreshold: rightAutoHideThreshold ?? PaneSize.fraction(0.5),
        visible: rightVisible,
        resizeBehavior: rightResizeBehavior,
      ),
    };

    // Horizontal: Left | Center | Right, split across rows per bottomLayout
    rootController = PaneController(
      entries: [for (final pane in _rootPanes(bottomLayout)) entries[pane]!],
    );
    topController = PaneController(
      entries: [for (final pane in _topPanes(bottomLayout)) entries[pane]!],
    );

    // Vertical: Editor | Bottom
    centerController = PaneController(
      entries: [
        PaneEntry(
          id: IdePane.center.id,
          initialSize: PaneSize.fraction(1.0),
        ),
        PaneEntry(
          id: IdePane.bottom.id,
          initialSize: bottomSize ?? PaneSize.pixel(240),
          minSize: bottomMinSize ?? PaneSize.pixel(50),
          maxSize: bottomMaxSize,
          autoHide: bottomAutoHide,
          autoHideThreshold: bottomAutoHideThreshold ?? PaneSize.fraction(0.5),
          visible: bottomVisible,
          resizeBehavior: bottomResizeBehavior,
        ),
      ],
    );
  }

  static final _centerContainerEntry = PaneEntry(
    id: IdePane.centerContainer.id,
    initialSize: PaneSize.fraction(1.0),
  );

  static const _stateKeys = ['pixelSizes', 'fractionalSizes', 'overrides'];

  static List<IdePane> _rootPanes(IdeBottomLayout layout) => switch (layout) {
        IdeBottomLayout.contained || IdeBottomLayout.fullWidth => [
            IdePane.left,
            IdePane.centerContainer,
            IdePane.right
          ],
        IdeBottomLayout.extendLeft => [IdePane.centerContainer, IdePane.right],
        IdeBottomLayout.extendRight => [IdePane.left, IdePane.centerContainer],
      };

  static List<IdePane> _topPanes(IdeBottomLayout layout) => switch (layout) {
        IdeBottomLayout.contained || IdeBottomLayout.fullWidth => [],
        IdeBottomLayout.extendLeft => [IdePane.left, IdePane.centerContainer],
        IdeBottomLayout.extendRight => [IdePane.centerContainer, IdePane.right],
      };

  List<PaneController> get _controllers =>
      [rootController, centerController, topController];

  /// How the bottom panel is laid out relative to the side panes.
  IdeBottomLayout get bottomLayout => _bottomLayout;

  /// Changes how the bottom panel is laid out.
  ///
  /// The sizes and visibility of the left and right panes are carried over
  /// when they move between [rootController] and [topController]. Any
  /// maximized pane is restored.
  set bottomLayout(IdeBottomLayout value) {
    if (_bottomLayout == value) return;

    final rootState = rootController.save();
    final topState = topController.save();
    final entries = {
      IdePane.left: _entryOf(IdePane.left),
      IdePane.centerContainer: _centerContainerEntry,
      IdePane.right: _entryOf(IdePane.right),
    };
    final rootPanes = _rootPanes(value);
    final topPanes = _topPanes(value);

    // Add panes to their new controller before removing them from the old
    // one, so controllerOf() always resolves to a controller holding the pane.
    if (_addMissing(rootController, rootPanes, entries)) {
      rootController.load(_stateFor(rootController, [rootState, topState]));
    }
    if (_addMissing(topController, topPanes, entries)) {
      topController.load(_stateFor(topController, [topState, rootState]));
    }

    _bottomLayout = value;

    _removeExtra(rootController, rootPanes);
    _removeExtra(topController, topPanes);
    restore();
    notifyListeners();
  }

  /// Returns the [PaneController] that currently holds [pane].
  ///
  /// The left and right panes move to [topController] when the bottom panel
  /// extends under them.
  PaneController controllerOf(IdePane pane) => switch (pane) {
        IdePane.left when _bottomLayout == IdeBottomLayout.extendLeft =>
          topController,
        IdePane.right when _bottomLayout == IdeBottomLayout.extendRight =>
          topController,
        IdePane.left ||
        IdePane.right ||
        IdePane.centerContainer =>
          rootController,
        IdePane.center || IdePane.bottom => centerController,
      };

  PaneEntry _entryOf(IdePane pane) =>
      controllerOf(pane).entries.firstWhere((e) => e.id == pane.id);

  /// Inserts the [panes] missing from [controller], keeping their order.
  ///
  /// Returns true if any pane was added.
  static bool _addMissing(
    PaneController controller,
    List<IdePane> panes,
    Map<IdePane, PaneEntry> entries,
  ) {
    var added = false;
    for (final (i, pane) in panes.indexed) {
      final ids = [for (final entry in controller.entries) entry.id];
      if (ids.contains(pane.id)) continue;
      final index = i == 0 ? 0 : ids.indexOf(panes[i - 1].id) + 1;
      controller.addPane(entries[pane]!, index: index);
      added = true;
    }
    return added;
  }

  /// Removes the panes of [controller] that are not in [panes].
  static void _removeExtra(PaneController controller, List<IdePane> panes) {
    final keep = {for (final pane in panes) pane.id};
    for (final entry in controller.entries) {
      if (!keep.contains(entry.id)) controller.removePane(entry.id);
    }
  }

  /// Picks the saved state of [controller]'s panes out of [sources].
  ///
  /// Earlier sources take precedence for panes present in several of them.
  static Map<String, dynamic> _stateFor(
    PaneController controller,
    List<Map<String, dynamic>?> sources,
  ) {
    final ids = {for (final entry in controller.entries) entry.id};
    return {
      for (final key in _stateKeys)
        if (sources.any((source) => source?[key] is Map))
          key: {
            for (final source in sources.reversed)
              if (source?[key] case final Map values)
                for (final MapEntry(key: id, :value) in values.entries)
                  if (ids.contains(id)) id: value,
          },
    };
  }

  /// Toggles the visibility of the left panel.
  void toggleLeft() => controllerOf(IdePane.left).toggle(IdePane.left.id);

  /// Toggles the visibility of the right panel.
  void toggleRight() => controllerOf(IdePane.right).toggle(IdePane.right.id);

  /// Toggles the visibility of the bottom panel.
  void toggleBottom() => centerController.toggle(IdePane.bottom.id);

  /// The slots to maximize, outermost first, for [pane] to fill the layout.
  List<(PaneController, String)> _maximizePath(IdePane pane) {
    final root = rootController;
    final center = centerController;
    final top = topController;
    final container = IdePane.centerContainer.id;
    final editor = IdePane.center.id;
    final id = pane.id;

    return switch ((_bottomLayout, pane)) {
      (_, IdePane.centerContainer) => throw ArgumentError.value(
          pane, 'pane', 'The center container cannot be maximized'),
      (IdeBottomLayout.contained, IdePane.left || IdePane.right) => [
          (root, id)
        ],
      (IdeBottomLayout.contained, _) => [(root, container), (center, id)],
      (IdeBottomLayout.fullWidth, IdePane.bottom) => [(center, id)],
      (IdeBottomLayout.fullWidth, IdePane.center) => [
          (center, editor),
          (root, container)
        ],
      (IdeBottomLayout.fullWidth, _) => [(center, editor), (root, id)],
      (_, IdePane.bottom) => [(root, container), (center, id)],
      (_, IdePane.center) => [
          (root, container),
          (center, editor),
          (top, container)
        ],
      _ when controllerOf(pane) == root => [(root, id)],
      _ => [(root, container), (center, editor), (top, id)],
    };
  }

  /// The pane currently maximized to fill the whole layout, if any.
  IdePane? get maximizedPane {
    for (final pane in [
      IdePane.center,
      IdePane.bottom,
      IdePane.left,
      IdePane.right,
    ]) {
      final path = _maximizePath(pane);
      if (path.every((slot) => slot.$1.maximizedPaneId == slot.$2)) {
        return pane;
      }
    }
    return null;
  }

  /// Maximizes [pane] so it fills the whole layout, whatever the
  /// [bottomLayout].
  ///
  /// Throws an [ArgumentError] for [IdePane.centerContainer].
  void maximize(IdePane pane) {
    final path = {
      for (final (controller, id) in _maximizePath(pane)) controller: id,
    };
    for (final controller in _controllers) {
      if (path[controller] case final id?) {
        controller.maximize(id);
      } else {
        controller.restore();
      }
    }
  }

  /// Restores any maximized pane.
  void restore() {
    for (final controller in _controllers) {
      controller.restore();
    }
  }

  /// Toggles between maximized and restored state for [pane].
  void toggleMaximize(IdePane pane) {
    if (maximizedPane == pane) {
      restore();
    } else {
      maximize(pane);
    }
  }

  /// Saves the current layout state (sizes and visibility) to a map.
  ///
  /// The [bottomLayout] itself is not saved; the state can be loaded into a
  /// controller using any [bottomLayout].
  Map<String, dynamic> save() {
    return {
      'root': rootController.save(),
      'center': centerController.save(),
      'top': topController.save(),
    };
  }

  /// Loads the layout state from a map.
  void load(Map<String, dynamic> data) {
    final rootState =
        data['root'] is Map ? Map<String, dynamic>.from(data['root']) : null;
    final topState =
        data['top'] is Map ? Map<String, dynamic>.from(data['top']) : null;
    if (rootState != null || topState != null) {
      rootController.load(_stateFor(rootController, [rootState, topState]));
      topController.load(_stateFor(topController, [topState, rootState]));
    }
    if (data.containsKey('center')) {
      centerController.load(Map<String, dynamic>.from(data['center']));
    }
  }

  /// Disposes the root, center, and top controllers.
  ///
  /// Call this when the [IdeController] is no longer needed to free resources.
  @override
  void dispose() {
    rootController.dispose();
    centerController.dispose();
    topController.dispose();
    super.dispose();
  }
}

/// Callback signature for when a pane's visibility state changes.
typedef IdePaneStateChangedCallback = void Function(
  IdePane pane,
  bool isVisible,
);

/// Callback signature for when the maximize state changes.
typedef IdeMaximizeStateChangedCallback = void Function(
  bool isMaximized,
);

/// Callback signature for when a pane's size changes.
typedef IdeSizeChangedCallback = void Function(
  IdePane pane,
  double size,
);

/// Builder for an IDE pane, exposing its animation progress (0.0 to 1.0).
typedef IdePaneBuilder = Widget Function(
    BuildContext context, double animationProgress);

/// A pre-configured layout widget that mimics a standard IDE.
///
/// It provides slots for [leftPanelBuilder], [rightPanelBuilder], [bottomPanelBuilder],
/// and [centerBuilder] (editor), managed by an [IdeController].
///
/// The placement of the bottom panel is controlled by
/// [IdeController.bottomLayout]. Panel state is preserved when it changes.
class IdeLayout extends StatefulWidget {
  /// The controller that manages the state of this layout.
  final IdeController controller;

  /// Builder for the left sidebar panel.
  final IdePaneBuilder? leftPanelBuilder;

  /// Builder for the right sidebar panel.
  final IdePaneBuilder? rightPanelBuilder;

  /// Builder for the bottom panel.
  final IdePaneBuilder? bottomPanelBuilder;

  /// Builder for the main center/editor area.
  final IdePaneBuilder? centerBuilder;

  /// Duration for panel resize/toggle animations.
  final Duration animationDuration;

  /// Callback invoked when any pane's visibility state changes.
  final IdePaneStateChangedCallback? onPaneStateChanged;

  /// Callback invoked when the maximize state changes.
  ///
  /// Returns true when the editor or the bottom panel is maximized to fill
  /// the whole layout (see [IdeController.maximizedPane]).
  final IdeMaximizeStateChangedCallback? onMaximizeStateChanged;

  /// Callback invoked when any pane's size changes.
  ///
  /// This is called whenever a pane is resized, providing realtime size updates.
  final IdeSizeChangedCallback? onSizeChanged;

  /// Creates an [IdeLayout].
  const IdeLayout({
    super.key,
    required this.controller,
    this.leftPanelBuilder,
    this.rightPanelBuilder,
    this.bottomPanelBuilder,
    this.centerBuilder,
    this.animationDuration = const Duration(milliseconds: 250),
    this.onPaneStateChanged,
    this.onMaximizeStateChanged,
    this.onSizeChanged,
  });

  @override
  State<IdeLayout> createState() => _IdeLayoutState();
}

class _IdeLayoutState extends State<IdeLayout> {
  late Map<String, bool> _previousVisibility;
  late bool _previousMaximized;
  late Map<String, double?> _previousSizes;

  // Keep pane contents alive when they move between rows on layout changes.
  final _leftKey = GlobalKey(debugLabel: 'IdeLayout.left');
  final _rightKey = GlobalKey(debugLabel: 'IdeLayout.right');
  final _bottomKey = GlobalKey(debugLabel: 'IdeLayout.bottom');
  final _centerKey = GlobalKey(debugLabel: 'IdeLayout.center');

  @override
  void initState() {
    super.initState();
    _previousVisibility = _captureVisibility();
    _previousMaximized = _isFullyMaximized();
    _previousSizes = _captureSizes();
    _addListeners(widget.controller);
  }

  @override
  void didUpdateWidget(IdeLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _removeListeners(oldWidget.controller);
      _previousVisibility = _captureVisibility();
      _previousMaximized = _isFullyMaximized();
      _previousSizes = _captureSizes();
      _addListeners(widget.controller);
    }
  }

  @override
  void dispose() {
    _removeListeners(widget.controller);
    super.dispose();
  }

  void _addListeners(IdeController controller) {
    controller.addListener(_onLayoutChanged);
    for (final paneController in controller._controllers) {
      paneController.addListener(_onControllerChanged);
    }
  }

  void _removeListeners(IdeController controller) {
    controller.removeListener(_onLayoutChanged);
    for (final paneController in controller._controllers) {
      paneController.removeListener(_onControllerChanged);
    }
  }

  Map<String, bool> _captureVisibility() {
    return {
      for (final pane in [
        IdePane.left,
        IdePane.right,
        IdePane.bottom,
        IdePane.center,
      ])
        pane.id: widget.controller.controllerOf(pane).isVisible(pane.id),
    };
  }

  Map<String, double?> _captureSizes() {
    return {
      for (final pane in [IdePane.left, IdePane.right, IdePane.bottom])
        pane.id:
            widget.controller.controllerOf(pane).getVisualPixelSize(pane.id),
    };
  }

  bool _isFullyMaximized() {
    return switch (widget.controller.maximizedPane) {
      IdePane.center || IdePane.bottom => true,
      _ => false,
    };
  }

  void _onLayoutChanged() {
    setState(() {});
    _onControllerChanged();
  }

  void _onControllerChanged() {
    _checkAndNotifyVisibilityChanges();
    _checkAndNotifyMaximizeChanges();
    _checkAndNotifySizeChanges();
  }

  void _checkAndNotifyVisibilityChanges() {
    final callback = widget.onPaneStateChanged;
    if (callback == null) return;

    final current = _captureVisibility();

    final leftVisible = current[IdePane.left.id];
    final rightVisible = current[IdePane.right.id];
    final bottomVisible = current[IdePane.bottom.id];
    final centerVisible = current[IdePane.center.id];

    if (leftVisible != _previousVisibility[IdePane.left.id] &&
        leftVisible != null) {
      callback(IdePane.left, leftVisible);
    }
    if (rightVisible != _previousVisibility[IdePane.right.id] &&
        rightVisible != null) {
      callback(IdePane.right, rightVisible);
    }
    if (bottomVisible != _previousVisibility[IdePane.bottom.id] &&
        bottomVisible != null) {
      callback(IdePane.bottom, bottomVisible);
    }
    if (centerVisible != _previousVisibility[IdePane.center.id] &&
        centerVisible != null) {
      callback(IdePane.center, centerVisible);
    }

    _previousVisibility = current;
  }

  void _checkAndNotifyMaximizeChanges() {
    final callback = widget.onMaximizeStateChanged;
    if (callback == null) return;

    final currentMaximized = _isFullyMaximized();
    if (currentMaximized != _previousMaximized) {
      callback(currentMaximized);
      _previousMaximized = currentMaximized;
    }
  }

  void _checkAndNotifySizeChanges() {
    final callback = widget.onSizeChanged;
    if (callback == null) return;

    final current = _captureSizes();

    final leftSize = current[IdePane.left.id];
    final rightSize = current[IdePane.right.id];
    final bottomSize = current[IdePane.bottom.id];

    if (leftSize != _previousSizes[IdePane.left.id] && leftSize != null) {
      callback(IdePane.left, leftSize);
    }
    if (rightSize != _previousSizes[IdePane.right.id] && rightSize != null) {
      callback(IdePane.right, rightSize);
    }
    if (bottomSize != _previousSizes[IdePane.bottom.id] && bottomSize != null) {
      callback(IdePane.bottom, bottomSize);
    }

    _previousSizes = current;
  }

  Widget _buildLeft(BuildContext context, double progress) => KeyedSubtree(
        key: _leftKey,
        child: widget.leftPanelBuilder?.call(context, progress) ??
            const SizedBox.shrink(),
      );

  Widget _buildRight(BuildContext context, double progress) => KeyedSubtree(
        key: _rightKey,
        child: widget.rightPanelBuilder?.call(context, progress) ??
            const SizedBox(),
      );

  Widget _buildBottom(BuildContext context, double progress) => KeyedSubtree(
        key: _bottomKey,
        child: widget.bottomPanelBuilder?.call(context, progress) ??
            const SizedBox(),
      );

  Widget _buildCenter(BuildContext context, double progress) => KeyedSubtree(
        key: _centerKey,
        child: widget.centerBuilder?.call(context, progress) ??
            const SizedBox.shrink(),
      );

  /// Builds a horizontal row of side panes around [middle].
  Widget _buildRow(PaneController controller, IdePaneBuilder middle) {
    return MultiPane(
      key: ObjectKey(controller),
      direction: Axis.horizontal,
      controller: controller,
      animationDuration: widget.animationDuration,
      paneBuilder: (context, id, progress) {
        if (id == IdePane.left.id) return _buildLeft(context, progress);
        if (id == IdePane.right.id) return _buildRight(context, progress);
        if (id == IdePane.centerContainer.id) return middle(context, progress);
        return const SizedBox();
      },
    );
  }

  /// Builds a vertical column of [top] above the bottom panel.
  Widget _buildColumn(IdePaneBuilder top) {
    final controller = widget.controller.centerController;
    return MultiPane(
      key: ObjectKey(controller),
      direction: Axis.vertical,
      controller: controller,
      animationDuration: widget.animationDuration,
      paneBuilder: (context, id, progress) {
        if (id == IdePane.center.id) return top(context, progress);
        if (id == IdePane.bottom.id) return _buildBottom(context, progress);
        return const SizedBox();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return switch (controller.bottomLayout) {
      // Left | (Editor / Bottom) | Right
      IdeBottomLayout.contained => _buildRow(
          controller.rootController,
          (_, __) => _buildColumn(_buildCenter),
        ),
      // (Left | Editor | Right) / Bottom
      IdeBottomLayout.fullWidth => _buildColumn(
          (_, __) => _buildRow(controller.rootController, _buildCenter),
        ),
      // ((Left | Editor) / Bottom) | Right, or Left | ((Editor | Right) / Bottom)
      IdeBottomLayout.extendLeft || IdeBottomLayout.extendRight => _buildRow(
          controller.rootController,
          (_, __) => _buildColumn(
            (_, __) => _buildRow(controller.topController, _buildCenter),
          ),
        ),
    };
  }
}
