import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/transit/live_plan.dart';

void main() {
  final now = DateTime.utc(2026, 10, 20, 0);
  Map<String, dynamic> train(int minutes, {int age = 0}) => {
    'fresh': true,
    'receivedAt': now.subtract(Duration(seconds: age)).toIso8601String(),
    'eta': now.add(Duration(minutes: minutes)).toIso8601String(),
  };
  test('boarding works without a destination or full journey', () {
    expect(boardingEstimate(train(11), 10, now)!.canCatch, isTrue);
    expect(boardingEstimate(train(10), 10, now)!.canCatch, isFalse);
    expect(boardingEstimate(train(15), 10, now)!.spareSeconds, 240);
  });
  test('boarding rejects invalid walk, stale and expired forecast', () {
    expect(boardingEstimate(train(15), -1, now), isNull);
    expect(boardingEstimate(train(15, age: 121), 10, now), isNull);
    expect(boardingEstimate(train(15, age: -31), 10, now), isNull);
    expect(boardingEstimate(train(0), 10, now), isNull);
  });
}
