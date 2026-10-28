import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/transit/crowd_timeline.dart';

void main() {
  testWidgets(
    'carriage keeps missing slots distinct from real zero and supports selection',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CrowdTimeline(slots: {360: 0, 420: 135}, boardMinute: 360),
            ),
          ),
        ),
      );
      expect(find.text('06:00 · 평균 0.0% · 예상 탑승 시간대'), findsOneWidget);
      expect(find.byKey(const ValueKey('crowd-carriage')), findsOneWidget);
      await tester.ensureVisible(find.text('06:30'));
      await tester.pump();
      await tester.tap(find.text('06:30'));
      await tester.pump();
      expect(find.text('06:30 · 통계 없음'), findsOneWidget);
      await tester.ensureVisible(find.text('07:00'));
      await tester.pump();
      await tester.tap(find.text('07:00'));
      await tester.pump();
      expect(find.text('07:00 · 평균 135.0%'), findsOneWidget);
      if (const bool.fromEnvironment('CROWD_RENDER_PREVIEW')) {
        final recorder = ui.PictureRecorder();
        CrowdCarriagePainter(
          135,
        ).paint(ui.Canvas(recorder), const Size(720, 450));
        final picture = recorder.endRecording();
        final image = await tester.runAsync(() => picture.toImage(720, 450));
        final png = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.png),
        );
        // Transport this synthetic, key-free canvas preview through CI logs.
        // ignore: avoid_print
        print(
          'CARRIAGE_RENDER_BASE64:${base64Encode(png!.buffer.asUint8List())}',
        );
        image!.dispose();
        picture.dispose();
      }

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('large text carriage stays bounded and empty data is explicit', (
    tester,
  ) async {
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
            child: CrowdTimeline(slots: {360: 20, 390: 180}, boardMinute: 360),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(home: CrowdTimeline(slots: {}, boardMinute: 360)),
    );
    expect(find.text('표시할 시간대 통계가 없습니다.'), findsOneWidget);
  });
}
