import 'dart:math';

import 'package:flutter/material.dart';

class CatAvatar extends StatelessWidget {
  const CatAvatar({
    super.key,
    this.open = 0,
    this.smile = 0,
    this.round = 0,
    this.happy = false,
    this.accessory = false,
  });
  final double open;
  final double smile;
  final double round;
  final bool happy;
  final bool accessory;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3990 / 4019,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            happy ? 'assets/cat_happy.png' : 'assets/cat.png',
            fit: BoxFit.fill,
            cacheWidth: 720,
            excludeFromSemantics: true,
          ),
          CustomPaint(
            painter: _Expression(open, smile, round, happy, accessory),
          ),
        ],
      ),
    );
  }
}

class _Expression extends CustomPainter {
  const _Expression(
    this.open,
    this.smile,
    this.round,
    this.happy,
    this.accessory,
  );
  final double open, smile, round;
  final bool happy, accessory;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    final openness = (open * 2.25).clamp(0.0, 1.0);
    final grin = (smile * 2.5).clamp(0.0, 1.0);
    final pucker = (round * 2.0).clamp(0.0, 1.0);
    if (!happy && max(openness, max(grin, pucker)) > 0.025) {
      final patch = Rect.fromCenter(
        center: const Offset(.561, .415),
        width: .178,
        height: .137,
      );
      canvas.drawOval(
        patch,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xfffbaa27), Color(0xfffcab29), Color(0x00fcac2e)],
            stops: [0, .81, 1],
          ).createShader(patch),
      );
      final ink = Paint()..color = const Color(0xff301a24);
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(.561, .365),
          width: .032,
          height: .031,
        ),
        ink,
      );
      final w = .084 + grin * .057 - pucker * .052;
      final top = .402 - grin * .021;
      final left = .561 - w / 2;
      final right = .561 + w / 2;
      final bottom = .425 + openness * .043 + pucker * .012;
      final mouth = Path()
        ..moveTo(left, top)
        ..quadraticBezierTo(.561, top + .015 + grin * .020, right, top)
        ..cubicTo(right, bottom, left, bottom, left, top)
        ..close();
      canvas.drawPath(mouth, ink);
      if (openness > .22) {
        canvas.save();
        canvas.clipPath(mouth);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(.561, bottom - .002),
            width: w * .60,
            height: .034,
          ),
          Paint()..color = const Color(0xfffa838c),
        );
        canvas.restore();
      }
    }
    if (accessory) {
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final angle = pi * i / 5 - pi / 2;
        final radius = i.isEven ? .050 : .024;
        final x = .785 + cos(angle) * radius;
        final y = .260 + sin(angle) * radius;
        if (i == 0) {
          star.moveTo(x, y);
        } else {
          star.lineTo(x, y);
        }
      }
      star.close();
      canvas.drawPath(
        star,
        Paint()
          ..color = const Color(0xff6447b9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .010
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(star, Paint()..color = const Color(0xffede4ff));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Expression old) =>
      old.open != open ||
      old.smile != smile ||
      old.round != round ||
      old.accessory != accessory ||
      old.happy != happy;
}
