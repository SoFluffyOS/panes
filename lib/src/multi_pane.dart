import 'package:flutter/material.dart';
import 'package:panes/src/pane_controller.dart';
import 'package:panes/src/pane_entry.dart';
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

  bool _isResizing = false;
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
                duration:
                    _isResizing ? Duration.zero : widget.animationDuration,
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
            bool resizerVisible =
                isVisible && widget.controller.isVisible(entries[i + 1].id);

            children.add(
              AnimatedContainer(
                duration:
                    _isResizing ? Duration.zero : widget.animationDuration,
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
                      _handleResize(entry, i, entries, delta);
                    },
                    onResizeStart: () {
                      setState(() => _isResizing = true);
                      // Save sizes for both adjacent panes in case of auto-hide
                      widget.controller.savePreDragSize(entry.id);
                      if (i + 1 < entries.length) {
                        widget.controller.savePreDragSize(entries[i + 1].id);
                      }
                    },
                    onResizeEnd: () {
                      setState(() => _isResizing = false);
                      // Clear saved sizes if not auto-hidden
                      widget.controller.clearPreDragSize(entry.id);
                      if (i + 1 < entries.length) {
                        widget.controller.clearPreDragSize(entries[i + 1].id);
                      }
                    },
                    onDoubleTap: () {
                      widget.controller.resetSize(entry.id);
                      if (i + 1 < entries.length) {
                        widget.controller.resetSize(entries[i + 1].id);
                      }
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
    PaneEntry entry,
    int entryIndex,
    List<PaneEntry> allEntries,
    double delta,
  ) {
    if (delta == 0) return;

    // 1. Pixel Resize
    double? currentPixel = widget.controller.getPixelSize(entry.id);
    if (currentPixel != null || entry.initialSize is PaneSizePixel) {
      double size = currentPixel ?? entry.initialSize.size;
      widget.controller.updateSize(entry.id, PaneSize.pixel(size + delta));
      return;
    }

    // 2. Fractional Resize
    if (entryIndex + 1 >= allEntries.length) return;
    final nextEntry = allEntries[entryIndex + 1];

    double? nextPixel = widget.controller.getPixelSize(nextEntry.id);
    if (nextPixel != null || nextEntry.initialSize is PaneSizePixel) {
      // Resize the NEXT pane, but with negative delta
      double size = nextPixel ?? nextEntry.initialSize.size;
      widget.controller.updateSize(nextEntry.id, PaneSize.pixel(size - delta));
      return;
    }

    // Case: Flex | Divider | Flex
    // We need to convert delta(pixels) to delta(flex).

    double totalFixedSize = 0;
    double totalFlexSum = 0;

    for (var e in allEntries) {
      double? p = widget.controller.getPixelSize(e.id);
      if (p != null) {
        totalFixedSize += p;
      } else if (e.initialSize case PaneSizePixel(:final pixels)) {
        totalFixedSize += pixels;
      } else {
        // Flex
        double? f = widget.controller.getFractionalSize(e.id);
        totalFlexSum += f ?? e.initialSize.size;
      }
    }

    double flexSpace = (widget.direction == Axis.horizontal
            ? _containerSize.width
            : _containerSize.height) -
        totalFixedSize;
    if (flexSpace <= 0) return;

    double deltaFlex = (delta * totalFlexSum) / flexSpace;

    // Enforce Constraints
    double currentFlex =
        widget.controller.getFractionalSize(entry.id) ?? entry.initialSize.size;
    double nextFlex = widget.controller.getFractionalSize(nextEntry.id) ??
        nextEntry.initialSize.size;

    // 1. Calculate Min Flex for Entry
    double entryMinFlex = 0;
    if (entry.minSize case final minSize?) {
      entryMinFlex = switch (minSize) {
        PaneSizePixel(:final pixels) => (pixels * totalFlexSum) / flexSpace,
        PaneSizeFraction(:final fraction) => fraction,
      };
    }

    // 2. Calculate Min Flex for Next Entry
    double nextEntryMinFlex = 0;
    if (nextEntry.minSize case final minSize?) {
      nextEntryMinFlex = switch (minSize) {
        PaneSizePixel(:final pixels) => (pixels * totalFlexSum) / flexSpace,
        PaneSizeFraction(:final fraction) => fraction,
      };
    }

    // 3. Clamp Delta
    double minDeltaFlex = entryMinFlex - currentFlex;
    double maxDeltaFlex = nextFlex - nextEntryMinFlex;

    if (deltaFlex < minDeltaFlex) deltaFlex = minDeltaFlex;
    if (deltaFlex > maxDeltaFlex) deltaFlex = maxDeltaFlex;
    widget.controller.updateSize(
      entry.id,
      PaneSize.fraction(currentFlex + deltaFlex),
    );

    // Update Next Entry
    widget.controller.updateSize(
      nextEntry.id,
      PaneSize.fraction(nextFlex - deltaFlex),
    );
  }
}
