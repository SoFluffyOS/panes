import 'package:flutter/material.dart';
import 'package:panes/src/pane_controller.dart';
import 'package:panes/src/pane_size.dart';
import 'package:panes/src/pane_theme.dart';
import 'package:panes/src/resizer.dart';

/// Builder function for creating the widget content of a pane.
typedef PaneBuilder = Widget Function(BuildContext context, String paneId);

/// A widget that displays multiple resizable panes in a row or column.
///
/// It listens to a [PaneController] for changes in pane sizes and visibility.
class MultiPane extends StatefulWidget {
  /// The direction of the layout (horizontal or vertical).
  final Axis direction;

  /// The controller that manages the state of the panes.
  final PaneController controller;

  /// The builder used to create the widget for each pane.
  final PaneBuilder paneBuilder;

  /// The duration of the animation when panes are resized or toggled.
  final Duration animationDuration;

  /// The curve of the animation when panes are resized or toggled.
  final Curve animationCurve;

  /// Creates a [MultiPane].
  const MultiPane({
    super.key,
    required this.direction,
    required this.controller,
    required this.paneBuilder,
    this.animationDuration = const Duration(milliseconds: 250),
    this.animationCurve = Curves.easeInOut,
  });

  @override
  State<MultiPane> createState() => _MultiPaneState();
}

class _MultiPaneState extends State<MultiPane> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(MultiPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    setState(() {});
  }

  Size _containerSize = Size.zero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _containerSize = constraints.biggest;

        // Iterate ALL entries to enable animation even for hidden ones
        final entries = widget.controller.entries;

        // Check for Maximized Pane
        if (widget.controller.maximizedPaneId case final maxId?) {
          final childWidget = widget.paneBuilder(context, maxId);
          return SizedBox(
            width: _containerSize.width,
            height: _containerSize.height,
            child: childWidget,
          );
        }

        if (entries.isEmpty) return const SizedBox.shrink();

        final children = <Widget>[];

        // Get resizer thickness from theme
        final theme = PaneTheme.of(context);
        final resizerSize = theme.resizerHitTestThickness;

        // Use controller's isResizing state
        final isResizing = widget.controller.isResizing;

        for (int i = 0; i < entries.length; i++) {
          final entry = entries[i];
          final isVisible = widget.controller.isVisible(entry.id);
          final childWidget = widget.paneBuilder(context, entry.id);

          // Determine effective size (visual)
          double? pixelSize = widget.controller.getVisualPixelSize(entry.id);
          double? fractionalSize = widget.controller.getFractionalSize(
            entry.id,
          );

          PaneSize effectiveSize;
          if (pixelSize != null) {
            effectiveSize = PaneSize.pixel(pixelSize);
          } else if (fractionalSize != null) {
            effectiveSize = PaneSize.fraction(fractionalSize);
          } else {
            effectiveSize = entry.initialSize;
          }

          Widget wrappedChild = switch (effectiveSize) {
            PaneSizePixel(:final pixels) => AnimatedContainer(
                duration: isResizing ? Duration.zero : widget.animationDuration,
                curve: widget.animationCurve,
                width: widget.direction == Axis.horizontal
                    ? (isVisible ? pixels : 0)
                    : null,
                height: widget.direction == Axis.vertical
                    ? (isVisible ? pixels : 0)
                    : null,
                child: SingleChildScrollView(
                  scrollDirection: widget.direction,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: widget.direction == Axis.horizontal ? pixels : null,
                    height: widget.direction == Axis.vertical ? pixels : null,
                    child: childWidget,
                  ),
                ),
              ),
            PaneSizeFraction(:final fraction) => isVisible
                ? Expanded(
                    flex:
                        ((fraction.isNaN || fraction.isInfinite || fraction < 0
                                    ? 0
                                    : fraction) *
                                100)
                            .toInt(),
                    child: childWidget,
                  )
                : const SizedBox.shrink(),
          };

          children.add(wrappedChild);

          // Add resizer if not last
          if (i < entries.length - 1) {
            final nextEntry = entries[i + 1];
            final nextVisible = widget.controller.isVisible(nextEntry.id);

            // Resizer is visible if:
            // 1. Both adjacent panes are visible, OR
            // 2. We're actively resizing (to support drag-to-reveal), OR
            // 3. One pane is hidden with autoHide (edge drag to reveal)
            final bool edgeDragReveal = (entry.autoHide && !isVisible) ||
                (nextEntry.autoHide && !nextVisible);

            bool resizerVisible =
                (isVisible && nextVisible) || isResizing || edgeDragReveal;

            children.add(
              AnimatedContainer(
                duration: isResizing ? Duration.zero : widget.animationDuration,
                curve: widget.animationCurve,
                width: widget.direction == Axis.horizontal
                    ? (resizerVisible ? resizerSize : 0)
                    : null,
                height: widget.direction == Axis.vertical
                    ? (resizerVisible ? resizerSize : 0)
                    : null,
                child: OverflowBox(
                  maxWidth:
                      widget.direction == Axis.horizontal ? resizerSize : null,
                  maxHeight:
                      widget.direction == Axis.vertical ? resizerSize : null,
                  child: Resizer(
                    direction: widget.direction,
                    onResize: (delta) {
                      _handleResize(entry.id, nextEntry.id, delta, resizerSize);
                    },
                    onResizeStart: () {
                      widget.controller.beginResize(
                        entry.id,
                        adjacentPaneId: nextEntry.id,
                      );
                    },
                    onResizeEnd: () {
                      widget.controller.endResize(
                        entry.id,
                        adjacentPaneId: nextEntry.id,
                      );
                    },
                    onDoubleTap: () {
                      widget.controller.resetSize(entry.id);
                      widget.controller.resetSize(nextEntry.id);
                    },
                  ),
                ),
              ),
            );
          }
        }

        return Flex(
          direction: widget.direction,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  void _handleResize(
    String paneId,
    String adjacentPaneId,
    double delta,
    double resizerSize,
  ) {
    final containerSize = widget.direction == Axis.horizontal
        ? _containerSize.width
        : _containerSize.height;

    widget.controller.resize(
      paneId: paneId,
      delta: delta,
      containerSize: containerSize,
      resizerThickness: resizerSize,
      adjacentPaneId: adjacentPaneId,
    );
  }
}
