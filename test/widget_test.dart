import 'package:flutter_test/flutter_test.dart';
import 'package:rail_time/planner.dart';

void main() {
  final deadline = seoulInstant(2026, 10, 20, 9, 0);
  Journey plan() => Journey(
    deadline: deadline,
    walkToPlatform: 10,
    rideAndTransfer: 25,
    wait: 5,
    exitWalk: 5,
    buffer: 5,
  );
  test('all travel components count toward departure', () {
    expect(plan().total, 50);
    expect(hm(plan().leaveAt), '08:10');
  });
  test('deadline boundary is inclusive', () {
    expect(plan().canArrive(plan().leaveAt), true);
    expect(
      plan().canArrive(plan().leaveAt.add(const Duration(seconds: 1))),
      false,
    );
  });
  test('crowd comparison uses boarding time, not time leaving home', () {
    final r = lessCrowdedOptions(plan(), seoulInstant(2026, 10, 20, 7, 30), [
      CrowdSlot(450, 90),
      CrowdSlot(480, 30),
      CrowdSlot(510, 10),
    ]);
    expect(r.first.crowd, 30);
    expect(hm(r.first.depart), '07:45');
    expect(r.every((o) => plan().canArrive(o.depart)), true);
  });
  test(
    'no statistics means no fabricated recommendation',
    () => expect(lessCrowdedOptions(plan(), plan().leaveAt, []), isEmpty),
  );
  test(
    'past deadline produces no recommendations',
    () => expect(
      lessCrowdedOptions(plan(), deadline, [CrowdSlot(540, 30)]),
      isEmpty,
    ),
  );
  test('next day cannot use today profile', () {
    final now = seoulInstant(2026, 10, 20, 23, 50);
    final j = Journey(
      deadline: now.add(const Duration(hours: 2)),
      walkToPlatform: 10,
      rideAndTransfer: 10,
      wait: 5,
      exitWalk: 0,
      buffer: 0,
    );
    expect(lessCrowdedOptions(j, now, [CrowdSlot(0, 10)]), isEmpty);
  });
  test(
    'timezone conversion round trips',
    () => expect(hm(seoulInstant(2026, 10, 20, 0, 5)), '00:05'),
  );
}
