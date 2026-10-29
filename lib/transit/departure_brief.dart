import 'package:flutter/material.dart';
import 'live_plan.dart';
import 'planner.dart';

String departureCountdown(Duration duration) {
  if (duration.isNegative) return '시각 지남';
  final seconds = duration.inSeconds;
  return seconds < 60 ? '$seconds초' : '${seconds ~/ 60}분 ${seconds % 60}초';
}

/// A forecast, never a guarantee. All times use the same selected estimate.
class DepartureBrief extends StatelessWidget {
  const DepartureBrief({
    super.key,
    required this.estimate,
    required this.now,
    required this.received,
    required this.preparation,
    required this.walk,
    required this.margin,
    this.journey,
  });
  final BoardingEstimate estimate;
  final DateTime now, received;
  final int preparation, walk, margin;
  final Journey? journey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spare = estimate.spareSeconds;
    final tight = spare < 120;
    final arrival = journey == null
        ? null
        : estimate.eta.add(
            Duration(minutes: journey!.rideAndTransfer + journey!.exitWalk),
          );
    final deadlineSpare = arrival == null
        ? null
        : journey!.deadline.difference(
            arrival.add(Duration(minutes: journey!.buffer)),
          );
    Widget step(IconData icon, String label, DateTime time, String detail) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label · ${hm(time)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(detail),
                  ],
                ),
              ),
            ],
          ),
        );
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tight ? '곧 준비를 시작해요' : '여유 있게 준비해요',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '준비 시작까지 ${departureCountdown(estimate.prepareBy.difference(now))}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('준비 $preparation분 · 승강장까지 $walk분 · 탑승 여유 $margin분'),
              ],
            ),
          ),
          step(
            Icons.checkroom_outlined,
            '준비 시작',
            estimate.prepareBy,
            preparation == 0 ? '바로 출발할 수 있는 상태 기준' : '외출 준비 $preparation분 반영',
          ),
          step(
            Icons.directions_walk,
            '집에서 출발',
            estimate.leaveBy,
            '출발까지 ${departureCountdown(estimate.leaveBy.difference(now))}',
          ),
          step(
            Icons.train_outlined,
            '열차 도착 예상',
            estimate.eta,
            '승강장에 $margin분 먼저 도착하는 기준',
          ),
          if (arrival != null)
            step(
              Icons.flag_outlined,
              '목적지 도착 예상',
              arrival,
              deadlineSpare!.isNegative
                  ? '목표 도착까지 여유가 부족해요 · 다음 계획을 확인해주세요.'
                  : '추가 여유 ${journey!.buffer}분을 반영해 목표 도착 가능 예상',
            ),
          Text(
            '열차 정보 ${now.difference(received).inSeconds.clamp(0, 120)}초 전 기준 · 2분 이후 재조회 필요',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
