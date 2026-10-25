import 'dart:io';
import 'package:bark_note/transit/kakao_api.dart';

Future<void> main() async {
  final api = KakaoApi(Platform.environment['KAKAO_KEY'] ?? '');
  const center = KakaoPlace('서울시청', '', 126.9780, 37.5665);
  final results = [
    await api.nearby('SW8', center, 1000),
    await api.search('카페', near: center, radius: 1000),
  ];
  for (final places in results) {
    if (places.isEmpty ||
        places.any(
          (p) =>
              p.name.trim().isEmpty ||
              p.x < 126 ||
              p.x > 128 ||
              p.y < 37 ||
              p.y > 38,
        )) {
      throw StateError(
        'Nearby place response did not match the public Seoul fixture',
      );
    }
  }
  stdout.writeln(
    'Nearby station and keyword search verified against Kakao; no device location used',
  );
}
