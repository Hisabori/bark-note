import 'breed.dart';

/// Recording checks are operational heuristics, not model accuracy scores.
List<String> recordingAdvice(Map<String, dynamic> audio) {
  final advice = <String>[];
  final duration = audio['duration'];
  if (duration is num && duration < 3) {
    advice.add('녹음이 3초보다 짧아요. 주변 상황이 포함되도록 조금 더 녹음해보세요.');
  }
  final quality = audio['quality'];
  if (quality is Map) {
    final clipped = quality['clippedRatio'];
    if (clipped is num && clipped >= .001) {
      advice.add('소리가 입력 한계에 닿은 샘플이 있어요. 마이크를 조금 멀리 두고 다시 녹음해보세요.');
    }
    final quiet = quality['quietFrameRatio'];
    if (quiet is num && quiet >= .8) {
      advice.add('대부분의 구간이 매우 조용해요. 강아지와 마이크 사이 거리를 확인해주세요.');
    }
  }
  return advice;
}

double? verifiedBarkRate(Map<String, dynamic> audio) {
  final duration = audio['duration'], count = audio['verifiedCount'];
  if (audio['ai'] is! Map ||
      audio['aiError'] != null ||
      duration is! num ||
      !duration.isFinite ||
      duration < 10 ||
      count is! num ||
      !count.isFinite ||
      count < 0) {
    return null;
  }
  return count * 60 / duration;
}

({double current, double previous, int records})? compareBarkHistory(
  Map<String, dynamic> current,
  List<Map<String, dynamic>> history,
  String dog,
  String situation, {
  String? breed,
  bool sameDog = true,
}) {
  final selectedBreed = normalizeBreed(breed ?? current['breed']);
  if (!sameDog && !canGroupBreed(selectedBreed)) return null;
  final rate = verifiedBarkRate(current);
  if (rate == null || dog.trim().isEmpty) return null;
  final candidates = history.where((entry) {
    final emotion = entry['emotion'];
    final ai = entry['ai'];
    return entry['date'] != current['date'] &&
        (!sameDog || (entry['dog'] as String? ?? '우리 강아지') == dog.trim()) &&
        normalizeBreed(entry['breed']) == selectedBreed &&
        emotion is Map &&
        emotion['context'] == situation &&
        ai is Map &&
        ai['threshold'] == (current['ai'] as Map)['threshold'] &&
        verifiedBarkRate(entry) != null;
  }).toList()..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
  final recent = candidates.take(5).toList();
  if (recent.isEmpty) return null;
  // Pool durations rather than averaging rates from unequal recordings.
  final duration = recent.fold<double>(
    0,
    (sum, e) => sum + (e['duration'] as num),
  );
  final count = recent.fold<double>(
    0,
    (sum, e) => sum + (e['verifiedCount'] as num),
  );
  return (
    current: rate,
    previous: count * 60 / duration,
    records: recent.length,
  );
}
