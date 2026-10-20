import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/transit/saved_route.dart';

void main() {
  final route = SavedRoute(
    '출근',
    '서울',
    '회사',
    '1001|상행|청량리',
    [10, 30, 5, 5, 5],
    9,
    0,
  );
  test(
    'saved routes round trip without storing API credentials or old dates',
    () {
      final decoded = SavedRoute.parse(route.toJson())!;
      expect(decoded.station, '서울');
      expect(decoded.minutes, [10, 30, 5, 5, 5]);
      expect(decoded.toJson().keys, isNot(contains('apiKey')));
      expect(decoded.toJson().keys, isNot(contains('deadline')));
    },
  );
  test('next arrival uses Korea time and rolls into next year', () {
    expect(
      route.nextDeadline(DateTime.utc(2026, 12, 31, 0)),
      DateTime.utc(2027, 1, 1, 0),
    );
    expect(
      route.nextDeadline(DateTime.utc(2026, 12, 30, 23, 59)),
      DateTime.utc(2026, 12, 31, 0),
    );
  });
  test('invalid stored entries are skipped', () {
    expect(SavedRoute.parse(null), isNull);
    expect(
      SavedRoute.parse({
        ...route.toJson(),
        'minutes': [10, 0, 5, 5, 5],
      }),
      isNull,
    );
    expect(SavedRoute.parse({...route.toJson(), 'hour': 24}), isNull);
    expect(
      SavedRoute.parse({
        ...route.toJson(),
        'minutes': ['10', 30, 5, 5, 5],
      }),
      isNull,
    );
  });
}
