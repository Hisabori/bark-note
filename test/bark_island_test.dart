import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/bark_island.dart';

Future<void> flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('updates are throttled while stop bypasses throttle', () async {
    var now = DateTime.utc(2026);
    final calls = <String>[];
    final bridge = BarkIslandBridge(
      clock: () => now,
      changed: () {},
      send: (method, args) async {
        calls.add(method);
        return true;
      },
    );
    bridge.update({'elapsed': 0});
    await flush();
    bridge.update({'elapsed': 1});
    now = now.add(const Duration(seconds: 3));
    bridge.update({'elapsed': 3});
    await flush();
    bridge.update(null);
    await flush();
    expect(calls, ['barkSync', 'barkSync', 'barkEnd']);
    bridge.dispose();
  });
  test(
    'stop is an ordering barrier even when restart races a native request',
    () async {
      var now = DateTime.utc(2026);
      final gate = Completer<bool?>();
      final calls = <String>[];
      final bridge = BarkIslandBridge(
        clock: () => now,
        changed: () {},
        send: (method, args) {
          calls.add('$method:${args?['elapsed']}');
          return calls.length == 1 ? gate.future : Future.value(true);
        },
      );
      bridge.update({'elapsed': 0});
      now = now.add(const Duration(seconds: 3));
      bridge.update({'elapsed': 3});
      bridge.update(null);
      bridge.update({'elapsed': 0});
      gate.complete(false);
      await flush();
      expect(calls, ['barkSync:0', 'barkEnd:null', 'barkSync:0']);
      expect(bridge.failed, isFalse);
      bridge.dispose();
      await flush();
    },
  );
  test(
    'denied island does not repeatedly retry and next session may retry',
    () async {
      var now = DateTime.utc(2026);
      final calls = <String>[];
      final bridge = BarkIslandBridge(
        clock: () => now,
        changed: () {},
        send: (method, args) async {
          calls.add(method);
          return false;
        },
      );
      bridge.update({'elapsed': 0});
      await flush();
      now = now.add(const Duration(seconds: 5));
      bridge.update({'elapsed': 5});
      expect(calls.length, 1);
      bridge.update(null);
      await flush();
      bridge.update({'elapsed': 0});
      await flush();
      expect(calls, ['barkSync', 'barkEnd', 'barkSync']);
      bridge.dispose();
      await flush();
    },
  );
  test(
    'stale, nonfinite and missing scores cannot appear as current detection',
    () {
      final now = DateTime.utc(2026);
      Map<String, dynamic> snapshot(
        DateTime? updated,
        Map<String, dynamic>? scores, {
        bool delayed = false,
      }) => barkIslandSnapshot(
        elapsed: double.nan,
        processed: 2,
        positive: 999,
        scores: scores,
        updated: updated,
        now: now,
        delayed: delayed,
      );
      final fresh = snapshot(now, {'bark': .9});
      expect(fresh['signal'], 'bark');
      expect(fresh['barkPercent'], 90);
      expect(fresh['elapsed'], 0);
      expect(fresh['positive'], 2);
      expect(
        snapshot(now.subtract(const Duration(seconds: 4)), {
          'bark': 1,
        })['signal'],
        'waiting',
      );
      expect(snapshot(now, {'bark': double.nan})['barkPercent'], 0);
      expect(snapshot(null, null)['signal'], 'waiting');
      expect(snapshot(now, {'bark': 1}, delayed: true)['signal'], 'waiting');
      expect(
        fresh.keys,
        unorderedEquals([
          'elapsed',
          'processed',
          'positive',
          'signal',
          'barkPercent',
        ]),
      );
    },
  );
  test('disposal ends activity and prevents later starts', () async {
    final calls = <String>[];
    final bridge = BarkIslandBridge(
      changed: () {},
      send: (method, args) async {
        calls.add(method);
        return true;
      },
    );
    bridge.update({'elapsed': 0});
    await flush();
    bridge.dispose();
    bridge.update({'elapsed': 5});
    await flush();
    expect(calls, ['barkSync', 'barkEnd']);
  });
}
