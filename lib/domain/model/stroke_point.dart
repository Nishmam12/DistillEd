// A single point in a stroke with x, y coordinates and stylus pressure.

class StrokePoint {
  final double x;
  final double y;
  final double pressure;
  // True when hardware does not supply real pressure (defaults to 0.5).
  // Mirrors Excalidraw's simulatePressure flag — lets perfect_freehand
  // generate its own thinning curve instead of using the flat 0.5 value.
  final bool simulatePressure;
  // Capture time in milliseconds (monotonic — from the pointer event's engine
  // timestamp, not wall clock; only deltas are meaningful). Null for points
  // written before this field existed (legacy .ink files) — handwriting
  // recognition synthesizes timestamps for those at read time.
  final int? t;
  // How far a stylus leaned from upright, in radians: 0 upright (and for a
  // finger, or a point from before tilt was kept) up to pi/2 flat. The
  // shading pencil draws broader the flatter it is held.
  final double tilt;

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
    this.simulatePressure = false,
    this.t,
    this.tilt = 0,
  });

  /// Creates a StrokePoint from a map (for deserialization).
  factory StrokePoint.fromMap(Map<String, dynamic> map) {
    return StrokePoint(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      pressure: (map['p'] as num?)?.toDouble() ?? 0.5,
      simulatePressure: map['sim'] as bool? ?? false,
      t: (map['t'] as num?)?.toInt(),
      tilt: (map['tilt'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Converts this point to a map (for serialization). `t` is omitted when
  /// null so legacy files stay byte-identical and old app versions (which
  /// ignore unknown keys) can still read new files.
  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'p': pressure,
      if (simulatePressure) 'sim': true,
      if (t != null) 't': t,
      if (tilt != 0) 'tilt': tilt,
    };
  }

  StrokePoint copyWith({
    double? x,
    double? y,
    double? pressure,
    bool? simulatePressure,
    int? t,
    double? tilt,
  }) {
    return StrokePoint(
      x: x ?? this.x,
      y: y ?? this.y,
      pressure: pressure ?? this.pressure,
      simulatePressure: simulatePressure ?? this.simulatePressure,
      t: t ?? this.t,
      tilt: tilt ?? this.tilt,
    );
  }

}

/// How long before the pen lifted at [upMs] the stroke of [points] began, in
/// ms. Point times are on the pointer events' own clock, which only compares
/// with itself: anything outside the stroke (a recording's start, say) must
/// work from this age and its own clock's "now", never from a point's time.
/// 0 when the times are missing.
int strokeAgeMs(List<StrokePoint> points, int? upMs) {
  if (points.isEmpty) return 0;
  final first = points.first.t;
  final up = upMs ?? points.last.t;
  if (first == null || up == null || up < first) return 0;
  return up - first;
}
