import 'package:flutter/material.dart';

class ShapeGeometry {
  static Rect boundingRect(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static Offset centroid(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    double sumX = 0;
    double sumY = 0;
    for (final p in points) {
      sumX += p.dx;
      sumY += p.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  static Rect rectFromGeometry(List<double> data) {
    if (data.length < 4) return Rect.zero;
    return Rect.fromLTRB(data[0], data[1], data[2], data[3]);
  }

  static (Offset, Offset) lineFromGeometry(List<double> data) {
    if (data.length < 4) return (Offset.zero, Offset.zero);
    return (Offset(data[0], data[1]), Offset(data[2], data[3]));
  }

  static List<Offset> verticesFromGeometry(List<double> data) {
    final List<Offset> vertices = [];
    for (int i = 0; i < data.length - 1; i += 2) {
      vertices.add(Offset(data[i], data[i + 1]));
    }
    return vertices;
  }
}
