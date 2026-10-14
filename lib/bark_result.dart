import 'dart:math';

/// Verification remains approximate at YAMNet's ~one-second resolution.
void applyBarkVerification(
  Map<String, dynamic> audio,
  Map<String, dynamic> ai,
) {
  final candidates = (audio['segments'] as List).cast<Map>();
  final windows = (ai['windows'] as List).cast<Map>();
  final threshold = (ai['threshold'] as num).toDouble();
  final verified = <Map<String, dynamic>>[];
  for (final segment in candidates) {
    final start = (segment['start'] as num).toDouble();
    final end = (segment['end'] as num).toDouble();
    double weighted = 0, weights = 0;
    for (final w in windows) {
      final overlap =
          min(end, (w['end'] as num).toDouble()) -
          max(start, (w['start'] as num).toDouble());
      if (overlap > 0) {
        weighted += overlap * (w['bark'] as num);
        weights += overlap;
      }
    }
    final score = weights > 0 ? weighted / weights : 0.0;
    if (score >= threshold) {
      verified.add({...segment.cast<String, dynamic>(), 'barkScore': score});
    }
  }
  audio['ai'] = ai;
  audio['verifiedSegments'] = verified;
  audio['verifiedCount'] = verified.length;
}
