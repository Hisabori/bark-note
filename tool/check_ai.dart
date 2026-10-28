import 'dart:io';
import 'dart:typed_data';
import 'package:bark_note/audio_input.dart';
import 'package:bark_note/bark_result.dart';
import 'package:bark_note/emotion.dart';

void main(List<String> args) {
  if (args.length == 2) {
    final samples = modelWaveform(File(args[0]).readAsBytesSync());
    File(args[1]).writeAsBytesSync(samples.buffer.asUint8List());
    stdout.writeln('Exported ${samples.length} samples at 16kHz');
    return;
  }
  void check(bool value, String name) {
    if (!value) {
      throw StateError(name);
    }
    stdout.writeln('PASS $name');
  }

  final audio = <String, dynamic>{
    'segments': [
      {'start': 0.1, 'end': 0.3},
      {'start': 1.1, 'end': 1.3},
    ],
    'count': 2,
  };
  applyBarkVerification(audio, {
    'threshold': .3,
    'windows': [
      {'start': 0.0, 'end': 1.0, 'bark': .9},
      {'start': 1.0, 'end': 2.0, 'bark': .01},
    ],
  });
  check(audio['verifiedCount'] == 1, 'speech-like window excluded');
  check(
    interpretEmotion(audio, 'play')['label'] == '판단 보류',
    'AI vetoes insufficient bark evidence',
  );
  check(
    interpretEmotion({
          'aiError': 'failed',
          'segments': audio['segments'],
        }, 'play')['label'] ==
        '판단 보류',
    'AI failure does not imply successful classification',
  );
  check(
    interpretEmotion({'segments': audio['segments']}, 'play')['label'] ==
        '판단 보류',
    'legacy records do not acquire unsupported emotion interpretations',
  );
  Uint8List make(int rate, int count, int channels) {
    final b = Uint8List(44 + count * 2 * channels);
    final d = ByteData.sublistView(b);
    void tag(int p, String s) => b.setRange(p, p + s.length, s.codeUnits);
    tag(0, 'RIFF');
    d.setUint32(4, b.length - 8, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    d.setUint32(16, 16, Endian.little);
    d.setUint16(20, 1, Endian.little);
    d.setUint16(22, channels, Endian.little);
    d.setUint32(24, rate, Endian.little);
    d.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    d.setUint32(40, b.length - 44, Endian.little);
    for (int i = 0; i < count; i++) {
      for (int c = 0; c < channels; c++) {
        d.setInt16(
          44 + (i * channels + c) * 2,
          c == 0 ? 16384 : -16384,
          Endian.little,
        );
      }
    }
    return b;
  }

  final mono = modelWaveform(make(16000, 1600, 1));
  check(mono.length == 1600 && mono[0] == .5, 'normalization');
  final stereo = modelWaveform(make(16000, 1600, 2));
  check(stereo[0] == .5, 'opposite phase retained');
  for (final rate in [8000, 44100, 48000, 96000]) {
    final s = modelWaveform(make(rate, rate, 1));
    check(
      s.length == 16000 && s.every((x) => x.isFinite && x.abs() <= 1),
      'resampling $rate',
    );
  }
}
