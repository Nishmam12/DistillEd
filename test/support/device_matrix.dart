// Popular Android viewports, in logical pixels (dp), for responsive tests.
//
// Sizes are the portrait dp of common devices; `landscape` flips them. The set
// deliberately spans the three Material window-size classes (compact < 600,
// medium 600–839, expanded ≥ 840) and includes the awkward ones: a very small
// older phone, a foldable's narrow cover screen and square-ish inner screen, and
// large tablets.

import 'dart:ui';

class TestDevice {
  const TestDevice(this.name, this.width, this.height);

  final String name;
  final double width;
  final double height;

  Size get portrait => Size(width, height);
  Size get landscape => Size(height, width);

  @override
  String toString() => '$name ${width.toInt()}x${height.toInt()}';
}

const androidDevices = <TestDevice>[
  // Phones.
  TestDevice('Small phone (older)', 320, 568),
  TestDevice('Compact phone', 360, 640),
  TestDevice('Galaxy A / Redmi 360x800', 360, 800),
  TestDevice('Pixel 7 / 8', 412, 915),
  TestDevice('Galaxy S24 Ultra', 412, 915),
  TestDevice('Pixel 8 Pro / large', 448, 998),
  // Foldables.
  TestDevice('Galaxy Z Fold cover', 346, 832),
  TestDevice('Galaxy Z Fold inner', 673, 841),
  TestDevice('Pixel Fold inner', 841, 701),
  // Tablets.
  TestDevice('7-8" tablet', 600, 960),
  TestDevice('Galaxy Tab A / 10" tablet', 800, 1280),
  TestDevice('Galaxy Tab S9 Ultra', 924, 1480),
];

/// Accessibility font scales worth exercising.
const textScales = <double>[1.0, 1.3, 2.0];
