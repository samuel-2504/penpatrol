import 'package:flutter/material.dart';

class AdaptiveRatioWrapper extends StatelessWidget {
  final Widget child;

  const AdaptiveRatioWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait = constraints.maxHeight > constraints.maxWidth;

        if (isPortrait) {
          // PORTRAIT: Enforce strict 9:16 aspect ratio locked frame
          return Container(
            color: Colors.black, // Background fill for letterboxing margins
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRect(
                  child: child,
                ),
              ),
            ),
          );
        } else {
          // LANDSCAPE: Allow content to stretch fully across the available screen width/height
          return SizedBox.expand(
            child: child,
          );
        }
      },
    );
  }
}
