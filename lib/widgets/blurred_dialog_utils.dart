import 'dart:ui';
import 'package:flutter/material.dart';

/// App-wide reusable soft-focus modal backdrop blur dialog utility.
Future<T?> showBlurredDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x73000000), // 45% dark scrim
  Duration transitionDuration = const Duration(milliseconds: 160),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: transitionDuration,
    pageBuilder: (ctx, anim1, anim2) {
      return builder(ctx);
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curvedAnim = CurvedAnimation(parent: anim1, curve: Curves.easeOutQuad);
      return Stack(
        children: [
          // Tap-outside-to-dismiss blurred backdrop + dark scrim
          GestureDetector(
            onTap: barrierDismissible ? () => Navigator.of(ctx).pop() : null,
            behavior: HitTestBehavior.opaque,
            child: FadeTransition(
              opacity: curvedAnim,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: Container(
                  color: barrierColor,
                ),
              ),
            ),
          ),
          // Dialog Content with scale and fade
          Center(
            child: FadeTransition(
              opacity: curvedAnim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(curvedAnim),
                child: Material(
                  type: MaterialType.transparency,
                  child: child,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
