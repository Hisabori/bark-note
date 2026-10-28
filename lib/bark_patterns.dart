import 'dart:math' as math;

class BarkBout {
  BarkBout(this.start, this.end, this.count);
  final double start, end;
  final int count;
}

class BarkPatternSummary {
  BarkPatternSummary(
    this.verified,
    this.count,
    this.activeSeconds,
    this.medianGap,
    this.bouts,
  );
  final bool verified;
  final int count;
  final double activeSeconds;
  final double? medianGap;
  final List<BarkBout> bouts;
}

/// Describes detected events only; does not infer emotion or model accuracy.
BarkPatternSummary? summarizeBarkPatterns(Map<String, dynamic> audio) {
  final duration = audio['duration'];
  if (duration is! num || !duration.isFinite || duration <= 0) return null;
  final verified = audio['ai'] is Map && audio['aiError'] == null;
  final raw = audio[verified ? 'verifiedSegments' : 'segments'];
  if (raw is! List) return null;
  final events = <(double, double)>[];
  for (final item in raw.whereType<Map>()) {
    final a = item['start'], b = item['end'];
    if (a is num &&
        b is num &&
        a.isFinite &&
        b.isFinite &&
        a >= 0 &&
        b > a &&
        b <= duration) {
      events.add((a.toDouble(), b.toDouble()));
    }
  }
  events.sort((a, b) => a.$1.compareTo(b.$1));
  final bouts = <BarkBout>[];
  final gaps = <double>[];
  double active = 0, lastEnd = 0;
  double? start, boutEnd;
  int count = 0;
  for (final e in events) {
    if (start != null && e.$1 - boutEnd! > 1.5) {
      bouts.add(BarkBout(start, boutEnd, count));
      start = null;
      count = 0;
    }
    start ??= e.$1;
    boutEnd = math.max(boutEnd ?? e.$2, e.$2);
    count++;
    if (lastEnd > 0) gaps.add(math.max(0, e.$1 - lastEnd));
    active += math.max(0, e.$2 - math.max(e.$1, lastEnd));
    lastEnd = math.max(lastEnd, e.$2);
  }
  if (start != null) bouts.add(BarkBout(start, boutEnd!, count));
  gaps.sort();
  final middle = gaps.length ~/ 2;
  final median = gaps.isEmpty
      ? null
      : gaps.length.isOdd
      ? gaps[middle]
      : (gaps[middle - 1] + gaps[middle]) / 2;
  return BarkPatternSummary(verified, events.length, active, median, bouts);
}
