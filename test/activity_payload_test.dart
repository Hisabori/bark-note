import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/transit/activity_payload.dart';
import 'package:bark_note/transit/kakao_api.dart';

void main() {
  final now = DateTime.utc(2026, 10, 27, 3);
  Map<String, dynamic> payload({
    String kind = 'train',
    int age = 0,
    int leave = 60,
  }) => departurePayload(
    station: '서울',
    label: '테스트',
    kind: kind,
    leave: now.add(Duration(seconds: leave)),
    arrival: now.add(Duration(seconds: leave + 600)),
    received: now.subtract(Duration(seconds: age)),
    now: now,
  );
  test('train expiry never extends beyond source freshness or departure', () {
    expect(
      payload(age: 30, leave: 300)['staleEpoch'],
      now.add(const Duration(seconds: 90)).millisecondsSinceEpoch,
    );
    expect(
      payload(leave: 30)['staleEpoch'],
      now.add(const Duration(seconds: 30)).millisecondsSinceEpoch,
    );
  });
  test('stale, future, expired and over-eight-hour plans are rejected', () {
    expect(() => payload(age: 120), throwsStateError);
    expect(() => payload(age: -1), throwsStateError);
    expect(() => payload(leave: 0), throwsStateError);
    expect(() => payload(leave: 8 * 3600 + 1), throwsStateError);
    expect(() => payload(kind: 'unknown'), throwsStateError);
  });
  test(
    'route departure includes buffer and arrival preserves travel duration',
    () {
      const route = KakaoRoute(1800, 1, [], type: 'BUS');
      final p = routeActivityPayload(
        route,
        const KakaoPlace('출발', '', 127, 37.5),
        const KakaoPlace('도착', '', 127.1, 37.6),
        now.add(const Duration(hours: 1)),
        5,
        now,
        now,
      );
      expect(p['kind'], 'route');
      expect(
        p['leaveEpoch'],
        now.add(const Duration(minutes: 25)).millisecondsSinceEpoch,
      );
      expect(
        p['trainEpoch'],
        now.add(const Duration(minutes: 55)).millisecondsSinceEpoch,
      );
      expect(
        p['staleEpoch'],
        now.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
      );
      expect(() => payload(kind: 'route', age: 900), throwsStateError);
    },
  );
  test('text limits preserve Unicode characters', () {
    expect(activityText('  🐶🐶🐶 ', 2), '🐶🐶');
  });
}
