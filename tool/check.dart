import 'dart:io';
import 'package:rail_time/planner.dart';

void main() {
  void check(bool value, String text) {
    if (!value) {
      throw StateError(text);
    }
    stdout.writeln('PASS $text');
  }

  final deadline = seoulInstant(2026, 10, 20, 9, 0);
  final p = Journey(
    deadline: deadline,
    walkToPlatform: 10,
    rideAndTransfer: 25,
    wait: 5,
    exitWalk: 5,
    buffer: 5,
  );
  check(p.total == 50 && hm(p.leaveAt) == '08:10', 'whole journey counted');
  check(
    p.canArrive(p.leaveAt) &&
        !p.canArrive(p.leaveAt.add(const Duration(seconds: 1))),
    'deadline boundary',
  );
  final options = lessCrowdedOptions(p, seoulInstant(2026, 10, 20, 7, 30), [
    CrowdSlot(450, 90),
    CrowdSlot(480, 30),
    CrowdSlot(510, 10),
  ]);
  check(
    options.first.crowd == 30 && hm(options.first.depart) == '07:45',
    'crowd evaluated at boarding time',
  );
  check(
    options.every((o) => p.canArrive(o.depart)),
    'recommended candidates arrive in time',
  );
  check(
    lessCrowdedOptions(p, p.leaveAt, []).isEmpty,
    'missing data not invented',
  );
  check(
    lessCrowdedOptions(p, deadline, [CrowdSlot(540, 10)]).isEmpty,
    'late journey rejected',
  );
  final now = seoulInstant(2026, 10, 20, 23, 50);
  final j = Journey(
    deadline: now.add(const Duration(hours: 2)),
    walkToPlatform: 10,
    rideAndTransfer: 10,
    wait: 5,
    exitWalk: 0,
    buffer: 0,
  );
  check(
    lessCrowdedOptions(j, now, [CrowdSlot(0, 10)]).isEmpty,
    'today data not reused tomorrow',
  );
  check(hm(seoulInstant(2026, 10, 20, 0, 5)) == '00:05', 'Seoul timezone');
}
