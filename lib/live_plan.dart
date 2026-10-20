import 'planner.dart';

class LivePlan {
  const LivePlan(this.leaveAt, this.arriveAt, this.canCatch, this.onTime);
  final DateTime leaveAt, arriveAt;
  final bool canCatch, onTime;
}

/// Arrival forecasts are usable only while fresh; allow a minute to board.
LivePlan? livePlan(Map<String, dynamic> train, Journey journey, DateTime now) {
  final received = DateTime.tryParse(train['receivedAt'] as String? ?? '');
  final eta = DateTime.tryParse(train['eta'] as String? ?? '');
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
