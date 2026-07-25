import 'dart:math';
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

  static List<Offset> rdpSimplify(List<Offset> points, double epsilon) {
    if (points.length < 3) return points;

    double dmax = 0;
    int index = 0;
    final int end = points.length - 1;

    for (int i = 1; i < end; i++) {
      double d = _perpendicularDistance(points[i], points[0], points[end]);
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }

    if (dmax > epsilon) {
      final List<Offset> recResults1 = rdpSimplify(points.sublist(0, index + 1), epsilon);
      final List<Offset> recResults2 = rdpSimplify(points.sublist(index, end + 1), epsilon);

      final List<Offset> result = List.from(recResults1);
      result.removeLast();
      result.addAll(recResults2);
      return result;
    } else {
      return [points[0], points[end]];
    }
  }

  static double _perpendicularDistance(Offset point, Offset lineStart, Offset lineEnd) {
    final double dx = lineEnd.dx - lineStart.dx;
    final double dy = lineEnd.dy - lineStart.dy;

    if (dx == 0 && dy == 0) {
      return (point - lineStart).distance;
    }

    final double num = (dy * point.dx - dx * point.dy + lineEnd.dx * lineStart.dy - lineEnd.dy * lineStart.dx).abs();
    final double den = sqrt(dx * dx + dy * dy);
    return num / den;
  }

  static bool isClosed(List<Offset> points, double closeThreshold) {
    if (points.length < 3) return false;
    return (points.first - points.last).distance <= closeThreshold;
  }

  static double linearR2(List<Offset> points) {
    if (points.length < 2) return 0.0;

    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;
    final int n = points.length;

    for (final p in points) {
      sumX += p.dx;
      sumY += p.dy;
      sumXY += p.dx * p.dy;
      sumX2 += p.dx * p.dx;
      sumY2 += p.dy * p.dy;
    }

    final double num = (n * sumXY - sumX * sumY);
    final double den1 = (n * sumX2 - sumX * sumX);
    final double den2 = (n * sumY2 - sumY * sumY);

    if (den1 == 0 || den2 == 0) {
      // Perfect vertical or horizontal line
      return 1.0; 
    }

    final double r = num / sqrt(den1 * den2);
    return r * r;
  }

  static double angleBetween(Offset a, Offset vertex, Offset b) {
    final Offset v1 = a - vertex;
    final Offset v2 = b - vertex;

    final double dotProduct = v1.dx * v2.dx + v1.dy * v2.dy;
    final double magnitude1 = v1.distance;
    final double magnitude2 = v2.distance;

    if (magnitude1 == 0 || magnitude2 == 0) return 0.0;

    double cosTheta = dotProduct / (magnitude1 * magnitude2);
    // Clamp to handle floating point inaccuracies
    if (cosTheta < -1.0) cosTheta = -1.0;
    if (cosTheta > 1.0) cosTheta = 1.0;

    return acos(cosTheta);
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
