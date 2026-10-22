import 'dart:convert';
import 'dart:io';

class KakaoPlace {
  const KakaoPlace(this.name, this.address, this.x, this.y);
  final String name, address;
  final double x, y;
  factory KakaoPlace.fromJson(Map<String, dynamic> j) {
    final x = double.parse('${j['x']}'), y = double.parse('${j['y']}');
    if (!x.isFinite || !y.isFinite || x.abs() > 180 || y.abs() > 90) {
      throw const FormatException('장소 좌표가 올바르지 않습니다.');
    }
    return KakaoPlace(
      '${j['place_name']}',
      '${j['road_address_name'] ?? j['address_name'] ?? ''}',
      x,
      y,
    );
  }
  Map<String, dynamic> toJson() => {
    'place_name': name,
    'road_address_name': address,
    'x': x,
    'y': y,
  };
}

class KakaoRoute {
  const KakaoRoute(
    this.seconds,
    this.transfers,
    this.guidance, {
    this.type = '',
    this.legs = const [],
  });
  final int seconds, transfers;
  final List<String> guidance;
  final String type;
  final List<KakaoLeg> legs;
  bool get hasBus =>
      type == 'BUS' ||
      type == 'BUS_AND_SUBWAY' ||
      legs.any((s) => s.type == 'BUS');
  String get label => switch (type) {
    'BUS' => '버스',
    'SUBWAY' => '지하철',
    'BUS_AND_SUBWAY' => '버스 + 지하철',
    _ => '대중교통',
  };
  int get minutes => (seconds / 60).ceil();
  DateTime leaveBy(DateTime deadline, int buffer) =>
      deadline.subtract(Duration(seconds: seconds, minutes: buffer));
  factory KakaoRoute.fromJson(Map<String, dynamic> j) {
    final p = j['properties'] as Map;
    final seconds = (p['totalTime'] as num).toInt();
    if (seconds <= 0) throw const FormatException('경로 소요시간이 올바르지 않습니다.');
    final steps = (j['steps'] as List? ?? [])
        .map((s) => '${s['properties']['guidance'] ?? ''}')
        .where((s) => s.isNotEmpty)
        .toList();
    return KakaoRoute(
      seconds,
      (p['transfers'] as num? ?? 0).toInt(),
      steps,
      type: p['type'] as String? ?? '',
      legs: (j['steps'] as List? ?? [])
          .map((s) => KakaoLeg.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }
}

class RoutePoint {
  const RoutePoint(this.x, this.y);
  final double x, y;
}

class KakaoLeg {
  const KakaoLeg(
    this.type,
    this.guidance,
    this.seconds,
    this.stops,
    this.vehicles,
    this.points,
  );
  final String type, guidance;
  final int seconds;
  final List<String> stops, vehicles;
  // Invalid coordinates break the line; never bridge a missing span.
  final List<RoutePoint?> points;
  factory KakaoLeg.fromJson(Map<String, dynamic> j) {
    final p = j['properties'] as Map? ?? {};
    final path = j['path'] as Map? ?? {};
    return KakaoLeg(
      '${p['type'] ?? ''}',
      '${p['guidance'] ?? ''}',
      (p['time'] as num? ?? 0).toInt(),
      (p['stops'] as List? ?? [])
          .whereType<Map>()
          .map((s) => '${s['name'] ?? ''}')
          .where((s) => s.isNotEmpty)
          .toList(),
      (p['vehicles'] as List? ?? [])
          .whereType<Map>()
          .map((s) => '${s['name'] ?? ''}')
          .where((s) => s.isNotEmpty)
          .toList(),
      (path['points'] as List? ?? []).map<RoutePoint?>((v) {
        if (v is! List || v.length < 2 || v[0] is! num || v[1] is! num) {
          return null;
        }
        final x = (v[0] as num).toDouble(), y = (v[1] as num).toDouble();
        if (!x.isFinite || !y.isFinite || x.abs() > 180 || y.abs() > 90) {
          return null;
        }
        return RoutePoint(x, y);
      }).toList(),
    );
  }
  String get label => switch (type) {
    'BUS' => '버스',
    'SUBWAY' => '지하철',
    'WALKING' => '도보',
    _ => '이동',
  };
}

class KakaoApi {
  KakaoApi(this.key);
  final String key;
  Future<Map<String, dynamic>> get(
    String path,
    Map<String, String> query,
  ) async {
    if (key.trim().isEmpty) throw StateError('설정에서 카카오 REST API 키를 입력해주세요.');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client
          .getUrl(Uri.https('dapi.kakao.com', path, query))
          .timeout(const Duration(seconds: 12));
      req.headers.set('Authorization', 'KakaoAK ${key.trim()}');
      final res = await req.close().timeout(const Duration(seconds: 12));
      final raw = await utf8.decoder
          .bind(res)
          .join()
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw StateError(
          '카카오 API 오류 (${res.statusCode}). 키·사용 권한·호출 한도를 확인해주세요.',
        );
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } on SocketException {
      throw StateError('카카오 API에 연결하지 못했습니다. 인터넷 연결을 확인해주세요.');
    } finally {
      client.close(force: true);
    }
  }

  Future<List<KakaoPlace>> search(String query) async {
    if (query.trim().isEmpty) throw StateError('장소 검색어를 입력해주세요.');
    final j = await get('/v2/local/search/keyword.json', {
      'query': query.trim(),
      'size': '10',
    });
    return (j['documents'] as List)
        .map((p) => KakaoPlace.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }

  Future<List<KakaoRoute>> routes(KakaoPlace start, KakaoPlace end) async {
    final j = await get('/v2/routing/publictraffic', {
      'start_x': '${start.x}',
      'start_y': '${start.y}',
      's_name': start.name,
      'end_x': '${end.x}',
      'end_y': '${end.y}',
      'e_name': end.name,
      'output_coord': 'WGS84',
    });
    if (j['status'] != 'OK') {
      throw StateError('대중교통 경로를 찾지 못했습니다 (${j['status']}).');
    }
    final routes = (j['routes'] as List)
        .map((r) => KakaoRoute.fromJson(Map<String, dynamic>.from(r)))
        .toList();
    routes.sort((a, b) => a.seconds.compareTo(b.seconds));
    return routes;
  }
}
