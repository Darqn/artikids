import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character.dart';
import '../models/pet.dart';
import '../models/task.dart';
import '../services/exercise_session.dart';
import '../services/observations.dart';
import '../services/task_service.dart';
import '../widgets/character_avatar.dart';
import 'settings_page.dart';

class ExercisePage extends StatefulWidget {
  const ExercisePage({
    super.key,
    required this.task,
    required this.service,
    required this.source,
    required this.accessory,
    required this.character,
    this.skin = PetSkin.classic,
  });
  final Task task;
  final TaskService service;
  final ObservationSource source;
  final bool accessory;
  final Character character;
  final PetSkin skin;

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage>
    with WidgetsBindingObserver {
  late final _session = ExerciseSession(widget.task);
  late final _exercise = widget.task.exercise!;
  late final StreamSubscription<Observation> _subscription;
  final _clock = Stopwatch()..start();
  late final Timer _watchdog;
  int _lastFace = 0;
  int _epoch = 0;
  bool _active = false;
  bool _busy = false;
  bool _example = false;
  bool _saving = false;
  bool _reviewing = false;
  bool _settings = false;
  String? _message;
  int? _reward;
  AvatarDance? _dance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = widget.source.observations.listen(
      _accept,
      onError: (Object error) {
        if (mounted && _active) {
          unawaited(
            _interrupt(
              error is PlatformException && error.code == 'browser_capture'
                  ? error.message
                  : 'Захват прерван. Запусти камеру снова.',
            ),
          );
        }
      },
    );
    _watchdog = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!_active || _busy) return;
      final idle = _clock.elapsedMilliseconds - _lastFace;
      if (idle > 500 && _session.faces != 0) {
        setState(() => _session.loseFace());
      }
      if (idle > 5000) {
        unawaited(
          _interrupt('Камера не передаёт изображение. Попробуй ещё раз.'),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached ||
            state == AppLifecycleState.hidden) &&
        (_active || _example)) {
      unawaited(_interrupt('Занятие на паузе'));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog.cancel();
    unawaited(_stopCapture());
    unawaited(_subscription.cancel());
    super.dispose();
  }

  bool _current(int epoch) => mounted && epoch == _epoch;

  Future<void> _stopCapture() async {
    _epoch++;
    _active = false;
    try {
      await widget.source.stop();
    } on PlatformException {
      // The native lifecycle also releases capture when the activity stops.
    } on MissingPluginException {
      // This platform has no capture implementation.
    }
  }

  Future<void> _interrupt(String? message) async {
    final stopping = _stopCapture();
    setState(() {
      _busy = false;
      _example = false;
      _message = message;
      _session.recalibrate();
    });
    await stopping;
  }

  Future<void> _start() async {
    if (_busy || _active) return;
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _message = null;
      _settings = false;
      _session.recalibrate();
    });
    try {
      final camera = await widget.source.permission('camera');
      if (!_current(epoch)) return;
      if (!camera) {
        setState(() {
          _message = 'Разреши камеру, чтобы кот мог повторять движения.';
          _settings = true;
        });
        return;
      }
      if (_exercise.needsVoice) {
        final mic = await widget.source.permission('microphone');
        if (!_current(epoch)) return;
        if (!mic) {
          setState(() {
            _message = 'Для упражнения со звуком нужен микрофон.';
            _settings = true;
          });
          return;
        }
      }
      _lastFace = _clock.elapsedMilliseconds;
      _active = true;
      await widget.source
          .start(microphone: _exercise.needsVoice)
          .timeout(const Duration(seconds: kIsWeb ? 60 : 10));
      if (_current(epoch)) {
        _lastFace = _clock.elapsedMilliseconds;
      }
    } on TimeoutException {
      if (_current(epoch)) {
        await _interrupt('Камера долго запускается. Попробуй ещё раз.');
      }
    } on PlatformException catch (error) {
      if (_current(epoch)) {
        await _interrupt(
          error.code == 'browser_capture'
              ? error.message
              : 'Не удалось открыть камеру или микрофон. Попробуй ещё раз.',
        );
      }
    } on MissingPluginException {
      if (_current(epoch)) {
        await _interrupt('Живая мимика доступна на Android.');
      }
    } finally {
      if (_current(epoch)) setState(() => _busy = false);
    }
  }

  Future<void> _showExample() async {
    final stopping = _stopCapture();
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _example = true;
      _message = null;
      _session.recalibrate();
    });
    await stopping;
    if (!_current(epoch)) return;
    var played = true;
    try {
      if (_exercise.needsVoice) played = await widget.source.playSample();
      await Future<void>.delayed(const Duration(milliseconds: 900));
    } on PlatformException {
      played = false;
    } on MissingPluginException {
      played = false;
    } finally {
      if (_current(epoch)) {
        setState(() {
          _example = _busy = false;
          _message = played ? null : 'Не удалось проиграть пример звука.';
        });
      }
    }
  }

  void _accept(Observation event) {
    if (!mounted || !_active) return;
    if (event is FaceObservation) _lastFace = _clock.elapsedMilliseconds;
    setState(() => _session.accept(event));
    if (_session.step == SessionStep.review) {
      _busy = false;
      unawaited(_stopCapture());
    } else if (_session.step == SessionStep.complete) {
      unawaited(_persist());
    }
  }

  Future<void> _review() async {
    if (_reviewing) return;
    setState(() => _reviewing = true);
    try {
      if (!await unlockAdult(context, widget.service) || !mounted) return;
      final heard = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Вы услышали звук «а»?'),
          content: const Text(
            'Подтвердите звук последней попытки, если вы лично её слышали.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Повторить попытку'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Да, услышал «а»'),
            ),
          ],
        ),
      );
      if (!mounted || heard == null) return;
      setState(() {
        _session.review(confirmed: heard);
        _message = heard ? null : 'Давай попробуем ещё раз';
      });
      if (_session.step == SessionStep.complete) await _persist();
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _persist() async {
    if (_saving || _reward != null) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    await _stopCapture();
    if (!mounted) return;
    try {
      final reward = await widget.service.complete(
        widget.task,
        _session.repeats,
        clinicianConfirmed: _exercise.needsVoice,
      );
      if (mounted) {
        setState(() {
          _reward = reward;
          _dance =
              AvatarDance.values[Random().nextInt(AvatarDance.values.length)];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Не удалось сохранить результат. Попробуй ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _hint {
    if (_message case final message?) return message;
    if (_example) return 'Смотри, как делает персонаж';
    if (_reward != null) return 'Задание выполнено!';
    if (_session.step == SessionStep.complete) return 'Сохраняем результат';
    if (_session.step == SessionStep.review) {
      return 'Позови врача, чтобы проверить звук';
    }
    if (!_active) {
      return _exercise.needsVoice
          ? 'Персонаж повторяет движения. Врач проверяет звук.'
          : 'Персонаж будет повторять твои движения';
    }
    if (_session.faces > 1) return 'Оставь в кадре только своё лицо';
    if (_session.faces == 0) return 'Посмотри на персонажа';
    return switch (_session.step) {
      SessionStep.calibrating => 'Расслабь лицо и посмотри прямо',
      SessionStep.neutral => 'Расслабь лицо для следующего повтора',
      _ => _exercise.instruction,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completed = _session.step == SessionStep.complete;
    final review = _session.step == SessionStep.review;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text('Занятие · ${widget.character.name}')),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  _exercise.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xffffe9ce),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: (constraints.maxWidth * .60).clamp(150, 240),
                      child: CharacterAvatar(
                        character: widget.character,
                        skin: widget.skin,
                        open: _example
                            ? (_exercise == Exercise.smile ? 0 : .5)
                            : _session.open,
                        smile: _example
                            ? (_exercise == Exercise.smile ? .5 : 0)
                            : _session.smile,
                        round: _session.round,
                        accessory: widget.accessory,
                        happy: _reward != null,
                        dance: _dance,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (_reward case final reward?)
                  Center(
                    child: Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.set_meal_rounded),
                          label: Text('+${fishAmount(reward)}'),
                        ),
                        const Chip(
                          avatar: Icon(Icons.star_outline),
                          label: Text('+${PetProgress.xpPerLesson} опыта'),
                        ),
                      ],
                    ),
                  ),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _hint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 14),
                if (!completed) ...[
                  Text(
                    'Повторы: ${_session.repeats} из ${widget.task.repeats}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: review ? 1 : _session.progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  if (_exercise.needsVoice && _active)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _session.heardVoice
                            ? 'Микрофон слышит голос'
                            : 'Микрофон слушает',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                if (_reward != null)
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Домой'),
                  )
                else if (completed)
                  FilledButton(
                    onPressed: _saving ? null : _persist,
                    child: const Text('Сохранить результат'),
                  )
                else if (review) ...[
                  FilledButton(
                    onPressed: _reviewing ? null : _review,
                    child: const Text('Проверка врачом'),
                  ),
                  TextButton(
                    onPressed: _reviewing
                        ? null
                        : () => setState(() {
                            _session.review(confirmed: false);
                            _message = null;
                          }),
                    child: const Text('Попробовать ещё раз'),
                  ),
                ] else ...[
                  if (_active && !_busy)
                    FilledButton.tonalIcon(
                      onPressed: () => _interrupt('Занятие на паузе'),
                      icon: const Icon(Icons.pause),
                      label: const Text('Пауза'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _busy ? null : _start,
                      icon: const Icon(Icons.videocam_outlined),
                      label: Text(_busy ? 'Подожди…' : 'Включить камеру'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _showExample,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Посмотреть пример'),
                  ),
                  if (_settings)
                    TextButton(
                      onPressed: () async {
                        try {
                          await widget.source.openSettings();
                        } on PlatformException {
                          if (mounted) {
                            setState(
                              () => _message =
                                  'Открой разрешения в настройках телефона.',
                            );
                          }
                        }
                      },
                      child: const Text('Открыть настройки телефона'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
