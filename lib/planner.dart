DateTime seoulClock(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 9));
String hm(DateTime instant) {
  final t = seoulClock(instant);
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

DateTime seoulInstant(int year, int month, int day, int hour, int minute) =>
    DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
    ).subtract(const Duration(hours: 9));

class Journey {
  const Journey({
    required this.deadline,
    required this.walkToPlatform,
    required this.rideAndTransfer,
    required this.wait,
    required this.exitWalk,
    required this.buffer,
  });
  final DateTime deadline;
  final int walkToPlatform, rideAndTransfer, wait, exitWalk, buffer;
  int get total => walkToPlatform + rideAndTransfer + wait + exitWalk + buffer;
  DateTime get leaveAt => deadline.subtract(Duration(minutes: total));
  DateTime arrivalAt(DateTime leave) => leave.add(Duration(minutes: total));
  bool canArrive(DateTime leave) => !arrivalAt(leave).isAfter(deadline);
}

class CrowdSlot {
  CrowdSlot(this.minute, this.percent);
  final int minute;
  final double percent;
}

class DepartureOption {
  DepartureOption(this.depart, this.crowd);
  final DateTime depart;
  final double crowd;
}

/// Compare only measured 30-minute statistics; do not invent missing values.
List<DepartureOption> lessCrowdedOptions(
  Journey journey,
  DateTime now,
  List<CrowdSlot> slots,
) {
  final result = <DepartureOption>[];
  for (int n = 0; n <= 120; n += 5) {
    final depart = now.add(Duration(minutes: n));
    if (!journey.canArrive(depart)) {
      break;
    }
    final board = seoulClock(
      depart.add(Duration(minutes: journey.walkToPlatform + journey.wait)),
    );
    // One-day profiles cannot be reused across midnight or across weekdays.
    final today = seoulClock(now);
    if (board.year != today.year ||
        board.month != today.month ||
        board.day != today.day) {
      continue;
    }
    final minute = (board.hour * 60 + board.minute) ~/ 30 * 30;
    final matching = slots.where((s) => s.minute == minute);
    if (matching.isNotEmpty) {
      result.add(DepartureOption(depart, matching.first.percent));
    }
  }
  result.sort((a, b) {
    final crowd = a.crowd.compareTo(b.crowd);
    return crowd != 0 ? crowd : a.depart.compareTo(b.depart);
  });
  final picked = <DepartureOption>[];
  final used = <int>{};
  for (final option in result) {
    final board = seoulClock(
      option.depart.add(
        Duration(minutes: journey.walkToPlatform + journey.wait),
      ),
    );
    final slot = (board.hour * 60 + board.minute) ~/ 30;
    if (used.add(slot)) {
      picked.add(option);
    }
    if (picked.length == 3) {
      break;
    }
  }
  return picked;
}
