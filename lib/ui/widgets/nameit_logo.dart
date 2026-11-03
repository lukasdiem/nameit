import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The nameIT app icon: a lowercase "n" that doubles as a person, with a
/// mint head, on a violet rounded square. Drawn in code so it stays sharp at
/// every size and needs no image asset.
class NameItLogo extends StatelessWidget {
  const NameItLogo({super.key, this.size = 48, this.dark = false});

  final double size;

  /// Ink background with a light violet "n", for dark surfaces.
  final bool dark;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'nameIT',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _LogoPainter(dark: dark)),
        ),
      );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas.scale(s);

    // Background: the same corner ratio as an iOS icon.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(22.5)),
      Paint()..color = dark ? Brand.ink : Brand.violet,
    );

    // Artwork sits in the middle 72 % (the Android safe zone).
    canvas.translate(14, 14);
    canvas.scale(0.72);

    final n = Path()
      ..moveTo(28, 88)
      ..lineTo(28, 60)
      ..arcTo(Rect.fromCircle(center: const Offset(50, 60), radius: 22), math.pi, math.pi, false)
      ..lineTo(72, 88);
    canvas.drawPath(
      n,
      Paint()
        ..color = dark ? Brand.violetLight : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(const Offset(50, 15), 11, Paint()..color = Brand.mint);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.dark != dark;
}

/// "nameIT" with the "IT" in the brand colour.
class NameItWordmark extends StatelessWidget {
  const NameItWordmark({super.key, this.fontSize = 24});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'name', style: TextStyle(color: scheme.onSurface)),
        TextSpan(text: 'IT', style: TextStyle(color: scheme.primary)),
      ]),
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.1),
    );
  }
}

/// Icon and wordmark side by side, for the home screen's app bar.
class NameItLockup extends StatelessWidget {
  const NameItLockup({super.key, this.height = 32});
  final double height;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        NameItLogo(size: height),
        SizedBox(width: height * 0.3),
        // Shrinks instead of overflowing when the app bar actions leave little room.
        Flexible(
          child: FittedBox(fit: BoxFit.scaleDown, child: NameItWordmark(fontSize: height * 0.75)),
        ),
      ]);
}
