import 'dart:math';
import 'dart:typed_data';

({int rate, int channels, int start, int samples}) wavInfo(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  String tag(int p) => String.fromCharCodes(bytes.sublist(p, p + 4));
  if (bytes.length < 44 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    throw const FormatException('올바른 WAV 파일이 아닙니다.');
  }
  int rate = 0, channels = 0, bits = 0, format = 0, start = 0, size = 0;
  for (int p = 12; p + 8 <= bytes.length;) {
    final n = d.getUint32(p + 4, Endian.little);
    if (p + 8 + n > bytes.length) {
      throw const FormatException('파일이 손상되었습니다.');
    }
    if (tag(p) == 'fmt ' && n >= 16) {
      format = d.getUint16(p + 8, Endian.little);
      channels = d.getUint16(p + 10, Endian.little);
      rate = d.getUint32(p + 12, Endian.little);
      bits = d.getUint16(p + 22, Endian.little);
    }
    if (tag(p) == 'data') {
      start = p + 8;
      size = n;
    }
    p += 8 + n + n % 2;
  }
  if (format != 1 ||
      bits != 16 ||
      channels < 1 ||
      channels > 2 ||
      rate < 8000 ||
      rate > 96000 ||
      size == 0) {
    throw const FormatException('8–96 kHz, 16-bit PCM WAV(모노/스테레오)을 선택해주세요.');
  }
  final samples = size ~/ (channels * 2);
  if (samples == 0 || size % (channels * 2) != 0) {
    throw const FormatException('오디오 데이터 길이가 올바르지 않습니다.');
  }
  if (samples / rate > 300) {
    throw const FormatException('5분 이하 파일만 분석할 수 있습니다.');
  }
  return (rate: rate, channels: channels, start: start, samples: samples);
}

Map<String, dynamic> analyzeWav(Uint8List bytes) {
  final info = wavInfo(bytes);
  final rate = info.rate,
      channels = info.channels,
      start = info.start,
      samples = info.samples;
  final d = ByteData.sublistView(bytes);
  final frame = (rate * .02).round();
  final levels = <double>[];
  for (int i = 0; i < samples; i += frame) {
    double sum = 0;
    final end = min(i + frame, samples);
    for (int j = i; j < end; j++) {
      for (int c = 0; c < channels; c++) {
        final v =
            d.getInt16(start + (j * channels + c) * 2, Endian.little) / 32768;
        sum += v * v;
      }
    }
    levels.add(
      20 * log(max(sqrt(sum / ((end - i) * channels)), .000001)) / ln10,
    );
  }
  final sorted = [...levels]..sort();
  final threshold = max(-42.0, sorted[(sorted.length * .2).floor()] + 12);
  final segments = <Map<String, dynamic>>[];
  int? onset;
  int last = 0;
  void finish() {
    if (onset == null) {
      return;
    }
    final length = (last - onset! + 1) * .02;
    if (length >= .08 && length <= 2.0) {
      segments.add({
        'start': onset! * .02,
        'end': min((last + 1) * .02, samples / rate),
      });
    }
    onset = null;
  }

  for (int i = 0; i < levels.length; i++) {
    if (levels[i] > threshold) {
      onset ??= i;
      last = i;
    } else if (onset != null && i - last >= 6) {
      finish();
    }
  }
  finish();
  final duration = samples / rate;
  return {
    'duration': duration,
    'peak': levels.reduce(max),
    'threshold': threshold,
    'count': segments.length,
    'perMinute': segments.length * 60 / duration,
    'segments': segments,
    'levels': levels,
  };
}
