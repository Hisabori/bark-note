import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/main.dart';

void main() {
  testWidgets('feature hub opens transit and returns to both tools', (
    tester,
  ) async {
    await tester.pumpWidget(const BarkApp());
    expect(find.text('강아지 소리 분석'), findsOneWidget);
    await tester.tap(find.text('버스·지하철 · 나갈때'));
    await tester.pump();
    // The place book reads real filesystem data. Let that IO complete outside
    // the fake animation clock before waiting for the progress bar to settle.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();
    expect(find.text('출발 플랜'), findsOneWidget);
    expect(find.text('버스·지하철 경로 지도'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('강아지 소리 분석'), findsOneWidget);
    expect(find.text('버스·지하철 · 나갈때'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
