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
  const KakaoRoute(this.seconds, this.transfers, this.guidance);
  final int seconds, transfers;
  final List<String> guidance;
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
    return KakaoRoute(seconds, (p['transfers'] as num? ?? 0).toInt(), steps);
  }
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
