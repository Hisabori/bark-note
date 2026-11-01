import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass_surface.dart';

/// A single native glass capsule with a lightweight, painted selection lens.
class CareLensNavigationBar extends StatelessWidget {
  const CareLensNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  }) : assert(destinations.length > 1),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length);
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  static double height(BuildContext context) =>
      94 + math.max(0, MediaQuery.textScalerOf(context).scale(14) - 14) * 2.5;
  static double contentInset(BuildContext context) =>
      height(context) + MediaQuery.viewPaddingOf(context).bottom + 34;

  @override
  Widget build(BuildContext context) {
    final reduced =
        MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final duration = Duration(milliseconds: reduced ? 0 : 240);
    return SizedBox(
      height: height(context),
      child: LayoutBuilder(
        builder: (context, box) {
          final slot = (box.maxWidth - 12) / destinations.length;
          final lens = slot * 1.12 + 12;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 8,
                bottom: 6,
                child: CareGlassSurface(
                  navigation: true,
                  radius: height(context) / 2,
                  child: const SizedBox.expand(),
                ),
              ),
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                left: 6 + slot * (selectedIndex + .5) - lens / 2,
                width: lens,
                top: 0,
                bottom: 0,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SelectionLens(reduced: reduced),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
                  child: Row(
                    children: [
                      for (var i = 0; i < destinations.length; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: selectedIndex == i,
                            label: destinations[i].label,
                            onTap: () => onDestinationSelected(i),
                            child: ExcludeSemantics(
                              child: Material(
                                type: MaterialType.transparency,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(42),
                                  onTap: () => onDestinationSelected(i),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconTheme(
                                          data: IconThemeData(
                                            size: selectedIndex == i ? 34 : 30,
                                            color: selectedIndex == i
                                                ? const Color(0xff0062b8)
                                                : const Color(0xff343b46),
                                          ),
                                          child: selectedIndex == i
                                              ? destinations[i].selectedIcon ??
                                                    destinations[i].icon
                                              : destinations[i].icon,
                                        ),
                                        const SizedBox(height: 4),
                                        AnimatedDefaultTextStyle(
                                          duration: duration,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.15,
                                            fontWeight: selectedIndex == i
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: selectedIndex == i
                                                ? const Color(0xff0062b8)
                                                : const Color(0xff343b46),
                                          ),
                                          child: Text(
                                            destinations[i].label,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SelectionLens extends CustomPainter {
  const _SelectionLens({required this.reduced});
  final bool reduced;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    final shape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    if (reduced) {
      canvas.drawRRect(shape, Paint()..color = const Color(0xffe4effd));
      canvas.drawRRect(
        shape,
        Paint()
          ..color = const Color(0xff195bb2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      return;
    }
    final path = Path()..addRRect(shape);
    canvas.drawShadow(path, const Color(0x40192b42), 8, false);
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xb3ffffff),
            Color(0x21b8e4f5),
            Color(0x40ffffff),
            Color(0x3054b4ed),
          ],
          stops: [0, .3, .72, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      shape.deflate(2),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.5, -.9),
          radius: 1.3,
          colors: [Color(0x66ffffff), Color(0x00ffffff)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..shader = const SweepGradient(
          center: Alignment(.2, .15),
          colors: [
            Color(0xa3ffffff),
            Color(0x663fe8ed),
            Color(0x668f85fb),
            Color(0xb3ffffff),
            Color(0x555ad9bb),
            Color(0x669bcefa),
            Color(0xa3ffffff),
          ],
          stops: [0, .16, .3, .5, .66, .82, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      shape.deflate(3),
      Paint()
        ..color = const Color(0x35ffffff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
  }

  @override
  bool shouldRepaint(covariant _SelectionLens oldDelegate) =>
      oldDelegate.reduced != reduced;
}
