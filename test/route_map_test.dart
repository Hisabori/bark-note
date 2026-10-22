import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/transit/kakao_api.dart';
import 'package:bark_note/transit/map_geometry.dart';

void main() {
  test('bus vehicles, stops, type and precise path survive parsing', () {
    final route = KakaoRoute.fromJson({
      'properties': {'type': 'BUS_AND_SUBWAY', 'totalTime': 600},
      'steps': [
        {
          'properties': {
            'type': 'BUS',
            'guidance': '간선 402 탑승',
            'time': 300,
            'vehicles': [
              {'name': '402'},
            ],
            'stops': [
              {'name': '서울역'},
              {'name': '남산'},
            ],
          },
          'path': {
            'points': [
              [126.97, 37.55],
              [126.98, 37.54],
              ['bad', 37],
              [127.0, 37.53],
            ],
          },
        },
      ],
    });
    expect(route.hasBus, isTrue);
    expect(route.legs.single.vehicles, ['402']);
    expect(route.legs.single.stops, ['서울역', '남산']);
    expect(route.legs.single.points[0]!.x, 126.97);
    expect(route.legs.single.points[0]!.y, 37.55);
    expect(route.legs.single.points[2], isNull);
    expect(route.legs.single.points[3]!.x, 127);
  });
  test('WTM origin and screen north agree and full route fits safely', () {
    final origin = projectWtm(const RoutePoint(127, 38));
    expect(origin.x, closeTo(200000, 0.001));
    expect(origin.y, closeTo(500000, 0.001));
    final points = [
      const RoutePoint(126.97, 37.55),
      const RoutePoint(127.03, 37.50),
    ];
    final viewport = RouteViewport(points);
    for (final p in points) {
      final pixel = viewport.pixel(p);
      expect(pixel.x, inInclusiveRange(50, 910));
      expect(pixel.y, inInclusiveRange(50, 590));
    }
    expect(
      viewport.pixel(points.first).y,
      lessThan(viewport.pixel(points.last).y),
    );
    expect(viewport.uri.queryParameters['coord'], 'WTM');
    expect(viewport.uri.queryParameters['scale'], '1');
    expect(viewport.uri.queryParameters.containsKey('key'), isFalse);
  });
}
