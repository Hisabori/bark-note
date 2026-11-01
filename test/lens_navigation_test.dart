import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/app_theme.dart';
import 'package:bark_note/lens_navigation.dart';

const destinations = [
  NavigationDestination(icon: Icon(Icons.schedule), label: '출발 플랜'),
  NavigationDestination(icon: Icon(Icons.train), label: '실시간 열차'),
  NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
];
void main() {
  testWidgets(
    'lens moves with tab selection and exposes each label once to accessibility',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, update) => Padding(
                padding: const EdgeInsets.all(20),
                child: CareLensNavigationBar(
                  selectedIndex: selected,
                  onDestinationSelected: (i) => update(() => selected = i),
                  destinations: destinations,
                ),
              ),
            ),
          ),
        ),
      );
      final before = tester
          .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
          .left!;
      expect(find.bySemanticsLabel('실시간 열차'), findsOneWidget);
      await tester.tap(find.text('실시간 열차'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(selected, 1);
      expect(
        tester
            .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
            .left!,
        greaterThan(before),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      } finally { semantics.dispose(); }
    },
  );
  testWidgets(
    'narrow navigation grows for large text without overflow or overlapping targets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              bottomNavigationBar: Padding(
                padding: const EdgeInsets.all(16),
                child: CareLensNavigationBar(
                  selectedIndex: 1,
                  onDestinationSelected: (_) {},
                  destinations: destinations,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(CareLensNavigationBar)).height,
        greaterThan(100),
      );
      expect(find.text('실시간 열차'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('reduced motion uses static selection and opaque navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            bottomNavigationBar: CareLensNavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: destinations,
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
          .duration,
      Duration.zero,
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
