import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/transit/live_plan.dart';
import 'package:bark_note/transit/departure_brief.dart';
import 'package:bark_note/transit/activity_payload.dart';
import 'package:bark_note/transit/planner.dart';

void main() {
  final now = DateTime.utc(2026, 10, 30);
  Map<String, dynamic> train(int minutes) => {
    'fresh': true,
    'receivedAt': now.toIso8601String(),
    'eta': now.add(Duration(minutes: minutes)).toIso8601String(),
  };
  test(
    'preparation and platform margin determine catchability independently',
    () {
      final e = boardingEstimate(
        train(20),
        10,
        now,
        marginMinutes: 3,
        preparationMinutes: 5,
      )!;
      expect(e.canCatch, isTrue);
      expect(e.spareSeconds, 120);
      expect(e.prepareBy, now.add(const Duration(minutes: 2)));
      expect(e.leaveBy, now.add(const Duration(minutes: 7)));
      expect(
        boardingEstimate(
          train(17),
          10,
          now,
          marginMinutes: 3,
          preparationMinutes: 5,
        )!.canCatch,
        isFalse,
      );
      expect(
        boardingEstimate(
          train(18),
          10,
          now,
          marginMinutes: 3,
          preparationMinutes: 5,
        )!.canCatch,
        isTrue,
      );
    },
  );
  test(
    'invalid inputs and malformed or expired source cannot recommend a train',
    () {
      expect(boardingEstimate(train(20), 10, now, marginMinutes: 31), isNull);
      expect(
        boardingEstimate(train(20), 10, now, preparationMinutes: -1),
        isNull,
      );
      expect(
        boardingEstimate(train(20), 10, now, preparationMinutes: 121),
        isNull,
      );
      expect(boardingEstimate({...train(20), 'eta': 42}, 10, now), isNull);
      expect(
        boardingEstimate(train(20), 10, now.add(const Duration(seconds: 121))),
        isNull,
      );
    },
  );
  test(
    'island departure remains the door departure, not preparation alarm time',
    () {
      final t = train(20);
      final e = boardingEstimate(
        t,
        10,
        now,
        marginMinutes: 3,
        preparationMinutes: 5,
      )!;
      final payload = trainActivityPayload(e, t, '강남', '2호선', now);
      expect(payload['leaveEpoch'], e.leaveBy.millisecondsSinceEpoch);
      expect(payload['leaveEpoch'], isNot(e.prepareBy.millisecondsSinceEpoch));
    },
  );
  test('countdown retains seconds and never displays negative minutes', () {
    expect(departureCountdown(const Duration(seconds: 61)), '1분 1초');
    expect(departureCountdown(const Duration(seconds: -1)), '시각 지남');
    expect(departureCountdown(Duration.zero), '0초');
  });
  testWidgets(
    'departure timeline includes preparation, exit, ETA and deadline on narrow large-text screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final e = boardingEstimate(train(20), 10, now, preparationMinutes: 5)!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: DepartureBrief(
                    estimate: e,
                    now: now,
                    received: now,
                    preparation: 5,
                    walk: 10,
                    margin: 1,
                    journey: Journey(
                      deadline: now.add(const Duration(minutes: 30)),
                      walkToPlatform: 10,
                      rideAndTransfer: 20,
                      wait: 5,
                      exitWalk: 5,
                      buffer: 5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('준비 시작 ·'), findsOneWidget);
      expect(find.textContaining('집에서 출발 ·'), findsOneWidget);
      expect(find.textContaining('목표 도착까지 여유가 부족'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
