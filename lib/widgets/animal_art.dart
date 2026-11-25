import 'dart:math';

import 'package:flutter/material.dart';

import '../models/character.dart';

class AnimalArt extends CustomPainter {
  const AnimalArt({
    required this.character,
    required this.open,
    required this.smile,
    required this.round,
    required this.happy,
    required this.accessory,
  });

  final Character character;
  final double open, smile, round;
  final bool happy, accessory;

  static const _ink = Color(0xff392334);
  static const _pink = Color(0xffef8fa5);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final (light, dark, belly, paws) = switch (character) {
      Character.fox => (
        const Color(0xffffbb66),
        const Color(0xffdf6a3c),
        const Color(0xffffe2af),
        const Color(0xffa84e46),
      ),
      Character.rabbit => (
        const Color(0xffddd1f9),
        const Color(0xffa391cf),
        const Color(0xfff3e8ff),
        const Color(0xffc4b0e8),
      ),
      Character.panda || Character.cat => (
        const Color(0xfffff5df),
        const Color(0xffd8ccd7),
        const Color(0xfffff6df),
        const Color(0xff5c516e),
      ),
    };

    switch (character) {
      case Character.fox:
        final tail = Path()
          ..moveTo(67, 79)
          ..cubicTo(83, 81, 94, 65, 92, 50)
          ..cubicTo(104, 63, 100, 82, 90, 90)
          ..cubicTo(80, 98, 70, 93, 66, 87)
          ..close();
        canvas.drawPath(tail, _shade(tail.getBounds(), light, dark));
        canvas.save();
        canvas.clipPath(tail);
        canvas.drawPath(
          Path()
            ..moveTo(86, 48)
            ..lineTo(105, 48)
            ..lineTo(101, 71)
            ..quadraticBezierTo(96, 67, 93, 71)
            ..lineTo(88, 67)
            ..close(),
          Paint()..color = belly,
        );
        canvas.restore();
        for (final direction in [-1.0, 1.0]) {
          final ear = Path()
            ..moveTo(50 + 13 * direction, 36)
            ..quadraticBezierTo(
              50 + 32 * direction,
              12,
              50 + 35 * direction,
              15,
            )
            ..quadraticBezierTo(
              50 + 39 * direction,
              23,
              50 + 29 * direction,
              43,
            )
            ..close();
          canvas.drawPath(ear, _shade(ear.getBounds(), light, dark));
          canvas.drawPath(
            Path()
              ..moveTo(50 + 20 * direction, 35)
              ..quadraticBezierTo(
                50 + 31 * direction,
                20,
                50 + 32 * direction,
                21,
              )
              ..quadraticBezierTo(
                50 + 34 * direction,
                30,
                50 + 26 * direction,
                38,
              )
              ..close(),
            Paint()..color = const Color(0xfff8a2a8),
          );
        }
      case Character.rabbit:
        _oval(canvas, 73, 83, 20, 20, belly, light);
        _ear(canvas, 37, 24, -.26, light, dark);
        _ear(canvas, 62, 23, .23, light, dark);
      case Character.panda || Character.cat:
        for (final x in [26.0, 74.0]) {
          _oval(canvas, x, 30, 24, 23, paws, _ink);
          _oval(canvas, x, 30, 12, 11, const Color(0xffa395a7), paws);
        }
    }
    _oval(canvas, 50, 76, 50, 41, light, dark);
    _oval(canvas, 50, 79, 36, 30, belly, light);
    for (final direction in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(50 + 26 * direction, 73);
      canvas.rotate(-.37 * direction);
      _oval(canvas, 0, 0, 15, 23, paws, dark);
      canvas.restore();
      _oval(canvas, 50 + 19 * direction, 91, 25, 13, paws, dark);
    }

    final head = Path()
      ..moveTo(50, 27)
      ..cubicTo(28, 27, 22, 36, 18, 46)
      ..cubicTo(12, 58, 25, 69, 50, 69)
      ..cubicTo(75, 69, 88, 58, 82, 46)
      ..cubicTo(78, 36, 72, 27, 50, 27)
      ..close();
    canvas.drawPath(head, _shade(head.getBounds(), light, dark));
    if (character == Character.fox) {
      canvas.save();
      canvas.clipPath(head);
      final cheeks = Path()
        ..moveTo(14, 51)
        ..cubicTo(29, 46, 36, 53, 50, 59)
        ..cubicTo(64, 53, 71, 46, 86, 51)
        ..lineTo(85, 72)
        ..lineTo(15, 72)
        ..close();
      canvas.drawPath(
        cheeks,
        _shade(cheeks.getBounds(), belly, const Color(0xffffc994)),
      );
      canvas.restore();
    }
    for (final direction in [-1.0, 1.0]) {
      final x = 50 + 15 * direction;
      if (character == Character.panda) {
        canvas.save();
        canvas.translate(x, 49);
        canvas.rotate(-.34 * direction);
        _oval(canvas, 0, 0, 17, 22, paws, _ink);
        canvas.restore();
      }
      _oval(canvas, x + 7 * direction, 56, 10, 5, _pink.withValues(alpha: .72));
      if (happy) {
        canvas.drawPath(
          Path()
            ..moveTo(x - 5.5, 49)
            ..quadraticBezierTo(x, 40, x + 5.5, 49),
          Paint()
            ..color = character == Character.panda ? belly : _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.3
            ..strokeCap = StrokeCap.round,
        );
      } else {
        _oval(canvas, x, 48, 13.5, 8, _ink);
        _oval(canvas, x - 2.7, 49, 4.7, 3.3, Colors.white);
      }
    }
    _oval(canvas, 50, 53.5, character == Character.rabbit ? 5 : 6, 4.5, _ink);
    _mouth(canvas);
    if (accessory) _star(canvas);
    canvas.restore();
  }

  void _ear(
    Canvas canvas,
    double x,
    double y,
    double tilt,
    Color light,
    Color dark,
  ) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(tilt);
    _oval(canvas, 0, 0, 16, 39, light, dark);
    _oval(canvas, 0, -1, 8.5, 28, const Color(0xfff7b3d4), _pink);
    canvas.restore();
  }

  void _mouth(Canvas canvas) {
    final jaw = happy ? .8 : (open * 2.65).clamp(0.0, 1.0);
    final grin = happy ? .9 : (smile * 2.55).clamp(0.0, 1.0);
    final pucker = happy ? 0.0 : (round * 2.25).clamp(0.0, 1.0);
    final width = 10 + grin * 9 - pucker * 6;
    final top = 56 - grin * 2 + pucker * 1.4;
    final bottom = top + 3.5 + jaw * 9 + pucker * 3.5;
    final left = 50 - width / 2;
    final right = 50 + width / 2;
    final outline = Path()
      ..moveTo(left, top)
      ..quadraticBezierTo(50, top + (1 + grin * 3) * (1 - pucker), right, top)
      ..cubicTo(right, bottom, left, bottom, left, top)
      ..close();
    canvas.drawPath(outline, Paint()..color = _ink);
    if (jaw > .25) {
      canvas.save();
      canvas.clipPath(outline);
      _oval(canvas, 50, bottom - 1.6, width * .67, 4.7, _pink);
      canvas.restore();
    }
  }

  void _star(Canvas canvas) {
    final star = Path();
    for (var point = 0; point < 10; point++) {
      final angle = pi * point / 5 - pi / 2;
      final radius = point.isEven ? 5.8 : 2.8;
      final x = 73 + cos(angle) * radius;
      final y = 34 + sin(angle) * radius;
      if (point == 0) {
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
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(star, Paint()..color = const Color(0xffede4ff));
  }

  void _oval(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    Color light, [
    Color? dark,
  ]) {
    final rect = Rect.fromCenter(
      center: Offset(x, y),
      width: width,
      height: height,
    );
    canvas.drawOval(
      rect,
      dark == null ? (Paint()..color = light) : _shade(rect, light, dark),
    );
  }

  Paint _shade(Rect bounds, Color light, Color dark) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [light, dark],
    ).createShader(bounds);

  @override
  bool shouldRepaint(AnimalArt old) =>
      character != old.character ||
      open != old.open ||
      smile != old.smile ||
      round != old.round ||
      happy != old.happy ||
      accessory != old.accessory;
}
