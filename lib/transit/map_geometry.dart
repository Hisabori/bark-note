import 'dart:math' as math;
import 'kakao_api.dart';

class MapPoint {
  const MapPoint(this.x, this.y);
  final double x, y;
}

// Korea central-belt WTM: GRS80, lon0=127, lat0=38, k=1.
MapPoint projectWtm(RoutePoint point) {
  const a = 6378137.0, f = 1 / 298.257222101;
  const e2 = f * (2 - f), ep2 = e2 / (1 - e2);
  final lat = point.y * math.pi / 180;
  final lon = (point.x - 127) * math.pi / 180;
  final sin = math.sin(lat), cos = math.cos(lat), tan = math.tan(lat);
  final n = a / math.sqrt(1 - e2 * sin * sin);
  final t = tan * tan, c = ep2 * cos * cos, aa = lon * cos;
  double meridian(double v) =>
      a *
      ((1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * math.pow(e2, 3) / 256) * v -
          (3 * e2 / 8 + 3 * e2 * e2 / 32 + 45 * math.pow(e2, 3) / 1024) *
              math.sin(2 * v) +
          (15 * e2 * e2 / 256 + 45 * math.pow(e2, 3) / 1024) * math.sin(4 * v) -
          35 * math.pow(e2, 3) / 3072 * math.sin(6 * v));
  return MapPoint(
    200000 +
        n *
            (aa +
                (1 - t + c) * math.pow(aa, 3) / 6 +
                (5 - 18 * t + t * t + 72 * c - 58 * ep2) *
                    math.pow(aa, 5) /
                    120),
    500000 +
        meridian(lat) -
        meridian(38 * math.pi / 180) +
        n *
            tan *
            (aa * aa / 2 +
                (5 - t + 9 * c + 4 * c * c) * math.pow(aa, 4) / 24 +
                (61 - 58 * t + t * t + 600 * c - 330 * ep2) *
                    math.pow(aa, 6) /
                    720),
  );
}

class RouteViewport {
  RouteViewport(List<RoutePoint> points) {
    final projected = points.map(projectWtm).toList();
    final minX = projected.map((p) => p.x).reduce(math.min),
        maxX = projected.map((p) => p.x).reduce(math.max);
    final minY = projected.map((p) => p.y).reduce(math.min),
        maxY = projected.map((p) => p.y).reduce(math.max);
    geographicCenter = RoutePoint(
      (points.map((p) => p.x).reduce(math.min) +
              points.map((p) => p.x).reduce(math.max)) /
          2,
      (points.map((p) => p.y).reduce(math.min) +
              points.map((p) => p.y).reduce(math.max)) /
          2,
    );
    center = projectWtm(geographicCenter);
    final required = math.max(
      2 *
          math.max((maxX - center.x).abs(), (minX - center.x).abs()) /
          (width - 120),
      2 *
          math.max((maxY - center.y).abs(), (minY - center.y).abs()) /
          (height - 120),
    );
    var fittedLevel = 1;
    while (fittedLevel < 15 && math.pow(2, fittedLevel - 3) < required) {
      fittedLevel++;
    }
    level = fittedLevel;
  }
  static const width = 960.0, height = 640.0;
  late final MapPoint center;
  late final RoutePoint geographicCenter;
  late final int level;
  double get metresPerPixel => math.pow(2, level - 3).toDouble();
  MapPoint pixel(RoutePoint p) {
    final v = projectWtm(p);
    return MapPoint(
      width / 2 + (v.x - center.x) / metresPerPixel,
      height / 2 - (v.y - center.y) / metresPerPixel,
    );
  }

  Uri get uri => Uri.https('dapi.kakao.com', '/v2/maps/staticmap', {
    'center': '${geographicCenter.x},${geographicCenter.y}',
    'coord': 'WGS84',
    'size': '960x640',
    'scale': '1',
    'lv': '$level',
    'format': 'png',
    'logo_pos': 'BOTTOM_LEFT',
  });
}
