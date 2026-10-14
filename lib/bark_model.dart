import 'dart:math';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'audio_input.dart';

/// Runs entirely in a worker isolate; no microphone/file plugin calls here.
Map<String, dynamic> classifyBarks(Map<String, Uint8List> input) {
  final waveform = modelWaveform(input['audio']!);
  final options = InterpreterOptions()..threads = 2;
  final interpreter = Interpreter.fromBuffer(input['model']!, options: options);
  try {
    if (interpreter.getInputTensor(0).shape.join(',') != '15600' ||
        interpreter.getOutputTensor(0).shape.join(',') != '1,521') {
      throw StateError('YAMNet 모델 입출력 형식이 일치하지 않습니다.');
    }
    final output = [List<double>.filled(521, 0)];
    final windows = <Map<String, dynamic>>[];
    double barkPeak = 0, dogPeak = 0, speechPeak = 0;
    // 0.975-second windows, 0.48-second hop, with zero-padded final window.
    for (int start = 0; start < waveform.length; start += 7680) {
      final frame = Float32List(15600);
      final n = min(15600, waveform.length - start);
      frame.setRange(0, n, waveform, start);
      interpreter.run(frame, output);
      final scores = output[0];
      if (scores.any((s) => !s.isFinite || s < 0 || s > 1.00001)) {
        throw StateError('모델이 올바르지 않은 점수를 반환했습니다.');
      }
      final bark = scores[70], dog = scores[69], speech = scores[0];
      barkPeak = max(barkPeak, bark);
      dogPeak = max(dogPeak, dog);
      speechPeak = max(speechPeak, speech);
      windows.add({
        'start': start / 16000,
        'end': min((start + 15600) / 16000, waveform.length / 16000),
        'bark': bark,
        'dog': dog,
        'speech': speech,
      });
      if (start + 15600 >= waveform.length) {
        break;
      }
    }
    return {
      'model': 'Google YAMNet',
      'version': 1,
      'threshold': .3,
      'barkPeak': barkPeak,
      'dogPeak': dogPeak,
      'speechPeak': speechPeak,
      'windows': windows,
      'sampleRate': 16000,
      'notice': '모델 점수는 정답률이나 감정 확률이 아닙니다.',
    };
  } finally {
    interpreter.close();
    options.delete();
  }
}
