import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass_surface.dart';

/// A compact iPhone-style glass tab bar with an inset selection capsule.
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
      74 + math.max(0, MediaQuery.textScalerOf(context).scale(12) - 12) * 3;
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
          final lens = slot - 4;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
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
                top: 6,
                bottom: 6,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: reduced
                            ? const Color(0xffe4effd)
                            : const Color(0xb3e9edf3),
                        borderRadius: BorderRadius.circular(
                          height(context) / 2,
                        ),
                        border: Border.all(
                          color: reduced
                              ? const Color(0xff5577a3)
                              : const Color(0x80ffffff),
                          width: .7,
                        ),
                      ),
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
                                            size: 26,
                                            color: selectedIndex == i
                                                ? const Color(0xff0062b8)
                                                : const Color(0xff5c6470),
                                          ),
                                          child: selectedIndex == i
                                              ? destinations[i].selectedIcon ??
                                                    destinations[i].icon
                                              : destinations[i].icon,
                                        ),
                                        const SizedBox(height: 3),
                                        AnimatedDefaultTextStyle(
                                          duration: duration,
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.15,
                                            fontWeight: selectedIndex == i
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: selectedIndex == i
                                                ? const Color(0xff0062b8)
                                                : const Color(0xff5c6470),
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
