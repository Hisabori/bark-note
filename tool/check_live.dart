import 'dart:io';
import 'package:rail_time/live_plan.dart';
import 'package:rail_time/planner.dart';

void main() {
  final now = DateTime.utc(2026, 10, 20, 0);
  final journey = Journey(
    deadline: now.add(const Duration(minutes: 60)),
    walkToPlatform: 10,
    rideAndTransfer: 25,
    wait: 5,
    exitWalk: 5,
    buffer: 5,
  );
  Map<String, dynamic> train(int minutes, {int age = 0}) => {
    'eta': now.add(Duration(minutes: minutes)).toIso8601String(),
    'receivedAt': now.subtract(Duration(seconds: age)).toIso8601String(),
    'fresh': true,
  };
  void check(bool value, String label) {
    if (!value) throw StateError(label);
    stdout.writeln('PASS $label');
  }

  final usable = livePlan(train(15), journey, now)!;
  check(
    usable.canCatch &&
        usable.onTime &&
        usable.leaveAt == now.add(const Duration(minutes: 4)),
    'walk and boarding margin',
  );
  check(
    usable.arriveAt == now.add(const Duration(minutes: 45)),
    'replace manual wait with actual train ETA',
  );
  check(!livePlan(train(10), journey, now)!.canCatch, 'missed train excluded');
  check(
    !livePlan(train(30), journey, now)!.onTime,
    'deadline includes destination walk and buffer',
  );
  check(
    livePlan(train(15, age: 121), journey, now) == null,
    'stale forecast rejected',
  );
  check(
    livePlan(train(15, age: -31), journey, now) == null,
    'future timestamp rejected',
  );
  check(livePlan(train(0), journey, now) == null, 'expired ETA rejected');
}
