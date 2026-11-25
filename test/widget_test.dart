import 'dart:async';

import 'package:arti_kids/main.dart';
import 'package:arti_kids/models/character.dart';
import 'package:arti_kids/models/pet.dart';
import 'package:arti_kids/models/task.dart';
import 'package:arti_kids/services/observations.dart';
import 'package:arti_kids/services/task_service.dart';
import 'package:arti_kids/widgets/character_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryTasks extends TaskService {
  MemoryTasks() : super(directory: '.');
  final _tasks = <Task>[];
  final _owned = {Character.cat};
  Character _selected = Character.cat;
  String? pin;
  final petActions = <PetAction>[];

  @override
  Future<PetStatus> pet() async => PetStatus(
    balance: await balance(),
    progress: PetProgress(
      petActions.fold<int>(0, (total, action) => total + action.xp),
    ),
  );

  @override
  Future<PetActionResult> performPetAction(
    PetAction action,
    String eventId,
  ) async {
    petActions.add(action);
    return (outcome: PetActionOutcome.completed, pet: await pet());
  }

  @override
  Future<List<Task>> tasks() async => List.of(_tasks);
  @override
  Future<int> balance() async =>
      120 +
      _tasks.where((t) => t.done).fold<int>(0, (sum, t) => sum + t.reward) -
      _owned.fold<int>(0, (sum, character) => sum + character.price);
  @override
  Future<CharacterCollection> characters() async => CharacterCollection(
    balance: await balance(),
    owned: Set.of(_owned),
    selected: _selected,
  );
  @override
  Future<bool> purchaseCharacter(Character character) async {
    if (await balance() < character.price) return false;
    _owned.add(character);
    _selected = character;
    return true;
  }

  @override
  Future<void> selectCharacter(Character character) async {
    _selected = character;
  }

  @override
  Future<String?> setting(String key) async => key == 'pin' ? pin : null;

  @override
  Future<bool> setOrVerifyPin(String value, {required bool create}) async {
    if (create) pin = value;
    return pin == value;
  }

  @override
  Future<void> assign({
    String? existingId,
    required Exercise exercise,
    required String day,
    required int reward,
    required int repeats,
    required int holdMs,
  }) async {
    _tasks.add(
      Task(
        id: 'task',
        title: exercise.title,
        reward: reward,
        date: day,
        repeats: repeats,
        holdMs: holdMs,
        exercise: exercise,
      ),
    );
  }

  @override
  Future<int> complete(
    Task task,
    int repeats, {
    required bool clinicianConfirmed,
  }) async {
    _tasks[0] = Task(
      id: task.id,
      title: task.title,
      reward: task.reward,
      date: task.date,
      completedAt: DateTime.now().toIso8601String(),
      method: 'camera',
      confirmedRepeats: repeats,
    );
    return task.reward;
  }
}

class TestCamera implements ObservationSource {
  final events = StreamController<Observation>.broadcast(sync: true);
  var starts = 0;
  var stops = 0;
  @override
  Stream<Observation> get observations => events.stream;
  @override
  Future<void> openSettings() async {}
  @override
  Future<bool> permission(String kind) async => true;
  @override
  Future<bool> playSample() async => true;
  @override
  Future<void> start({required bool microphone}) async => starts++;
  @override
  Future<void> stop() async => stops++;
}

void main() {
  testWidgets('a game grants experience after all five stars', (tester) async {
    final service = MemoryTasks();
    final camera = TestCamera();
    await tester.pumpWidget(MyApp(service: service, source: camera));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Игры'));
    await tester.tap(find.text('Игры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Играть'));
    await tester.pumpAndSettle();
    final star = find.byTooltip('Поймать звезду');
    for (var index = 0; index < 4; index++) {
      await tester.ensureVisible(star);
      await tester.tap(star);
      await tester.pumpAndSettle();
      expect(service.petActions, isEmpty);
    }
    await tester.ensureVisible(star);
    await tester.tap(star);
    await tester.pumpAndSettle();
    expect(service.petActions, [PetAction.play]);
    expect(find.text('12 из 50 опыта'), findsOneWidget);
    expect(find.text('Сыграть ещё'), findsOneWidget);
    await camera.events.close();
  });
  testWidgets(
    'buy a character, use it in a lesson and celebrate the saved reward',
    (tester) async {
      final service = MemoryTasks();
      final camera = TestCamera();
      await tester.pumpWidget(MyApp(service: service, source: camera));
      await tester.pumpAndSettle();
      expect(find.text('120 рыбок'), findsOneWidget);
      await tester.tap(find.text('Магазин'));
      await tester.pumpAndSettle();
      final fox = find.ancestor(
        of: find.text('Лисёнок'),
        matching: find.byType(Card),
      );
      await tester.tap(find.descendant(of: fox, matching: find.text('Купить')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Купить'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: fox, matching: find.text('Выбран')),
        findsOneWidget,
      );
      expect(find.text('60 рыбок'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Лисёнок'), findsOneWidget);
      await tester.tap(find.byTooltip('Кабинет врача'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4831');
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Назначить упражнение'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Назначить'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Начать'));
      await tester.tap(find.text('Начать'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Включить камеру'));
      await tester.tap(find.text('Включить камеру'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Пауза'));
      await tester.tap(find.text('Пауза'));
      await tester.pumpAndSettle();
      expect(camera.stops, 1);
      await tester.ensureVisible(find.text('Включить камеру'));
      await tester.tap(find.text('Включить камеру'));
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      for (var t = 0; t <= 700; t += 50) {
        camera.events.add(FaceObservation(t));
      }
      for (var t = 750; t <= 1800; t += 50) {
        camera.events.add(FaceObservation(t, open: .6));
      }
      await tester.pump();
      await tester.pump();
      final translation = find
          .descendant(
            of: find.byType(CharacterAvatar),
            matching: find.byType(Transform),
          )
          .first;
      final resting = tester.widget<Transform>(translation).transform.clone();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<Transform>(translation).transform, isNot(resting));
      await tester.pumpAndSettle();
      expect(find.text('Задание выполнено!'), findsOneWidget);
      expect(find.text('+10 рыбок'), findsOneWidget);
      final avatar = tester.widget<CharacterAvatar>(
        find.byType(CharacterAvatar),
      );
      expect(avatar.character, Character.fox);
      expect(avatar.happy, isTrue);
      expect(avatar.dance, isIn(AvatarDance.values));
      await tester.ensureVisible(find.text('Домой'));
      await tester.tap(find.text('Домой'));
      await tester.pumpAndSettle();
      expect(find.text('70 рыбок'), findsOneWidget);
      await tester.ensureVisible(find.text('История'));
      await tester.tap(find.text('История'));
      await tester.pumpAndSettle();
      expect(find.text('Камера подтвердила движение'), findsOneWidget);
      await camera.events.close();
    },
  );
}
