import 'dart:io';
import 'package:bark_note/emotion.dart';
import 'package:bark_note/analyzer.dart';
import 'dart:typed_data';
import 'dart:math';

Uint8List fixture({bool silent = false, bool stereo = false}) {
  final ch = stereo ? 2 : 1;
  final b = Uint8List(44 + 16000 * 4 * 2 * ch);
  final d = ByteData.sublistView(b);
  void tag(int p, String s) => b.setRange(p, p + s.length, s.codeUnits);
  tag(0, 'RIFF');
  d.setUint32(4, b.length - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  d.setUint32(16, 16, Endian.little);
  d.setUint16(20, 1, Endian.little);
  d.setUint16(22, ch, Endian.little);
  d.setUint32(24, 16000, Endian.little);
  d.setUint32(28, 32000 * ch, Endian.little);
  d.setUint16(32, 2 * ch, Endian.little);
  d.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  d.setUint32(40, b.length - 44, Endian.little);
  for (int i = 0; i < 64000; i++) {
    final t = i / 16000;
    final on = !silent && ((t > .5 && t < .75) || (t > 2 && t < 2.35));
    final v = (sin(2 * pi * 600 * t) * (on ? 18000 : 0)).round();
    for (int c = 0; c < ch; c++) {
      d.setInt16(44 + (i * ch + c) * 2, c == 0 ? v : -v, Endian.little);
    }
  }
  return b;
}

void main() {
  void check(bool condition, String name) {
    if (!condition) {
      throw StateError(name);
    }
    stdout.writeln('PASS: $name');
  }

  check(analyzeWav(fixture())['count'] == 2, 'two bursts');
  check(
    interpretEmotion(analyzeWav(fixture(silent: true)), 'play')['label'] ==
        '판단 보류',
    'silence does not imply happiness',
  );
  check(
    interpretEmotion(analyzeWav(fixture()), 'unknown')['label'] ==
        '흥분 / 경계 / 요구 가능성',
    'unknown context stays ambiguous',
  );
  check(
    interpretEmotion(analyzeWav(fixture()), 'play')['label'] ==
        '기대 / 놀이 흥분 가능성',
    'play context interpretation',
  );
  check(
    interpretEmotion(analyzeWav(fixture()), 'visitor')['label'] ==
        '경계 / 긴장 가능성',
    'visitor context interpretation',
  );
  check(
    interpretEmotion(analyzeWav(fixture()), 'alone')['label'] ==
        '불편함 / 접촉 요구 가능성',
    'alone context interpretation',
  );
  check(
    interpretEmotion(analyzeWav(fixture()), 'invalid')['label'] ==
        '흥분 / 경계 / 요구 가능성',
    'invalid context fallback',
  );
  check(
    !interpretEmotion(analyzeWav(fixture()), 'play').containsKey('probability'),
    'no fabricated probabilities',
  );
  check(analyzeWav(fixture())['duration'] == 4, 'duration');
  check(analyzeWav(fixture(silent: true))['count'] == 0, 'silence');
  check(
    analyzeWav(fixture(stereo: true))['count'] == 2,
    'opposite stereo phase',
  );
  for (final b in [Uint8List(44), fixture().sublist(0, 100)]) {
    bool rejected = false;
    try {
      analyzeWav(b);
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'invalid/truncated WAV');
  }
}

