import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/transit/kakao_api.dart';

void main() {
  test(
    'Kakao coordinates preserve longitude and latitude and reject invalid values',
    () {
      final place = KakaoPlace.fromJson({
        'place_name': '서울역',
        'x': '126.97',
        'y': '37.55',
      });
      expect(place.x, 126.97);
      expect(place.y, 37.55);
      expect(
        () => KakaoPlace.fromJson({'x': 'NaN', 'y': '37'}),
        throwsFormatException,
      );
    },
  );
  test('Kakao whole journey seconds and buffer counted exactly once', () {
    final route = KakaoRoute.fromJson({
      'properties': {'totalTime': 1810, 'transfers': 1},
      'steps': [
        {
          'properties': {'guidance': '2호선 탑승'},
        },
      ],
    });
    expect(route.minutes, 31);
    expect(route.guidance, ['2호선 탑승']);
    final target = DateTime.utc(2026, 10, 20, 1);
    expect(target.difference(route.leaveBy(target, 5)).inSeconds, 2110);
    expect(
      () => KakaoRoute.fromJson({
        'properties': {'totalTime': 0},
      }),
      throwsFormatException,
    );
  });
}
