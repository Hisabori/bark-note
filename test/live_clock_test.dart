import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/transit/live_clock.dart';

class CountedChild extends StatelessWidget {
  const CountedChild(this.onBuild, {super.key});
  final VoidCallback onBuild;
  @override
  Widget build(BuildContext context) {
    onBuild();
    return const Text('Map');
  }
}

void main() {
  testWidgets('clock keeps expensive child stable and stops while hidden', (
    tester,
  ) async {
    var ticks = 0, childBuilds = 0;
    var visible = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return TickerMode(
              enabled: visible,
              child: LiveClock(
                child: CountedChild(() => childBuilds++),
                builder: (context, now, child) {
                  ticks++;
                  return child!;
                },
              ),
            );
          },
        ),
      ),
    );
    final initial = ticks;
    await tester.pump(const Duration(seconds: 2));
    expect(ticks, greaterThan(initial));
    expect(childBuilds, 1);
    update(() => visible = false);
    await tester.pump();
    final hidden = ticks;
    await tester.pump(const Duration(seconds: 3));
    expect(ticks, hidden);
    update(() => visible = true);
    await tester.pump();
    final resumed = ticks;
    await tester.pump(const Duration(seconds: 1));
    expect(ticks, greaterThan(resumed));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
