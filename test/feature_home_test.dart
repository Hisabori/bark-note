import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/main.dart';

void main() {
  testWidgets('feature hub opens transit and returns to both tools', (
    tester,
  ) async {
    await tester.pumpWidget(const BarkApp());
    await tester.scrollUntilVisible(
      find.text('소리 분석'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('소리 분석'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('길찾기'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('길찾기')),
      alignment: .25,
    );
    await tester.pump();
    await tester.tap(find.text('길찾기'));
    await tester.pump();
    // Navigation must not wait for an indeterminate preference-loading
    // indicator. Storage behavior has separate real-filesystem tests.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('출발 플랜'), findsOneWidget);
    expect(find.text('지금 나가면 탈 수 있을까?'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('소리 분석'), findsOneWidget);
    expect(find.text('길찾기'), findsOneWidget);
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
    await tester.scrollUntilVisible(find.text('길찾기'), 300);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'normal mode remains bright when the device uses dark appearance',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(const BarkApp());
      final theme = Theme.of(tester.element(find.text('함께하는 하루')));
      expect(theme.brightness, Brightness.light);
      expect(theme.cardColor, Colors.white);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
