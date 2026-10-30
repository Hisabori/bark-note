import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/app_theme.dart';
import 'package:bark_note/glass_surface.dart';

void main() {
  testWidgets('glass backdrop keeps navigation taps and selection working', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          bottomNavigationBar: CareGlassSurface(
            navigation: true,
            child: StatefulBuilder(
              builder: (context, update) => NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (value) =>
                    update(() => selected = value),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: '오늘'),
                  NavigationDestination(icon: Icon(Icons.train), label: '이동'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tap(find.text('이동'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(selected, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'high contrast uses opaque material instead of blur or a native view',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(highContrast: true),
            child: const Scaffold(
              body: CareGlassSurface(
                navigation: true,
                child: SizedBox(width: 300, height: 76, child: Text('출발 안내')),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(UiKitView), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('출발 안내'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'summary adds no backdrop filter and reduced motion disables navigation blur',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CareGlassSurface(
                  child: SizedBox(height: 100, child: Text('요약')),
                ),
                MediaQuery(
                  data: MediaQueryData(disableAnimations: true),
                  child: CareGlassSurface(
                    navigation: true,
                    child: SizedBox(height: 76, child: Text('탭')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
