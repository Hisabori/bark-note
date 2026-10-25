import 'dart:math' as math;
import 'kakao_api.dart';
import 'map_geometry.dart';

class PlaceMapCamera {
  const PlaceMapCamera(this.center, {this.level = 5});
  final KakaoPlace center;
  final int level;
  static const width = 960.0, height = 640.0;
  double get metresPerPixel => math.pow(2, level - 3).toDouble();
  PlaceMapCamera zoom(int delta) =>
      PlaceMapCamera(center, level: (level + delta).clamp(1, 15));
  PlaceMapCamera move(double east, double north) {
    final metres = width * metresPerPixel / 4;
    final latitude = (center.y + north * metres / 111320).clamp(-85.0, 85.0);
    final longitude =
        (center.x +
                east * metres / (111320 * math.cos(center.y * math.pi / 180)))
            .clamp(-180.0, 180.0);
    return PlaceMapCamera(
      KakaoPlace('지도 중심', '', longitude, latitude),
      level: level,
    );
  }

  MapPoint pixel(KakaoPlace place) {
    final c = projectWtm(RoutePoint(center.x, center.y));
    final p = projectWtm(RoutePoint(place.x, place.y));
    return MapPoint(
      width / 2 + (p.x - c.x) / metresPerPixel,
      height / 2 - (p.y - c.y) / metresPerPixel,
    );
  }

  Uri get uri => Uri.https('dapi.kakao.com', '/v2/maps/staticmap', {
    'center': '${center.x},${center.y}',
    'coord': 'WGS84',
    'size': '960x640',
    'scale': '1',
    'lv': '$level',
    'format': 'png',
    'logo_pos': 'BOTTOM_LEFT',
  });
}
