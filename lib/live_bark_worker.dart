import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'live_bark_core.dart';

/// One interpreter per live session, reused off the UI isolate.
class LiveBarkWorker implements LiveBarkScorer {
  ReceivePort? replies, exit;
  SendPort? commands;
  Isolate? isolate;
  Completer<void>? ready;
  Completer<void>? ended;
  Completer<Map<String, dynamic>>? pending;
  Timer? killTimer;
  bool closed = false;
  @override
  Future<void> open() async {
    if (closed) throw StateError('분석 세션이 종료됐습니다.');
    final asset = await rootBundle.load('assets/models/yamnet.tflite');
    if (closed) throw StateError('분석 세션이 종료됐습니다.');
    ready = Completer<void>();
    ended = Completer<void>();
    replies = ReceivePort();
    exit = ReceivePort();
    exit!.listen((_) {
      finish();
    });
    replies!.listen((message) {
      if (message is SendPort) {
        commands = message;
        if (closed) commands!.send(null);
        if (!ready!.isCompleted) ready!.complete();
      } else if (message is Map) {
        if (message['error'] != null) {
          final error = StateError('기기 내 짖음 모델을 실행하지 못했습니다.');
          if (!ready!.isCompleted) ready!.completeError(error);
          if (pending != null && !pending!.isCompleted) {
            pending!.completeError(error);
          }
        } else if (pending != null && !pending!.isCompleted) {
          pending!.complete(Map<String, dynamic>.from(message));
        }
      } else if (message is List) {
        final error = StateError('분석 작업이 종료됐습니다.');
        if (!ready!.isCompleted) ready!.completeError(error);
        if (pending != null && !pending!.isCompleted) {
          pending!.completeError(error);
        }
      }
    });
    try {
      await Future.wait<void>([
        Isolate.spawn(
          liveBarkEntry,
          [
            replies!.sendPort,
            TransferableTypedData.fromList([
              asset.buffer.asUint8List(
                asset.offsetInBytes,
                asset.lengthInBytes,
              ),
            ]),
          ],
          onExit: exit!.sendPort,
          onError: replies!.sendPort,
          errorsAreFatal: true,
        ).then((worker) {
          isolate = worker;
          if (closed) commands?.send(null);
        }),
        ready!.future.timeout(const Duration(seconds: 20)),
      ]);
      if (closed) throw StateError('분석 세션이 종료됐습니다.');
    } catch (_) {
      await close();
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> score(Float32List frame) async {
    if (closed || commands == null || pending != null) {
      throw StateError('분석 작업을 시작할 수 없습니다.');
    }
    final result = Completer<Map<String, dynamic>>();
    pending = result;
    commands!.send(
      TransferableTypedData.fromList([frame.buffer.asUint8List()]),
    );
    try {
      return await result.future.timeout(const Duration(seconds: 5));
    } finally {
      if (identical(pending, result)) pending = null;
    }
  }

  void finish() {
    closed = true;
    killTimer?.cancel();
    killTimer = null;
    if (ready != null && !ready!.isCompleted) {
      ready!.completeError(StateError('분석 작업이 종료됐습니다.'));
    }
    if (pending != null && !pending!.isCompleted) {
      pending!.completeError(StateError('분석 작업이 종료됐습니다.'));
    }
    replies?.close();
    exit?.close();
    replies = null;
    exit = null;
    if (ended != null && !ended!.isCompleted) ended!.complete();
  }

  @override
  Future<void> close() async {
    if (!closed) {
      closed = true;
      commands?.send(null);
      if (ready != null && !ready!.isCompleted) {
        ready!.completeError(StateError('분석 세션이 종료됐습니다.'));
      }
      if (pending != null && !pending!.isCompleted) {
        pending!.completeError(StateError('분석 세션이 종료됐습니다.'));
      }
      if (ended != null && !ended!.isCompleted) {
        killTimer = Timer(const Duration(seconds: 5), () {
          isolate?.kill(priority: Isolate.immediate);
          finish();
        });
      }
    }
    await ended?.future;
  }
}

void liveBarkEntry(List<dynamic> args) async {
  final parent = args[0] as SendPort;
  final channel = ReceivePort();
  Interpreter? interpreter;
  final options = InterpreterOptions()..threads = 2;
  try {
    interpreter = Interpreter.fromBuffer(
      (args[1] as TransferableTypedData).materialize().asUint8List(),
      options: options,
    );
    if (interpreter.getInputTensor(0).shape.join(',') != '15600' ||
        interpreter.getOutputTensor(0).shape.join(',') != '1,521') {
      throw StateError('모델 형식 오류');
    }
    final output = [List<double>.filled(521, 0)];
    parent.send(channel.sendPort);
    await for (final message in channel) {
      if (message == null) break;
      final frame = (message as TransferableTypedData)
          .materialize()
          .asFloat32List();
      if (frame.length != 15600) throw StateError('분석 창 길이 오류');
      final watch = Stopwatch()..start();
      interpreter.run(frame, output);
      final scores = output[0];
      if (scores.any((v) => !v.isFinite || v < 0 || v > 1.00001)) {
        throw StateError('모델 점수 오류');
      }
      parent.send({
        'bark': scores[70],
        'dog': scores[69],
        'speech': scores[0],
        'milliseconds': watch.elapsedMicroseconds / 1000,
      });
    }
  } catch (_) {
    parent.send({'error': true});
  } finally {
    interpreter?.close();
    options.delete();
    channel.close();
  }
}
