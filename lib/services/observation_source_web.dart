import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/services.dart';

import 'observations.dart';

@JS('artikidsCapture.available')
external JSBoolean _available();

@JS('artikidsCapture.start')
external JSPromise<JSString?> _start(JSBoolean microphone, JSFunction callback);

@JS('artikidsCapture.stop')
external void _stop();

@JS('artikidsCapture.sample')
external JSPromise<JSBoolean> _sample();

ObservationSource createObservationSource() => _BrowserObservationSource();

class _BrowserObservationSource implements ObservationSource {
  final _events = StreamController<Observation>.broadcast();
  late final _callback = _onMessage.toJS;

  @override
  Stream<Observation> get observations => _events.stream;

  void _onMessage(JSString message) {
    final data = jsonDecode(message.toDart) as Map<String, dynamic>;
    final error = data['error'];
    if (error is String) {
      _events.addError(
        PlatformException(code: 'browser_capture', message: error),
      );
    } else {
      _events.add(Observation.fromMessage(data));
    }
  }

  @override
  Future<bool> permission(String kind) async {
    if (!_available().toDart) {
      throw PlatformException(
        code: 'browser_capture',
        message:
            'Открой приложение через localhost или HTTPS, чтобы включить камеру.',
      );
    }
    return true;
  }

  @override
  Future<void> start({required bool microphone}) async {
    final error = await _start(microphone.toJS, _callback).toDart;
    if (error != null) {
      throw PlatformException(code: 'browser_capture', message: error.toDart);
    }
  }

  @override
  Future<void> stop() async => _stop();

  @override
  Future<bool> playSample() async => (await _sample().toDart).toDart;

  @override
  Future<void> openSettings() async {}
}
