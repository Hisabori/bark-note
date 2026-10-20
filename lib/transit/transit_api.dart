import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> directArrivals(String key, String station) async {
  if (key.trim().isEmpty) {
    throw StateError('설정에 서울시 지하철 인증키를 입력해주세요.');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final uri = Uri.http(
      'swopenapi.seoul.go.kr',
      '/api/subway/${key.trim()}/json/realtimeStationArrival/0/100/${station.trim()}',
    );
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 12));
    final response = await request.close().timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('서울시 API 연결 오류 (${response.statusCode})');
    }
    final raw =
        jsonDecode(
              await utf8.decoder
                  .bind(response)
                  .join()
                  .timeout(const Duration(seconds: 12)),
            )
            as Map<String, dynamic>;
    final error = raw['errorMessage'];
    if (error is Map && error['code'] != 'INFO-000') {
      throw StateError('서울시 API 오류: ${error['code']}');
    }
    if (raw['realtimeArrivalList'] is! List) {
      throw StateError('현재 제공되는 도착정보가 없습니다.');
    }
    final now = DateTime.now().toUtc();
    final rows = (raw['realtimeArrivalList'] as List).map((r) {
      final text = (r['recptnDt'] as String? ?? '').replaceFirst(' ', 'T');
      final received = text.isEmpty
          ? null
          : DateTime.tryParse(
              RegExp(r'[zZ]|[+-]\d\d:\d\d$').hasMatch(text)
                  ? text
                  : '$text+09:00',
            );
      final age = received == null
          ? 999999
          : now.difference(received).inSeconds;
      final fresh = age >= -30 && age <= 120;
      final seconds = int.tryParse('${r['barvlDt']}');
      return <String, dynamic>{
        'line': '${r['subwayId'] ?? ''}',
        'direction': '${r['updnLine'] ?? ''}',
        'terminal': '${r['bstatnNm'] ?? ''}',
        'destination': '${r['trainLineNm'] ?? ''}',
        'message': '${r['arvlMsg2'] ?? '도착 시각 미제공'}',
        'receivedAt': received?.toUtc().toIso8601String(),
        'fresh': fresh,
        'eta': fresh && seconds != null && seconds > 0
            ? received!
                  .add(Duration(seconds: seconds))
                  .toUtc()
                  .toIso8601String()
            : null,
      };
    }).toList();
    return {'available': true, 'arrivals': rows};
  } on SocketException {
    throw StateError('서울시 API에 연결하지 못했습니다. 인터넷 연결을 확인해주세요.');
  } finally {
    client.close(force: true);
  }
}
