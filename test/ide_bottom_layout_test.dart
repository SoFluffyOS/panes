import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panes/panes.dart';

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Text('$count');
}

void main() {
  IdeController createController(IdeBottomLayout layout) => IdeController(
        bottomLayout: layout,
        leftSize: PaneSize.pixel(200),
        rightSize: PaneSize.pixel(200),
        rightVisible: true,
        bottomSize: PaneSize.pixel(200),
        bottomVisible: true,
      );

  Future<void> pumpLayout(WidgetTester tester, IdeController controller) {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 1000,
              height: 800,
              child: PaneTheme(
                data: const PaneThemeData(resizerThickness: 0),
                child: IdeLayout(
                  controller: controller,
                  leftPanelBuilder: (context, progress) =>
                      const _Counter(key: Key('left')),
                  rightPanelBuilder: (context, progress) =>
                      Container(key: const Key('right')),
                  bottomPanelBuilder: (context, progress) =>
                      Container(key: const Key('bottom')),
                  centerBuilder: (context, progress) =>
                      Container(key: const Key('center')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect rectOf(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(Key(key)));

  group('IdeBottomLayout geometry', () {
    testWidgets('contained keeps bottom panel between side panes',
        (tester) async {
      await pumpLayout(tester, createController(IdeBottomLayout.contained));
      await tester.pumpAndSettle();

      expect(rectOf(tester, 'bottom'), const Rect.fromLTRB(200, 600, 800, 800));
      expect(rectOf(tester, 'left'), const Rect.fromLTRB(0, 0, 200, 800));
      expect(rectOf(tester, 'right'), const Rect.fromLTRB(800, 0, 1000, 800));
    });

    testWidgets('fullWidth spans bottom panel under both side panes',
        (tester) async {
      await pumpLayout(tester, createController(IdeBottomLayout.fullWidth));
      await tester.pumpAndSettle();

      expect(rectOf(tester, 'bottom'), const Rect.fromLTRB(0, 600, 1000, 800));
      expect(rectOf(tester, 'left'), const Rect.fromLTRB(0, 0, 200, 600));
      expect(rectOf(tester, 'right'), const Rect.fromLTRB(800, 0, 1000, 600));
      expect(rectOf(tester, 'center'), const Rect.fromLTRB(200, 0, 800, 600));
    });

    testWidgets('extendLeft spans bottom panel under the left pane',
        (tester) async {
      await pumpLayout(tester, createController(IdeBottomLayout.extendLeft));
      await tester.pumpAndSettle();

      expect(rectOf(tester, 'bottom'), const Rect.fromLTRB(0, 600, 800, 800));
      expect(rectOf(tester, 'left'), const Rect.fromLTRB(0, 0, 200, 600));
      expect(rectOf(tester, 'right'), const Rect.fromLTRB(800, 0, 1000, 800));
    });

    testWidgets('extendRight spans bottom panel under the right pane',
        (tester) async {
      await pumpLayout(tester, createController(IdeBottomLayout.extendRight));
      await tester.pumpAndSettle();

      expect(
          rectOf(tester, 'bottom'), const Rect.fromLTRB(200, 600, 1000, 800));
      expect(rectOf(tester, 'left'), const Rect.fromLTRB(0, 0, 200, 800));
      expect(rectOf(tester, 'right'), const Rect.fromLTRB(800, 0, 1000, 600));
    });
  });

  group('IdeController.bottomLayout', () {
    test('moves side panes between root and top controllers', () {
      final controller = createController(IdeBottomLayout.contained);
      expect(controller.controllerOf(IdePane.left),
          same(controller.rootController));
      expect(controller.topController.entries, isEmpty);

      controller.bottomLayout = IdeBottomLayout.extendLeft;
      expect(controller.controllerOf(IdePane.left),
          same(controller.topController));
      expect(controller.rootController.entries.map((e) => e.id),
          [IdePane.centerContainer.id, IdePane.right.id]);
      expect(controller.topController.entries.map((e) => e.id),
          [IdePane.left.id, IdePane.centerContainer.id]);

      controller.bottomLayout = IdeBottomLayout.extendRight;
      expect(controller.controllerOf(IdePane.right),
          same(controller.topController));
      expect(controller.rootController.entries.map((e) => e.id),
          [IdePane.left.id, IdePane.centerContainer.id]);
      expect(controller.topController.entries.map((e) => e.id),
          [IdePane.centerContainer.id, IdePane.right.id]);

      controller.bottomLayout = IdeBottomLayout.fullWidth;
      expect(controller.rootController.entries.map((e) => e.id), [
        IdePane.left.id,
        IdePane.centerContainer.id,
        IdePane.right.id,
      ]);
      expect(controller.topController.entries, isEmpty);
    });

    test('preserves side pane size and visibility when switching', () {
      final controller = createController(IdeBottomLayout.contained);
      controller.rootController.updateSize(
        IdePane.left.id,
        PaneSize.pixel(320),
      );
      controller.toggleRight();

      controller.bottomLayout = IdeBottomLayout.extendLeft;
      expect(
        controller.topController.getPixelSize(IdePane.left.id),
        320,
      );
      expect(controller.rootController.isVisible(IdePane.right.id), isFalse);

      controller.bottomLayout = IdeBottomLayout.extendRight;
      expect(
        controller.rootController.getPixelSize(IdePane.left.id),
        320,
      );
      expect(controller.topController.isVisible(IdePane.right.id), isFalse);

      controller.toggleRight();
      expect(controller.topController.isVisible(IdePane.right.id), isTrue);
    });

    test('notifies listeners only when the layout changes', () {
      final controller = createController(IdeBottomLayout.contained);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.bottomLayout = IdeBottomLayout.contained;
      expect(notifications, 0);

      controller.bottomLayout = IdeBottomLayout.fullWidth;
      expect(notifications, 1);
    });

    testWidgets('keeps pane widget state when switching', (tester) async {
      final controller = createController(IdeBottomLayout.contained);
      await pumpLayout(tester, controller);
      await tester.pumpAndSettle();

      tester.state<_CounterState>(find.byKey(const Key('left'))).count = 42;

      for (final layout in IdeBottomLayout.values) {
        controller.bottomLayout = layout;
        await tester.pumpAndSettle();
        expect(
          tester.state<_CounterState>(find.byKey(const Key('left'))).count,
          42,
          reason: 'after switching to $layout',
        );
      }
    });

    testWidgets('relayouts when switched at runtime', (tester) async {
      final controller = createController(IdeBottomLayout.contained);
      await pumpLayout(tester, controller);
      await tester.pumpAndSettle();

      controller.bottomLayout = IdeBottomLayout.fullWidth;
      await tester.pumpAndSettle();
      expect(rectOf(tester, 'bottom'), const Rect.fromLTRB(0, 600, 1000, 800));

      controller.bottomLayout = IdeBottomLayout.extendLeft;
      await tester.pumpAndSettle();
      expect(rectOf(tester, 'bottom'), const Rect.fromLTRB(0, 600, 800, 800));
    });

    testWidgets('does not report visibility changes when switching',
        (tester) async {
      final controller = createController(IdeBottomLayout.contained);
      final changes = <IdePane>[];
      await tester.pumpWidget(
        MaterialApp(
          home: IdeLayout(
            controller: controller,
            onPaneStateChanged: (pane, isVisible) => changes.add(pane),
          ),
        ),
      );

      for (final layout in IdeBottomLayout.values) {
        controller.bottomLayout = layout;
        await tester.pumpAndSettle();
      }

      expect(changes, isEmpty);
    });
  });

  group('IdeController maximize', () {
    for (final layout in IdeBottomLayout.values) {
      for (final pane in [
        IdePane.center,
        IdePane.bottom,
        IdePane.left,
        IdePane.right,
      ]) {
        testWidgets('$pane fills the $layout layout', (tester) async {
          final controller = createController(layout);
          await pumpLayout(tester, controller);
          await tester.pumpAndSettle();

          controller.maximize(pane);
          await tester.pumpAndSettle();

          expect(controller.maximizedPane, pane);
          expect(rectOf(tester, pane.id), const Rect.fromLTRB(0, 0, 1000, 800));
          for (final other in [
            IdePane.center,
            IdePane.bottom,
            IdePane.left,
            IdePane.right,
          ]) {
            if (other == pane) continue;
            expect(find.byKey(Key(other.id)), findsNothing);
          }

          controller.toggleMaximize(pane);
          await tester.pumpAndSettle();
          expect(controller.maximizedPane, isNull);
          expect(find.byKey(Key(pane == IdePane.left ? 'right' : 'left')),
              findsOneWidget);
        });
      }
    }

    test('switching layout restores maximized pane', () {
      final controller = createController(IdeBottomLayout.contained);
      controller.maximize(IdePane.center);
      expect(controller.maximizedPane, IdePane.center);

      controller.bottomLayout = IdeBottomLayout.extendLeft;
      expect(controller.maximizedPane, isNull);
    });

    test('maximizing another pane replaces the maximized pane', () {
      final controller = createController(IdeBottomLayout.extendRight);
      controller.maximize(IdePane.center);
      controller.maximize(IdePane.left);
      expect(controller.maximizedPane, IdePane.left);
    });
  });

  group('IdeController save/load', () {
    test('loads state saved with a different bottom layout', () {
      final source = createController(IdeBottomLayout.extendLeft);
      source.topController.updateSize(IdePane.left.id, PaneSize.pixel(320));
      source.toggleRight();
      final saved = source.save();

      final target = createController(IdeBottomLayout.contained);
      target.load(saved);
      expect(target.rootController.getPixelSize(IdePane.left.id), 320);
      expect(target.rootController.isVisible(IdePane.right.id), isFalse);

      final target2 = createController(IdeBottomLayout.extendLeft);
      target2.load(saved);
      expect(target2.topController.getPixelSize(IdePane.left.id), 320);
    });

    test('loads state saved before bottom layouts existed', () {
      final saved = {
        'root': {
          'pixelSizes': {'left': 320.0},
          'fractionalSizes': <String, double>{},
          'overrides': {'right': false},
        },
        'center': {
          'pixelSizes': <String, double>{},
          'fractionalSizes': <String, double>{},
          'overrides': <String, bool>{},
        },
      };

      final controller = createController(IdeBottomLayout.extendLeft);
      controller.load(saved);
      expect(controller.topController.getPixelSize(IdePane.left.id), 320);
      expect(controller.rootController.isVisible(IdePane.right.id), isFalse);
    });
  });
}
