import 'dart:async';

/// One in-flight native call and one newest pending snapshot. No audio crosses.
class BarkIslandBridge {
  BarkIslandBridge({
    required this.send,
    required this.changed,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final Future<bool?> Function(String, Map<String, dynamic>?) send;
  final void Function() changed;
  final DateTime Function() clock;
  DateTime? last;
  bool endPending = false;
  int generation = 0;
  Map<String, dynamic>? pending;
  bool queued = false,
      busy = false,
      active = false,
      failed = false,
      closed = false;
  String message = '';

  void update(Map<String, dynamic>? snapshot) {
    if (closed) return;
    if (snapshot != null) {
      if (failed) return;
      if (active &&
          last != null &&
          clock().difference(last!) < const Duration(seconds: 3)) {
        return;
      }
      if (!active) generation++;
      last = clock();
      active = true;
    } else {
      if (!active && !failed) return;
      generation++;
      endPending = true;
      active = false;
      failed = false;
      last = null;
    }
    pending = snapshot;
    queued = true;
    if (!busy) unawaited(drain());
  }

  Future<void> drain() async {
    busy = true;
    while (queued) {
      final ending = endPending;
      final value = ending ? null : pending;
      final token = generation;
      if (ending) {
        endPending = false;
        queued = pending != null;
      } else {
        pending = null;
        queued = false;
      }
      try {
        final ok = await send(
          value == null ? 'barkEnd' : 'barkSync',
          value,
        ).timeout(const Duration(seconds: 5));
        if (token != generation) continue;
        if (value != null && active && ok != true) {
          failed = true;
          message = '실시간 현황을 표시하지 못했습니다. iOS 실시간 현황 설정을 확인해주세요.';
        } else if (value != null && active) {
          message = '다이내믹 아일랜드에 표시 중 · 약 3초 간격 갱신';
        } else {
          message = '';
        }
      } catch (_) {
        if (token != generation) continue;
        if (active) failed = true;
        message = active ? '실시간 현황 연결을 확인하지 못했습니다. 소리 분석은 계속됩니다.' : '';
      }
      changed();
    }
    busy = false;
  }

  void dispose() {
    update(null);
    closed = true;
  }
}

Map<String, dynamic> barkIslandSnapshot({
  required double elapsed,
  required int processed,
  required int positive,
  required Map<String, dynamic>? scores,
  required DateTime? updated,
  required DateTime now,
  required bool delayed,
}) {
  int percent(String key) {
    final value = scores?[key];
    return value is num && value.isFinite
        ? (value.clamp(0, 1) * 100).round()
        : 0;
  }

  bool reacts(String key) {
    final value = scores?[key];
    return value is num && value.isFinite && value >= .3 && value <= 1;
  }

  final fresh =
      scores != null &&
      updated != null &&
      now.difference(updated).inMilliseconds >= 0 &&
      now.difference(updated) <= const Duration(seconds: 3) &&
      !delayed;
  final bark = percent('bark');
  return {
    'elapsed': elapsed.isFinite ? elapsed.round().clamp(0, 300) : 0,
    'processed': processed.clamp(0, 10000),
    'positive': positive.clamp(0, processed.clamp(0, 10000)),
    'signal': !fresh
        ? 'waiting'
        : reacts('bark')
        ? 'bark'
        : reacts('dog')
        ? 'dog'
        : reacts('speech')
        ? 'speech'
        : 'quiet',
    'barkPercent': fresh ? bark : 0,
  };
}
