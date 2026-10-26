import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panes/panes.dart';

void main() {
  for (final disableAnimations in [false, true]) {
    testWidgets(
        'hiding a pane animates unless animations are disabled '
        '(disableAnimations: $disableAnimations)', (tester) async {
      final controller = PaneController(
        entries: [
          PaneEntry(id: 'a', initialSize: PaneSize.pixel(100)),
          PaneEntry(id: 'b', initialSize: PaneSize.fraction(1.0)),
        ],
      );
      addTearDown(controller.dispose);
      final progressOf = <String, double>{};

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: MultiPane(
              direction: Axis.horizontal,
              controller: controller,
              paneBuilder: (context, id, progress) {
                progressOf[id] = progress;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      expect(progressOf['a'], 1.0);

      controller.hide('a');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      if (disableAnimations) {
        expect(progressOf['a'], 0.0);
      } else {
        expect(progressOf['a'], allOf(greaterThan(0.0), lessThan(1.0)));
      }
      await tester.pumpAndSettle();
      expect(progressOf['a'], 0.0);
    });
  }
}
