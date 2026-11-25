import 'package:arti_kids/models/task.dart';
import 'package:arti_kids/services/exercise_session.dart';
import 'package:arti_kids/services/observations.dart';
import 'package:flutter_test/flutter_test.dart';

ExerciseSession makeSession(Exercise exercise, {int repeats = 1}) {
  final session = ExerciseSession(
    Task(
      id: 't',
      title: exercise.title,
      reward: 10,
      date: '2026-01-01',
      exercise: exercise,
      holdMs: 500,
      repeats: repeats,
    ),
  );
  for (var time = 0; time <= 700; time += 50) {
    session.accept(FaceObservation(time));
  }
  expect(session.step, SessionStep.action);
  return session;
}

void frames(
  ExerciseSession session,
  int start,
  int end, {
  double jaw = 0,
  double smile = 0,
  bool? voice,
  int faces = 1,
}) {
  for (var time = start; time <= end; time += 50) {
    if (voice != null) session.accept(VoiceObservation(time, voice));
    session.accept(
      FaceObservation(time, open: jaw, smile: smile, faces: faces),
    );
  }
}

void main() {
  test('avatar follows a smile while the open-mouth count waits', () {
    final session = makeSession(Exercise.open, repeats: 2);
    frames(session, 750, 1300, smile: .6);
    expect(session.smile, greaterThan(.4));
    expect(session.repeats, 0);
    frames(session, 1350, 2350, jaw: .6);
    expect(session.repeats, 1);
    expect(session.step, SessionStep.neutral);
    frames(session, 2400, 2400);
    frames(session, 2450, 2950, jaw: .6);
    expect(session.repeats, 2);
    expect(session.step, SessionStep.complete);
  });

  test('a second face, missing frames and recalibration break a hold', () {
    final session = makeSession(Exercise.open);
    frames(session, 750, 1100, jaw: .6);
    frames(session, 1150, 1150, faces: 2);
    expect(session.progress, 0);
    frames(session, 1200, 1450, jaw: .6);
    frames(session, 1800, 2000, jaw: .6);
    expect(session.repeats, 0);
    session.recalibrate();
    frames(session, 2050, 2900, jaw: .6);
    expect(session.step, SessionStep.calibrating);
    expect(session.progress, 0);
  });

  test(
    'voice before the pose and silence in the pose never ask for credit',
    () {
      final session = makeSession(Exercise.vowel);
      frames(session, 750, 1150, voice: true);
      frames(session, 1200, 2000, jaw: .6, voice: false);
      expect(session.repeats, 0);
      expect(session.step, SessionStep.action);
    },
  );

  test('overlapping voice opens review, a rejected vowel gives no credit', () {
    final session = makeSession(Exercise.vowel);
    frames(session, 750, 1400, jaw: .6, voice: true);
    expect(session.step, SessionStep.review);
    expect(session.repeats, 0);
    session.review(confirmed: false);
    frames(session, 1450, 2050, jaw: .6, voice: true);
    expect(session.step, SessionStep.neutral);
    expect(session.repeats, 0);
    frames(session, 2100, 2100, voice: false);
    frames(session, 2150, 2800, jaw: .6, voice: true);
    session.review(confirmed: true);
    expect(session.step, SessionStep.complete);
    expect(session.repeats, 1);
  });

  test('smile task accepts a smile and rejects an open mouth', () {
    final session = makeSession(Exercise.smile);
    frames(session, 750, 1300, jaw: .6);
    expect(session.repeats, 0);
    frames(session, 1350, 1900, smile: .6);
    expect(session.repeats, 1);
  });
}
