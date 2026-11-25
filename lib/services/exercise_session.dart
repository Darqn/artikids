import 'dart:math';

import '../models/task.dart';
import 'observations.dart';

enum SessionStep { calibrating, action, neutral, review, complete }

class ExerciseSession {
  ExerciseSession(this.task);

  final Task task;
  SessionStep step = SessionStep.calibrating;
  int repeats = 0;
  double progress = 0;
  int faces = 0;
  double open = 0;
  double smile = 0;
  double round = 0;
  bool heardVoice = false;

  int? _lastFace;
  int? _voiceAt;
  int? _heldFrom;
  int? _voiceFrom;
  int? _calibrationStart;
  double _neutralOpen = 0;
  double _neutralSmile = 0;
  double _neutralRound = 0;
  int _samples = 0;

  void accept(Observation observation) {
    if (step == SessionStep.review || step == SessionStep.complete) return;
    if (observation is VoiceObservation) {
      if (_voiceAt != null && observation.timeMs <= _voiceAt!) return;
      _voiceAt = observation.timeMs;
      heardVoice = observation.voiced;
      if (!heardVoice) _voiceFrom = null;
      return;
    }
    final face = observation as FaceObservation;
    final last = _lastFace;
    if (last != null && face.timeMs <= last) return;
    if (last != null && face.timeMs - last > 250) loseFace();
    _lastFace = face.timeMs;
    if (face.faces != 1) {
      loseFace(face.faces);
      return;
    }
    faces = 1;
    if (step == SessionStep.calibrating) {
      if (face.open > 0.15 || face.smile > 0.18 || face.round > 0.20) {
        _clearCalibration();
        return;
      }
      _calibrationStart ??= face.timeMs;
      _samples++;
      _neutralOpen += (face.open - _neutralOpen) / _samples;
      _neutralSmile += (face.smile - _neutralSmile) / _samples;
      _neutralRound += (face.round - _neutralRound) / _samples;
      if (face.timeMs - _calibrationStart! >= 650 && _samples >= 5) {
        step = SessionStep.action;
      }
      return;
    }

    final jaw = max(0.0, face.open - _neutralOpen);
    final grin = max(0.0, face.smile - _neutralSmile);
    final pucker = max(0.0, face.round - _neutralRound);
    open = _smooth(open, jaw);
    smile = _smooth(smile, grin);
    round = _smooth(round, pucker);

    if (step == SessionStep.neutral) {
      if (jaw < 0.09 && grin < 0.12 && pucker < 0.12) {
        step = SessionStep.action;
      }
      return;
    }

    final match = task.exercise == Exercise.smile
        ? grin >= 0.20 && jaw < 0.25
        : jaw >= 0.18;
    if (!match) {
      _clearHold();
      return;
    }
    _heldFrom ??= face.timeMs;
    final elapsed = face.timeMs - _heldFrom!;
    if (task.exercise!.needsVoice) {
      final time = _voiceAt;
      if (heardVoice &&
          time != null &&
          time >= _heldFrom! + 40 &&
          (time - face.timeMs).abs() <= 110) {
        _voiceFrom ??= max(_heldFrom!, time - 40);
      } else {
        _voiceFrom = null;
      }
      final voiceElapsed = _voiceFrom == null
          ? 0
          : min(face.timeMs, time!) - _voiceFrom!;
      final voiceRequired = min(task.holdMs, 400);
      progress = min(
        elapsed / task.holdMs,
        voiceElapsed / voiceRequired,
      ).clamp(0, 1);
      if (elapsed >= task.holdMs && voiceElapsed >= voiceRequired) {
        step = SessionStep.review;
      }
    } else {
      progress = min(1, elapsed / task.holdMs);
      if (elapsed >= task.holdMs) _count();
    }
  }

  void review({required bool confirmed}) {
    if (step != SessionStep.review) return;
    if (confirmed) {
      _count();
    } else {
      _clearHold();
      step = SessionStep.neutral;
    }
  }

  void _count() {
    repeats++;
    _clearHold();
    step = repeats < task.repeats ? SessionStep.neutral : SessionStep.complete;
  }

  void loseFace([int count = 0]) {
    faces = count;
    open = smile = round = 0;
    _clearHold();
    if (step == SessionStep.calibrating) _clearCalibration();
  }

  void recalibrate() {
    if (step == SessionStep.complete || step == SessionStep.review) return;
    step = SessionStep.calibrating;
    _clearCalibration();
    _lastFace = _voiceAt = null;
    heardVoice = false;
    loseFace();
  }

  void _clearHold() {
    _heldFrom = _voiceFrom = null;
    progress = 0;
  }

  void _clearCalibration() {
    _calibrationStart = null;
    _samples = 0;
    _neutralOpen = _neutralSmile = _neutralRound = 0;
  }

  double _smooth(double previous, double current) =>
      previous * 0.35 + current * 0.65;
}
