import 'dart:typed_data';
import 'dart:io';
import 'package:bark_note/analyzer.dart';
import 'package:bark_note/breed.dart';
import 'package:bark_note/bark_insights.dart';

void check(bool value, String name) {
  if (!value) throw StateError(name);
}

Map<String, dynamic> entry(
  String date,
  int count,
  int duration, {
  String dog = '콩이',
  String context = 'play',
}) => {
  'date': date,
  'dog': dog,
  'verifiedCount': count,
  'duration': duration,
  'ai': {'threshold': .3},
  'emotion': {'context': context},
};
Uint8List wav(int value) {
  const samples = 16000;
  final bytes = Uint8List(44 + samples * 2);
  final data = ByteData.sublistView(bytes);
  void tag(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  tag(0, 'RIFF');
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  tag(36, 'data');
  data.setUint32(4, bytes.length - 8, Endian.little);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint16(34, 16, Endian.little);
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    data.setInt16(44 + i * 2, value, Endian.little);
  }
  return bytes;
}

void main() {
  final current = entry('2026-10-24', 10, 60);
  final history = [
    entry('2026-10-23', 10, 60),
    entry('2026-10-22', 10, 120),
    entry('2026-10-21', 999, 60, dog: '다른 강아지'),
    entry('2026-10-20', 999, 60, context: 'alone'),
    current,
  ];
  final comparison = compareBarkHistory(current, history, '콩이', 'play')!;
  check(
    comparison.records == 2 &&
        (comparison.previous - 20 * 60 / 180).abs() < .0001,
    'weighted baseline and exclusion',
  );
  check(
    verifiedBarkRate(entry('short', 10, 5)) == null,
    'short recordings excluded',
  );
  check(
    verifiedBarkRate({...current, 'aiError': 'failed'}) == null,
    'failed AI excluded',
  );
  check(
    compareBarkHistory(current, [], '콩이', 'play') == null,
    'empty baseline',
  );
  final silence = analyzeWav(wav(0));
  check(
    (silence['quality'] as Map)['quietFrameRatio'] == 1,
    'silence measured',
  );
  check(recordingAdvice(silence).length == 2, 'short and quiet advice');
  final clipped = analyzeWav(wav(32767));
  check((clipped['quality'] as Map)['clippedRatio'] == 1, 'clipping measured');
  check(
    recordingAdvice(clipped).any((s) => s.contains('입력 한계')),
    'clipping advice',
  );
  check(recordingAdvice({'duration': 30}).isEmpty, 'old records supported');
  final poodle = {...current, 'breed': 'poodle'};
  final breedRecords = [
    {...entry('2026-10-23', 4, 60), 'breed': 'poodle'},
    {...entry('2026-10-22', 6, 60, dog: '두부'), 'breed': 'poodle'},
    {...entry('2026-10-21', 100, 60), 'breed': 'maltese'},
    {...entry('2026-10-20', 100, 60), 'breed': 'mixed'},
  ];
  final personal = compareBarkHistory(
    poodle,
    breedRecords,
    '콩이',
    'play',
    breed: 'poodle',
  )!;
  check(
    personal.records == 1 && personal.previous == 4,
    'individual breed filter',
  );
  final breedGroup = compareBarkHistory(
    poodle,
    breedRecords,
    '콩이',
    'play',
    breed: 'poodle',
    sameDog: false,
  )!;
  check(
    breedGroup.records == 2 && breedGroup.previous == 5,
    'local breed group filter',
  );
  check(
    compareBarkHistory(
          poodle,
          breedRecords,
          '콩이',
          'play',
          breed: 'mixed',
          sameDog: false,
        ) ==
        null,
    'mixed breeds not pooled',
  );
  check(
    compareBarkHistory(
          poodle,
          breedRecords,
          '콩이',
          'play',
          breed: 'other',
          sameDog: false,
        ) ==
        null,
    'other breeds not pooled',
  );
  check(
    normalizeBreed('invalid') == 'unknown' && normalizeBreed(null) == 'unknown',
    'legacy breed fallback',
  );
  check(breedLabel('poodle') == '푸들', 'breed label');
  stdout.writeln('15 bark recording, breed and comparison checks passed');
}
