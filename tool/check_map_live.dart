import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bark_note/transit/kakao_api.dart';
import 'package:bark_note/transit/map_geometry.dart';

Future<void> main() async {
  final key = Platform.environment['KAKAO_KEY'] ?? '';
  final api = KakaoApi(key);
  for (final p in [
    const RoutePoint(127, 38),
    const RoutePoint(126.972, 37.555),
    const RoutePoint(129.07, 35.18),
    const RoutePoint(126.53, 33.5),
  ]) {
    final response = await api.get('/v2/local/geo/transcoord.json', {
      'x': '${p.x}',
      'y': '${p.y}',
      'input_coord': 'WGS84',
      'output_coord': 'WTM',
    });
    final reference = response['documents'][0] as Map;
    final actual = projectWtm(p);
    if ((actual.x - (reference['x'] as num)).abs() > 0.25 ||
        (actual.y - (reference['y'] as num)).abs() > 0.25) {
      throw StateError(
        'WTM projection differs from official API: ${p.x},${p.y}: ${actual.x},${actual.y} versus $reference',
      );
    }
  }
  stdout.writeln(
    'Local WTM projection: official API agreement within 0.25 metre at four locations',
  );
  const start = KakaoPlace('서울역', '', 126.972, 37.555),
      end = KakaoPlace('강남역', '', 127.027, 37.498);
  final routes = await api.routes(start, end);
  final bus = routes.firstWhere(
    (r) => r.hasBus && r.legs.any((s) => s.points.length >= 2),
  );
  final points = bus.legs
      .expand((s) => s.points.whereType<RoutePoint>())
      .toList();
  final viewport = RouteViewport([
    ...points,
    RoutePoint(start.x, start.y),
    RoutePoint(end.x, end.y),
  ]);
  final client = HttpClient();
  try {
    final request = await client.getUrl(viewport.uri);
    request.headers.set('Authorization', 'KakaoAK $key');
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Kakao static map HTTP ${response.statusCode}');
    }
    final bytes = await response.fold<List<int>>(
      [],
      (all, data) => all..addAll(data),
    );
    if (bytes.length < 24 || bytes[0] != 137 || bytes[1] != 80) {
      throw StateError('Map is not PNG');
    }
    final header = ByteData.sublistView(Uint8List.fromList(bytes));
    if (header.getUint32(16) != 960 || header.getUint32(20) != 640) {
      throw StateError('Unexpected static map dimensions');
    }
    final folder = Directory('build/map-verification')
      ..createSync(recursive: true);
    File('${folder.path}/map.png').writeAsBytesSync(bytes);
    File('${folder.path}/route.json').writeAsStringSync(
      jsonEncode({
        'level': viewport.level,
        'legs': bus.legs
            .map(
              (s) => {
                'type': s.type,
                'guidance': s.guidance,
                'vehicles': s.vehicles,
                'stops': s.stops,
                'pixels': s.points.map((p) {
                  if (p == null) return null;
                  final v = viewport.pixel(p);
                  return [v.x, v.y];
                }).toList(),
              },
            )
            .toList(),
      }),
    );
    stdout.writeln(
      'Bus route geometry and authenticated 960x640 Kakao map verified: ${bus.legs.length} legs, ${points.length} coordinates',
    );
  } finally {
    client.close(force: true);
  }
}
