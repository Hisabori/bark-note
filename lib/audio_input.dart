import 'dart:math';
import 'dart:typed_data';
import 'analyzer.dart';

/// PCM16 to normalized 16 kHz mono. Select the higher-energy stereo channel
/// rather than averaging opposite-phase channels. Windowed-sinc resampling
/// suppresses aliasing when importing high-rate audio.
Float32List modelWaveform(Uint8List bytes) {
  final info = wavInfo(bytes);
  final d = ByteData.sublistView(bytes);
  int channel = 0;
  if (info.channels == 2) {
    final energy = [0.0, 0.0];
    for (int i = 0; i < info.samples; i++) {
      for (int c = 0; c < 2; c++) {
        final v = d
            .getInt16(info.start + (i * 2 + c) * 2, Endian.little)
            .toDouble();
        energy[c] += v * v;
      }
    }
    channel = energy[1] > energy[0] ? 1 : 0;
  }
  double sample(int i) =>
      d.getInt16(
        info.start + (i * info.channels + channel) * 2,
        Endian.little,
      ) /
      32768;
  final count = max(1, (info.samples * 16000 / info.rate).round());
  final output = Float32List(count);
  if (info.rate == 16000) {
    for (int i = 0; i < count; i++) {
      output[i] = sample(i);
    }
    return output;
  }
  final cutoff = min(1.0, 16000 / info.rate) * .94;
  final radius = (12 / cutoff).ceil();
  for (int i = 0; i < count; i++) {
    final position = i * info.rate / 16000;
    final center = position.floor();
    double value = 0, weight = 0;
    for (
      int j = max(0, center - radius);
      j <= min(info.samples - 1, center + radius);
      j++
    ) {
      final x = position - j;
      if (x.abs() > radius) {
        continue;
      }
      final sinc = x.abs() < 1e-9 ? cutoff : sin(pi * cutoff * x) / (pi * x);
      final w = sinc * (.5 + .5 * cos(pi * x / radius));
      value += sample(j) * w;
      weight += w;
    }
    output[i] = weight.abs() > 1e-9 ? (value / weight).clamp(-1, 1) : 0;
  }
  return output;
}
