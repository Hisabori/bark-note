import 'kakao_api.dart';
import 'live_plan.dart';

String activityText(String value, int limit) =>
    String.fromCharCodes(value.trim().runes.take(limit));
Map<String, dynamic> departurePayload({
  required String station,
  required String label,
  required String kind,
  required DateTime leave,
  required DateTime arrival,
  required DateTime received,
  required DateTime now,
}) {
  final age = now.difference(received);
  final ttl = Duration(minutes: kind == 'train' ? 2 : 15);
  if (!{'train', 'route'}.contains(kind) ||
      station.trim().isEmpty ||
      label.trim().isEmpty ||
      age.isNegative ||
      age >= ttl ||
      !leave.isAfter(now) ||
      !arrival.isAfter(leave) ||
      leave.difference(now) > const Duration(hours: 8)) {
    throw StateError('출발 시각과 최신 조회 정보를 확인해주세요. 실시간 현황은 8시간 이내 출발에 사용할 수 있습니다.');
  }
  final sourceExpiry = received.add(ttl);
  final expiry = sourceExpiry.isBefore(leave) ? sourceExpiry : leave;
  return {
    'station': activityText(station, 80),
    'train': activityText(label, 160),
    'kind': kind,
    'leaveEpoch': leave.millisecondsSinceEpoch,
    'trainEpoch': arrival.millisecondsSinceEpoch,
    'staleEpoch': expiry.millisecondsSinceEpoch,
    'updatedEpoch': received.millisecondsSinceEpoch,
  };
}

Map<String, dynamic> trainActivityPayload(
  BoardingEstimate estimate,
  Map<String, dynamic> train,
  String station,
  String label,
  DateTime now,
) => departurePayload(
  station: station,
  label: label,
  kind: 'train',
  leave: estimate.leaveBy,
  arrival: estimate.eta,
  received: DateTime.parse(train['receivedAt'] as String),
  now: now,
);
Map<String, dynamic> routeActivityPayload(
  KakaoRoute route,
  KakaoPlace start,
  KakaoPlace end,
  DateTime deadline,
  int buffer,
  DateTime fetched,
  DateTime now,
) {
  final leave = route.leaveBy(deadline, buffer);
  return departurePayload(
    station: start.name,
    label: '${route.label} · ${end.name}',
    kind: 'route',
    leave: leave,
    arrival: leave.add(Duration(seconds: route.seconds)),
    received: fetched,
    now: now,
  );
}
