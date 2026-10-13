import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/analyzer.dart';

Uint8List wav({bool silent = false, bool stereo = false}) {
  const rate = 16000;
  final ch = stereo ? 2 : 1;
  final b = Uint8List(44 + rate * 4 * 2 * ch);
  final d = ByteData.sublistView(b);
  void tag(int at, String s) => b.setRange(at, at + s.length, s.codeUnits);
  tag(0, 'RIFF');
  d.setUint32(4, b.length - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  d.setUint32(16, 16, Endian.little);
  d.setUint16(20, 1, Endian.little);
  d.setUint16(22, ch, Endian.little);
  d.setUint32(24, rate, Endian.little);
  d.setUint32(28, rate * 2 * ch, Endian.little);
  d.setUint16(32, 2 * ch, Endian.little);
  d.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  d.setUint32(40, b.length - 44, Endian.little);
  for (int i = 0; i < rate * 4; i++) {
    final t = i / rate;
    final active = !silent && ((t > .5 && t < .75) || (t > 2 && t < 2.35));
    final v = (sin(2 * pi * 600 * t) * (active ? 18000 : 0)).round();
    for (int c = 0; c < ch; c++) {
      d.setInt16(44 + (i * ch + c) * 2, c == 0 ? v : -v, Endian.little);
    }
  }
  return b;
}

void main() {
  test('Two separated bursts detected', () {
    final r = analyzeWav(wav());
    expect(r['count'], 2);
    expect(r['duration'], 4);
  });
  test('Silence', () => expect(analyzeWav(wav(silent: true))['count'], 0));
  test(
    'Stereo opposite phase retains energy',
    () => expect(analyzeWav(wav(stereo: true))['count'], 2),
  );
  test(
    'Invalid header',
    () => expect(() => analyzeWav(Uint8List(44)), throwsFormatException),
  );
  test(
    'Truncated chunk',
    () =>
        expect(() => analyzeWav(wav().sublist(0, 100)), throwsFormatException),
  );
}
