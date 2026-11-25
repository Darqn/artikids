import 'package:flutter/services.dart';

sealed class Observation {
  const Observation(this.timeMs);
  final int timeMs;

  factory Observation.fromMessage(Map<Object?, Object?> data) {
    final time = data['time'] as int;
    if (data['voice'] case final bool voiced) {
      return VoiceObservation(time, voiced);
    }
    return FaceObservation(
      time,
      faces: data['faces'] as int,
      open: (data['open'] as num?)?.toDouble() ?? 0,
      smile: (data['smile'] as num?)?.toDouble() ?? 0,
      round: (data['round'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FaceObservation extends Observation {
  const FaceObservation(
    super.timeMs, {
    this.faces = 1,
    this.open = 0,
    this.smile = 0,
    this.round = 0,
  });
  final int faces;
  final double open;
  final double smile;
  final double round;
}

class VoiceObservation extends Observation {
  const VoiceObservation(super.timeMs, this.voiced);
  final bool voiced;
}

abstract interface class ObservationSource {
  Stream<Observation> get observations;
  Future<bool> permission(String kind);
  Future<void> start({required bool microphone});
  Future<void> stop();
  Future<bool> playSample();
  Future<void> openSettings();
}

class PhoneObservationSource implements ObservationSource {
  static const _method = MethodChannel('artikids/capture');
  static const _events = EventChannel('artikids/observations');

  @override
  late final Stream<Observation> observations = _events
      .receiveBroadcastStream()
      .map(
        (event) =>
            Observation.fromMessage(Map<Object?, Object?>.from(event as Map)),
      );

  @override
  Future<bool> permission(String kind) async =>
      await _method.invokeMethod<bool>('permission', kind) ?? false;

  @override
  Future<void> start({required bool microphone}) =>
      _method.invokeMethod<void>('start', microphone);

  @override
  Future<void> stop() => _method.invokeMethod<void>('stop');

  @override
  Future<bool> playSample() async =>
      await _method.invokeMethod<bool>('sample') ?? false;

  @override
  Future<void> openSettings() => _method.invokeMethod<void>('settings');
}
