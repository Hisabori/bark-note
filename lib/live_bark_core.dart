import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

abstract interface class LiveMicrophone {
  Future<bool> permission();
  Future<Stream<Uint8List>> start();
  Stream<bool> get interruptions;
  Future<void> stop();
  Future<void> dispose();
}

abstract interface class LiveBarkScorer {
  Future<void> open();
  Future<Map<String, dynamic>> score(Float32List frame);
  Future<void> close();
}

class PcmBarkWindow {
  static const length = 15600, hop = 7680, rate = 16000;
  final ring = Float32List(length);
  int samples = 0, write = 0;
  int? lowByte;
  double db = -120;
  void add(Uint8List bytes, void Function(Float32List, double) onWindow) {
    double energy = 0;
    int count = 0;
    for (final byte in bytes) {
      if (lowByte == null) {
        lowByte = byte;
        continue;
      }
      var signed = lowByte! | byte << 8;
      lowByte = null;
      if (signed >= 32768) signed -= 65536;
      final value = signed / 32768;
      energy += value * value;
      count++;
      ring[write] = value;
      write = (write + 1) % length;
      samples++;
      if (samples >= length && (samples - length) % hop == 0) {
        final frame = Float32List(length);
        for (var i = 0; i < length; i++) {
          frame[i] = ring[(write + i) % length];
        }
        onWindow(frame, samples / rate);
      }
    }
    if (count > 0) {
      db =
          20 *
          math.log(math.max(math.sqrt(energy / count), .000001)) /
          math.ln10;
    }
  }

  void clear() {
    ring.fillRange(0, length, 0);
    lowByte = null;
    samples = 0;
    write = 0;
    db = -120;
  }
}

/// At most one active request and one latest pending window; no growing queue.
class LatestBarkQueue {
  LatestBarkQueue(this.process, this.result, this.failure);
  final Future<Map<String, dynamic>> Function(Float32List) process;
  final void Function(Map<String, dynamic>, double) result;
  final void Function(Object) failure;
  bool busy = false, closed = false;
  int dropped = 0;
  (Float32List, double)? pending;
  void add(Float32List frame, double end) {
    if (closed) return;
    if (busy) {
      if (pending != null) dropped++;
      pending = (frame, end);
      return;
    }
    unawaited(run(frame, end));
  }

  Future<void> run(Float32List frame, double end) async {
    busy = true;
    try {
      final value = await process(frame);
      if (!closed) result(value, end);
    } catch (e) {
      if (!closed) failure(e);
    } finally {
      busy = false;
      final next = pending;
      pending = null;
      if (!closed && next != null) add(next.$1, next.$2);
    }
  }

  void close() {
    closed = true;
    pending = null;
  }
}

class LiveBarkSession {
  LiveBarkSession({
    required this.microphone,
    required this.scorerFactory,
    required this.changed,
  });
  final LiveMicrophone microphone;
  final LiveBarkScorer Function() scorerFactory;
  final void Function() changed;
  final pcm = PcmBarkWindow();
  LiveBarkScorer? scorer;
  LatestBarkQueue? queue;
  StreamSubscription<Uint8List>? audio;
  StreamSubscription<bool>? interruption;
  Timer? ticker;
  int generation = 0, processed = 0, positive = 0, skipped = 0;
  bool starting = false, running = false, disposed = false, opening = false;
  bool unavailable = false;
  final wallClock = Stopwatch();
  DateTime? lastInput;
  String message = '시작을 누르면 마이크를 사용합니다.';
  Map<String, dynamic>? latest;
  DateTime? updated;
  double latestEnd = 0, elapsed = 0, level = -120;
  Future<void>? stopping, startup;
  bool valid(int token) => !disposed && generation == token;
  void notify() {
    if (!disposed) changed();
  }

  Future<void> start() {
    if (disposed ||
        unavailable ||
        opening ||
        starting ||
        running ||
        stopping != null) {
      return Future<void>.value();
    }
    final task = startNow();
    startup = task;
    return task.whenComplete(() {
      if (identical(startup, task)) startup = null;
    });
  }

  Future<void> startNow() async {
    if (disposed ||
        unavailable ||
        opening ||
        starting ||
        running ||
        stopping != null)
      return;
    final token = ++generation;
    starting = true;
    opening = true;
    latest = null;
    latestEnd = 0;
    updated = null;
    processed = 0;
    positive = 0;
    skipped = 0;
    elapsed = 0;
    level = -120;
    pcm.clear();
    message = '마이크와 기기 내 모델을 준비하고 있어요.';
    notify();
    LiveBarkScorer? local;
    try {
      final allowed = await microphone.permission();
      if (!valid(token)) return;
      if (!allowed) throw StateError('마이크 권한이 필요합니다. 기기 설정에서 허용해주세요.');
      local = scorerFactory();
      scorer = local;
      await local.open();
      if (!valid(token)) {
        await local.close();
        return;
      }
      final stream = await microphone.start();
      if (!valid(token)) {
        await microphone.stop();
        await local.close();
        return;
      }
      wallClock.reset();
      wallClock.start();
      lastInput = DateTime.now();
      running = true;
      starting = false;
      message = '기기에서 실시간 분석 중 · 약 1초 단위';
      queue = LatestBarkQueue(
        local.score,
        (value, end) {
          if (!valid(token) || !running) return;
          processed++;
          if ((value['bark'] as num) >= .3) positive++;
          latest = value;
          updated = DateTime.now();
          latestEnd = end;
          notify();
        },
        (error) {
          if (valid(token)) unawaited(stop('분석이 중단됐습니다. 다시 시작해주세요.'));
        },
      );
      audio = stream.listen(
        (bytes) {
          if (valid(token) && running) {
            lastInput = DateTime.now();
            pcm.add(bytes, (frame, end) => queue?.add(frame, end));
          }
        },
        onError: (Object error) {
          if (valid(token)) unawaited(stop('마이크 입력이 중단됐습니다.'));
        },
        onDone: () {
          if (valid(token) && running) unawaited(stop('마이크 입력이 종료됐습니다.'));
        },
      );
      interruption = microphone.interruptions.listen(
        (interrupted) {
          if (valid(token) && interrupted && running) {
            unawaited(stop('통화 또는 마이크 중단으로 분석을 멈췄습니다.'));
          }
        },
        onError: (Object error) {
          if (valid(token)) unawaited(stop('마이크 상태를 확인하지 못해 중지했습니다.'));
        },
      );
      ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!valid(token) || !running) return;
        elapsed = pcm.samples / PcmBarkWindow.rate;
        level = pcm.db;
        skipped = queue?.dropped ?? 0;
        if (lastInput != null &&
            DateTime.now().difference(lastInput!) >
                const Duration(seconds: 5)) {
          unawaited(stop('마이크 입력이 없어 분석을 중지했습니다.'));
          return;
        }
        if (wallClock.elapsed >= const Duration(minutes: 5)) {
          unawaited(stop('5분 분석을 마쳤습니다. 다시 시작할 수 있어요.'));
          return;
        }
        notify();
      });
      notify();
    } catch (e) {
      if (valid(token)) {
        await stop(e.toString().replaceFirst('Bad state: ', ''));
      } else if (local != null) {
        await local.close();
      }
    } finally {
      opening = false;
      if (valid(token)) starting = false;
      notify();
    }
  }

  Future<void> stop([String reason = '분석을 중지했습니다.']) {
    if (stopping != null) return stopping!;
    final task = stopNow(reason);
    stopping = task;
    return task.whenComplete(() {
      if (identical(stopping, task)) {
        stopping = null;
        notify();
      }
    });
  }

  Future<void> stopNow(String reason) async {
    generation++;
    running = false;
    starting = false;
    wallClock.stop();
    message = reason;
    elapsed = pcm.samples / PcmBarkWindow.rate;
    level = pcm.db;
    skipped = queue?.dropped ?? skipped;
    ticker?.cancel();
    ticker = null;
    queue?.close();
    queue = null;
    final a = audio, b = interruption;
    audio = null;
    interruption = null;
    final engine = scorer;
    scorer = null;
    pcm.clear();
    notify();
    try {
      await a?.cancel();
    } catch (_) {
      /* Continue through native stop. */
    }
    try {
      await b?.cancel();
    } catch (_) {
      /* Continue through native stop. */
    }
    try {
      await microphone.stop();
    } catch (_) {
      unavailable = true;
      message = '마이크 정리 중 오류가 발생했습니다. 앱을 다시 열어주세요.';
      try {
        await microphone.dispose();
      } catch (_) {
        /* Reported above. */
      }
    }
    try {
      await engine?.close();
    } catch (_) {
      message = '분석 작업 정리 중 오류가 발생했습니다. 앱을 다시 열어주세요.';
    }
    notify();
  }

  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await stop();
    await startup;
    try {
      await microphone.dispose();
    } catch (_) {
      /* Already closed after a capture error. */
    }
  }
}
