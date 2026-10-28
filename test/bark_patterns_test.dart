import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/bark_patterns.dart';
import 'package:bark_note/bark_report.dart';
import 'package:bark_note/emotion.dart';

void main() {
  test(
    'overlapping events are not double counted and long pauses split bouts',
    () {
      final r = summarizeBarkPatterns({
        'duration': 10,
        'ai': {},
        'verifiedSegments': [
          {'start': 5, 'end': 6},
          {'start': 1, 'end': 2},
          {'start': 1.5, 'end': 2.5},
          {'start': 3, 'end': 3.2},
        ],
      })!;
      expect(r.verified, isTrue);
      expect(r.count, 4);
      expect(r.activeSeconds, closeTo(2.7, .0001));
      expect(r.bouts.length, 2);
      expect(r.bouts.first.count, 3);
      expect(r.medianGap, closeTo(.5, .0001));
    },
  );
  test(
    'invalid events are omitted and invalid recording duration is explicit',
    () {
      expect(summarizeBarkPatterns({'duration': double.nan}), isNull);
      final r = summarizeBarkPatterns({
        'duration': 5,
        'segments': [
          {'start': -1, 'end': 1},
          {'start': 3, 'end': 2},
          {'start': 1, 'end': 8},
          {'start': double.nan, 'end': 2},
          {'start': 1, 'end': 2},
        ],
      })!;
      expect(r.verified, isFalse);
      expect(r.count, 1);
      expect(r.activeSeconds, 1);
      expect(r.medianGap, isNull);
    },
  );
  test(
    'failed or absent model never produces a new emotion interpretation',
    () {
      final segments = [
        {'start': 1, 'end': 2},
        {'start': 3, 'end': 4},
      ];
      for (final audio in [
        {'segments': segments},
        {'ai': {}, 'aiError': 'failed', 'verifiedSegments': segments},
      ]) {
        expect(interpretEmotion(audio, 'play')['label'], '판단 보류');
      }
      expect(
        interpretEmotion({
          'ai': {},
          'verifiedSegments': [
            {'start': 'bad', 'end': 2},
          ],
        }, 'play')['label'],
        '판단 보류',
      );
    },
  );
  testWidgets('pattern report supports large text and legacy records', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: BarkPatternReport(
              audio: {
                'duration': 20,
                'segments': [
                  {'start': 1, 'end': 2},
                ],
              },
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('음량으로 찾은 소리 후보 기준 · 짖음 확인 전'), findsOneWidget);
    await tester.pumpWidget(
      const MaterialApp(home: BarkPatternReport(audio: {})),
    );
    expect(find.text('이 기록에는 패턴을 계산할 녹음 정보가 없습니다.'), findsOneWidget);
  });
}
