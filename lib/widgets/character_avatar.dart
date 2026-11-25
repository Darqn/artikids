import 'dart:math';

import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/pet.dart';
import 'animal_art.dart';
import 'cat_avatar.dart';
import 'skin_art.dart';

enum AvatarDance { hops, sway, twirl }

class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.character,
    this.open = 0,
    this.smile = 0,
    this.round = 0,
    this.happy = false,
    this.accessory = false,
    this.dance,
    this.skin = PetSkin.classic,
  });

  final Character character;
  final double open, smile, round;
  final bool happy, accessory;
  final AvatarDance? dance;
  final PetSkin skin;

  @override
  Widget build(BuildContext context) {
    final body = character == Character.cat
        ? CatAvatar(
            open: open,
            smile: smile,
            round: round,
            happy: happy,
            accessory: accessory,
          )
        : AspectRatio(
            aspectRatio: 3990 / 4019,
            child: CustomPaint(
              painter: AnimalArt(
                character: character,
                open: open,
                smile: smile,
                round: round,
                happy: happy,
                accessory: accessory,
              ),
            ),
          );
    final avatar = RepaintBoundary(
      child: Stack(
        children: [
          body,
          if (skin != PetSkin.classic)
            Positioned.fill(
              child: CustomPaint(painter: SkinArt(skin, character)),
            ),
        ],
      ),
    );
    final motion = dance;
    if (motion == null || MediaQuery.disableAnimationsOf(context)) {
      return avatar;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2200),
      child: avatar,
      builder: (context, time, child) => LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          final energy = sin(pi * time);
          final beat = 2 * pi * time;
          final (x, y, tilt, width, height) = switch (motion) {
            AvatarDance.hops => (
              sin(beat * 2) * .055 * energy,
              -.19 * sin(beat * 2).abs() * energy,
              .15 * sin(beat * 2),
              1 + .08 * energy * cos(beat * 4),
              1 - .08 * energy * cos(beat * 4),
            ),
            AvatarDance.sway => (
              sin(beat * 2) * .12 * energy,
              -.075 * sin(beat * 2).abs(),
              sin(beat * 2) * .34,
              1.0,
              1.0,
            ),
            AvatarDance.twirl => (
              sin(beat) * .085,
              -.14 * energy,
              sin(beat) * .23,
              cos(beat),
              1 + energy * .075,
            ),
          };
          return Transform.translate(
            offset: Offset(x * size, y * size),
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scaleX: width,
                scaleY: height,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
