import 'package:flutter_test/flutter_test.dart';
import 'package:panes/panes.dart';

void main() {
  test('PaneSize creation', () {
    final pixel = PaneSize.pixel(100);
    expect(pixel, isA<PaneSizePixel>());
    expect(pixel.size, 100);

    final fraction = PaneSize.fraction(0.5);
    expect(fraction, isA<PaneSizeFraction>());
    expect(fraction.size, 0.5);
  });

  test('PaneController visibility', () {
    final controller = PaneController(
      entries: [
        PaneEntry(id: '1', initialSize: PaneSize.pixel(100)),
      ],
    );

    expect(controller.isVisible('1'), isTrue);
    controller.hide('1');
    expect(controller.isVisible('1'), isFalse);
    controller.show('1');
    expect(controller.isVisible('1'), isTrue);
  });

  test('PaneController constraints', () {
    final controller = PaneController(
      entries: [
        PaneEntry(
          id: '1',
          initialSize: PaneSize.pixel(100),
          minSize: PaneSize.pixel(50),
        ),
      ],
    );

    // Try setting negative
    controller.updateSize('1', PaneSize.pixel(-10));
    expect(controller.getPixelSize('1'), 50); // Should clamp to minSize

    // Try setting valid
    controller.updateSize('1', PaneSize.pixel(200));
    expect(controller.getPixelSize('1'), 200);
  });

  test('PaneController auto-hide', () {
    final controller = PaneController(
      entries: [
        PaneEntry(
          id: '1',
          initialSize: PaneSize.pixel(100),
          autoHide: true,
          autoHideThreshold: 50,
        ),
      ],
    );

    // Resize down to 60 -> OK
    controller.updateSize('1', PaneSize.pixel(60));
    expect(controller.getPixelSize('1'), 60);
    expect(controller.isVisible('1'), isTrue);

    // Resize down to 40 -> Auto-Hide
    controller.updateSize('1', PaneSize.pixel(40));
    expect(controller.isVisible('1'), isFalse);
  });

  test('PaneController reset', () {
    final controller = PaneController(
      entries: [
        PaneEntry(id: '1', initialSize: PaneSize.pixel(100)),
      ],
    );

    // Override
    controller.updateSize('1', PaneSize.pixel(200));
    expect(controller.getPixelSize('1'), 200);

    // Reset
    controller.resetSize('1');
    expect(controller.getPixelSize('1'), isNull); // Falls back to initial in UI
  });

  test('PaneController serialization', () {
    final controller = PaneController(
      entries: [
        PaneEntry(id: '1', initialSize: PaneSize.pixel(100)),
        PaneEntry(id: '2', initialSize: PaneSize.fraction(1.0)),
      ],
    );

    // Modify state
    controller.updateSize('1', PaneSize.pixel(150));
    controller.hide('1');

    // Save
    final data = controller.save();

    // Create new controller (simulate restart)
    final newController = PaneController(
      entries: [
        PaneEntry(id: '1', initialSize: PaneSize.pixel(100)),
        PaneEntry(id: '2', initialSize: PaneSize.fraction(1.0)),
      ],
    );

    // Load
    newController.load(data);

    // Verify
    expect(newController.getPixelSize('1'), 150);
    expect(newController.isVisible('1'), isFalse);
  });
}
