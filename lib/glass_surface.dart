import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Glass is limited to floating navigation and the summary, never data tables.
class CareGlassSurface extends StatelessWidget {
  const CareGlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.navigation = false,
  });
  final Widget child;
  final double radius;
  final bool navigation;

  @override
  Widget build(BuildContext context) {
    final reduced =
        MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final native =
        navigation &&
        !reduced &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS;
    final shape = BorderRadius.circular(radius);
    Widget backing = DecoratedBox(
      decoration: BoxDecoration(
        color: reduced ? Colors.white : null,
        gradient: reduced
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: navigation ? .80 : .88),
                  const Color(
                    0xfff5faff,
                  ).withValues(alpha: navigation ? .65 : .77),
                ],
              ),
      ),
    );
    if (native) {
      backing = UiKitView(
        viewType: 'com.barknote/liquid-glass',
        creationParams: {'radius': radius},
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (navigation && !reduced) {
      backing = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: backing,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: reduced
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x151d4063),
                  blurRadius: 26,
                  offset: Offset(0, 9),
                ),
                BoxShadow(
                  color: Color(0x10ffffff),
                  blurRadius: 2,
                  offset: Offset(0, -1),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(child: IgnorePointer(child: backing)),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: shape,
                    border: Border.all(
                      color: reduced
                          ? const Color(0xff8693a6)
                          : Colors.white.withValues(alpha: .82),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            Material(type: MaterialType.transparency, child: child),
          ],
        ),
      ),
    );
  }
}
