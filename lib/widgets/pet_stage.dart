import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/pet.dart';
import 'character_avatar.dart';

class PetStage extends StatelessWidget {
  const PetStage({
    super.key,
    required this.character,
    required this.skin,
    this.accessory = false,
    this.happy = false,
    this.dance,
    this.avatarKey,
  });

  final Character character;
  final PetSkin skin;
  final bool accessory, happy;
  final AvatarDance? dance;
  final Key? avatarKey;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: CustomPaint(
      painter: const _Garden(),
      child: SizedBox(
        height: 170,
        width: double.infinity,
        child: Center(
          child: SizedBox(
            width: 142,
            child: CharacterAvatar(
              key: avatarKey,
              character: character,
              skin: skin,
              accessory: accessory,
              happy: happy,
              dance: dance,
            ),
          ),
        ),
      ),
    ),
  );
}

class PetProgressBar extends StatelessWidget {
  const PetProgressBar({super.key, required this.progress});

  final PetProgress progress;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Уровень ${progress.level}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            '${progress.xpInLevel} из ${PetProgress.xpPerLevel} опыта',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      const SizedBox(height: 7),
      LinearProgressIndicator(
        value: progress.fraction,
        minHeight: 10,
        borderRadius: BorderRadius.circular(8),
        semanticsLabel: 'Опыт до следующего уровня',
      ),
    ],
  );
}

class _Garden extends CustomPainter {
  const _Garden();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffffe3bb), Color(0xfffff4d7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
    );
    final sun = Offset(size.width * .83, size.height * .24);
    canvas.drawCircle(sun, 18, Paint()..color = const Color(0xffffd67c));
    canvas.save();
    canvas.scale(size.width, size.height);
    canvas.drawPath(
      Path()
        ..moveTo(0, .74)
        ..quadraticBezierTo(.24, .53, .5, .75)
        ..quadraticBezierTo(.76, .90, 1, .65)
        ..lineTo(1, 1)
        ..lineTo(0, 1)
        ..close(),
      Paint()..color = const Color(0xffe6edbd),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, .84)
        ..cubicTo(.32, .96, .78, .70, 1, .83)
        ..lineTo(1, 1)
        ..lineTo(0, 1)
        ..close(),
      Paint()..color = const Color(0xffc9e5bd),
    );
    canvas.restore();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - 12),
        width: 116,
        height: 13,
      ),
      Paint()..color = const Color(0xffaace99),
    );
    final flowers = Paint()..color = const Color(0xfffbf6d8);
    for (final (x, y) in [(.13, .87), (.21, .91), (.76, .87), (.87, .90)]) {
      final center = Offset(size.width * x, size.height * y);
      canvas.drawCircle(center + const Offset(-2, 0), 3, flowers);
      canvas.drawCircle(center + const Offset(2, 0), 3, flowers);
      canvas.drawCircle(center, 1.8, Paint()..color = const Color(0xffdc985d));
    }
  }

  @override
  bool shouldRepaint(_Garden oldDelegate) => false;
}
