import 'planner.dart';

class BoardingEstimate {
  const BoardingEstimate(
    this.eta,
    this.leaveBy,
    this.readyAt, {
    DateTime? prepareBy,
  }) : prepareBy = prepareBy ?? leaveBy;
  final DateTime eta, leaveBy, readyAt, prepareBy;
  bool get canCatch => !readyAt.isAfter(eta);
  int get spareSeconds => eta.difference(readyAt).inSeconds;
}

BoardingEstimate? boardingEstimate(
  Map<String, dynamic> train,
  int walkMinutes,
  DateTime now, {
  int marginMinutes = 1,
  int preparationMinutes = 0,
}) {
  if (walkMinutes < 0 ||
      walkMinutes > 240 ||
      marginMinutes < 0 ||
      marginMinutes > 30 ||
      preparationMinutes < 0 ||
      preparationMinutes > 120) {
    return null;
  }
  final received = DateTime.tryParse('${train['receivedAt'] ?? ''}');
  final eta = DateTime.tryParse('${train['eta'] ?? ''}');
  if (received == null || eta == null || train['fresh'] != true) return null;
  final age = now.difference(received).inSeconds;
  if (age < -30 || age > 120 || !eta.isAfter(now)) return null;
  final duration = Duration(minutes: walkMinutes + marginMinutes);
  final leave = eta.subtract(duration);
  return BoardingEstimate(
    eta,
    leave,
    now.add(duration + Duration(minutes: preparationMinutes)),
    prepareBy: leave.subtract(Duration(minutes: preparationMinutes)),
  );
}

class LivePlan {
  const LivePlan(this.leaveAt, this.arriveAt, this.canCatch, this.onTime);
  final DateTime leaveAt, arriveAt;
  final bool canCatch, onTime;
}

/// Arrival forecasts are usable only while fresh; allow a minute to board.
LivePlan? livePlan(Map<String, dynamic> train, Journey journey, DateTime now) {
  final received = DateTime.tryParse('${train['receivedAt'] ?? ''}');
  final eta = DateTime.tryParse('${train['eta'] ?? ''}');
  if (received == null || eta == null || train['fresh'] != true) return null;
  final age = now.difference(received).inSeconds;
  if (age < -30 || age > 120 || !eta.isAfter(now)) return null;
  final leave = eta.subtract(Duration(minutes: journey.walkToPlatform + 1));
  final arrival = eta.add(
    Duration(minutes: journey.rideAndTransfer + journey.exitWalk),
  );
  return LivePlan(
    leave,
    arrival,
    !leave.isBefore(now),
    !arrival.add(Duration(minutes: journey.buffer)).isAfter(journey.deadline),
  );
}
