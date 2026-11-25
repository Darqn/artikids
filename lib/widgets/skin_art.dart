import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/pet.dart';

class SkinArt extends CustomPainter {
  const SkinArt(this.skin, this.character);
  final PetSkin skin;
  final Character character;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final cat = character == Character.cat;
    final x = cat ? 56.0 : 50.0;
    final neck = cat ? 53.0 : 69.0;
    final head = cat ? 34.0 : 49.0;
    final gold = Paint()..color = const Color(0xffffd459);
    final dark = Paint()..color = const Color(0xff70453c);
    switch (skin) {
      case PetSkin.classic:
        break;
      case PetSkin.bee:
        for (final side in [-1, 1]) {
          final wing = Rect.fromCenter(
            center: Offset(x + side * 22, neck + 9),
            width: 20,
            height: 12,
          );
          canvas.drawOval(wing, Paint()..color = const Color(0xbbe4f8ff));
          canvas.drawOval(
            wing,
            Paint()
              ..color = const Color(0xff72b4c5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, neck + 8), width: 32, height: 12),
          gold,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, neck + 8), width: 29, height: 3),
            const Radius.circular(2),
          ),
          dark,
        );
      case PetSkin.gardener:
        final green = Paint()..color = const Color(0xff287b5f);
        final fresh = Paint()..color = const Color(0xff8ccf78);
        canvas.drawPath(
          Path()
            ..moveTo(x, neck + 4)
            ..quadraticBezierTo(x - 20, neck - 8, x - 14, neck + 5)
            ..quadraticBezierTo(x - 9, neck + 15, x, neck + 4)
            ..quadraticBezierTo(x + 20, neck - 8, x + 14, neck + 5)
            ..quadraticBezierTo(x + 9, neck + 15, x, neck + 4)
            ..close(),
          green,
        );
        canvas.drawCircle(Offset(x, neck + 4), 3.5, fresh);
        canvas.drawPath(
          Path()
            ..moveTo(x - 9, head - 18)
            ..quadraticBezierTo(x - 23, head - 33, x - 26, head - 22)
            ..quadraticBezierTo(x - 22, head - 14, x - 9, head - 18)
            ..quadraticBezierTo(x - 6, head - 32, x + 1, head - 30)
            ..quadraticBezierTo(x + 6, head - 20, x - 9, head - 18)
            ..close(),
          fresh,
        );
      case PetSkin.astronaut:
        final silver = Paint()..color = const Color(0xfff2faff);
        final blue = Paint()..color = const Color(0xff578aaf);
        final visor = Rect.fromCenter(
          center: Offset(x, head),
          width: 69,
          height: 48,
        );
        canvas.drawOval(
          visor,
          silver
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        canvas.drawArc(
          visor.deflate(4),
          3.6,
          .8,
          false,
          silver..strokeWidth = 1.6,
        );
        final collar = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, neck + 5), height: 9, width: 39),
          const Radius.circular(4),
        );
        canvas.drawRRect(collar, blue);
        canvas.drawCircle(Offset(x, neck + 5), 3, gold);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SkinArt previous) =>
      previous.skin != skin || previous.character != character;
}
