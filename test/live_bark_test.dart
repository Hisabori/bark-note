import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bark_note/live_bark_page.dart';
import 'package:bark_note/live_bark_core.dart';

Uint8List pcm(int samples) {
  final bytes = Uint8List(samples * 2);
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < samples; i++) {
    view.setInt16(i * 2, (i % 65536) - 32768, Endian.little);
  }
  return bytes;
}

class FakeMic implements LiveMicrophone {
  final input = StreamController<Uint8List>.broadcast(sync: true);
  final states = StreamController<bool>.broadcast(sync: true);
  Completer<bool>? permissionGate;
  Completer<Stream<Uint8List>>? startGate;
  int starts = 0, stops = 0, disposals = 0;
  bool failStop = false;
  @override
  Future<bool> permission() async =>
      permissionGate == null ? true : await permissionGate!.future;
  @override
  Future<Stream<Uint8List>> start() async {
    starts++;
    return startGate == null ? input.stream : await startGate!.future;
  }

  @override
  Stream<bool> get interruptions => states.stream;
  @override
  Future<void> stop() async {
    stops++;
    if (failStop) throw StateError('native stop failed');
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await input.close();
    await states.close();
  }
}

class FakeScorer implements LiveBarkScorer {
  bool fail = false;
  @override
  Future<void> open() async {}
  @override
  Future<Map<String, dynamic>> score(Float32List frame) async {
    if (fail) throw StateError('test');
    return {'bark': .8, 'dog': .8, 'speech': .1, 'milliseconds': 1};
  }

  @override
  Future<void> close() async {}
}

Future<void> flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'PCM windows preserve split samples, sample order and exact overlap',
    () {
      final bytes = pcm(15600 + 7680 * 2);
      final a = PcmBarkWindow(), b = PcmBarkWindow();
      final x = <Float32List>[], y = <Float32List>[];
      final ends = <double>[];
      a.add(bytes, (frame, end) {
        x.add(frame);
        ends.add(end);
      });
      for (var i = 0; i < bytes.length; i += 127) {
        b.add(
          Uint8List.sublistView(
            bytes,
            i,
            (i + 127).clamp(0, bytes.length).toInt(),
          ),
          (frame, end) => y.add(frame),
        );
      }
      expect(x.length, 3);
      expect(y, x);
      expect(ends, [.975, 1.455, 1.935]);
      expect(x.first.first, -1);
      expect(x[1].first, x[0][7680]);
      b.clear();
      expect(b.samples, 0);
      expect(b.lowByte, isNull);
      expect(b.ring.every((v) => v == 0), isTrue);
    },
  );
  test(
    'slow inference keeps only the latest pending frame and close rejects late results',
    () async {
      final requests = <Completer<Map<String, dynamic>>>[];
      final inputs = <double>[];
      final results = <double>[];
      final q = LatestBarkQueue(
        (frame) {
          inputs.add(frame.first);
          final c = Completer<Map<String, dynamic>>();
          requests.add(c);
          return c.future;
        },
        (value, end) => results.add(end),
        (error) => fail('unexpected error'),
      );
      q.add(Float32List.fromList([0]), 0);
      q.add(Float32List.fromList([1]), 1);
      q.add(Float32List.fromList([2]), 2);
      expect(q.dropped, 1);
      expect(inputs, [0]);
      requests[0].complete({});
      await flush();
      expect(inputs, [0, 2]);
      expect(results, [0]);
      q.close();
      requests[1].complete({});
      await flush();
      expect(results, [0]);
      expect(q.pending, isNull);
    },
  );
  test(
    'background stop while permission is pending never starts the microphone',
    () async {
      final mic = FakeMic()..permissionGate = Completer<bool>();
      var engines = 0;
      final s = LiveBarkSession(
        microphone: mic,
        scorerFactory: () {
          engines++;
          return FakeScorer();
        },
        changed: () {},
      );
      final opening = s.start();
      await flush();
      await s.stop();
      mic.permissionGate!.complete(true);
      await opening;
      expect(mic.starts, 0);
      expect(engines, 0);
      expect(s.running, isFalse);
      await s.dispose();
    },
  );
  test(
    'restart is blocked until a cancelled native start has settled',
    () async {
      final mic = FakeMic()..startGate = Completer<Stream<Uint8List>>();
      final s = LiveBarkSession(
        microphone: mic,
        scorerFactory: FakeScorer.new,
        changed: () {},
      );
      final opening = s.start();
      await flush();
      expect(mic.starts, 1);
      await s.stop();
      await s.start();
      expect(mic.starts, 1);
      mic.startGate!.complete(mic.input.stream);
      await opening;
      expect(s.running, isFalse);
      expect(s.opening, isFalse);
      await s.dispose();
    },
  );
  test(
    'live scores arrive and interruption clears microphone buffers',
    () async {
      final mic = FakeMic();
      final s = LiveBarkSession(
        microphone: mic,
        scorerFactory: FakeScorer.new,
        changed: () {},
      );
      await s.start();
      mic.input.add(pcm(15600));
      await flush();
      expect(s.processed, 1);
      expect(s.positive, 1);
      mic.states.add(true);
      await flush();
      expect(s.running, isFalse);
      expect(s.pcm.samples, 0);
      expect(s.pcm.ring.every((v) => v == 0), isTrue);
      expect(mic.stops, greaterThan(0));
      await s.dispose();
    },
  );
  test(
    'model failure stops capture instead of leaving a silent live session',
    () async {
      final mic = FakeMic();
      final s = LiveBarkSession(
        microphone: mic,
        scorerFactory: () => FakeScorer()..fail = true,
        changed: () {},
      );
      await s.start();
      mic.input.add(pcm(15600));
      await flush();
      expect(s.running, isFalse);
      expect(s.latest, isNull);
      expect(s.pcm.samples, 0);
      await s.dispose();
    },
  );
  test('a native stop failure disposes capture and blocks reuse', () async {
    final mic = FakeMic();
    final s = LiveBarkSession(
      microphone: mic,
      scorerFactory: FakeScorer.new,
      changed: () {},
    );
    await s.start();
    mic.failStop = true;
    await s.stop();
    expect(s.unavailable, isTrue);
    expect(mic.disposals, greaterThan(0));
    await s.start();
    expect(mic.starts, 1);
    await s.dispose();
  });
  testWidgets(
    'live page waits for user action and stops capture on background',
    (tester) async {
      final mic = FakeMic();
      await tester.pumpWidget(
        MaterialApp(
          home: LiveBarkPage(
            microphoneFactory: () => mic,
            scorerFactory: FakeScorer.new,
          ),
        ),
      );
      expect(mic.starts, 0);
      await Scrollable.ensureVisible(
        tester.element(find.text('실시간 분석 시작')),
        alignment: .3,
      );
      await tester.pump();
      await tester.tap(find.text('실시간 분석 시작'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(mic.starts, 1);
      await tester.runAsync(() async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await flush();
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(mic.stops, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
