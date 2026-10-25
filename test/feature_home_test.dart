import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/main.dart';

void main() {
  testWidgets('feature hub opens transit and returns to both tools', (
    tester,
  ) async {
    await tester.pumpWidget(const BarkApp());
    expect(find.text('강아지 소리 분석'), findsOneWidget);
    await tester.ensureVisible(find.text('버스·지하철 · 나갈때'));
    await tester.tap(find.text('버스·지하철 · 나갈때'));
    await tester.pump();
    // Navigation must not wait for an indeterminate preference-loading
    // indicator. Storage behavior has separate real-filesystem tests.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('출발 플랜'), findsOneWidget);
    expect(find.text('버스·지하철 경로 지도'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('강아지 소리 분석'), findsOneWidget);
    expect(find.text('버스·지하철 · 나갈때'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('home supports narrow screens and large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
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
        home: const FeatureHome(),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('버스·지하철 · 나갈때'), 300);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

