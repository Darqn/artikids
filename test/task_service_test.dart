import 'dart:io';

import 'package:arti_kids/models/character.dart';
import 'package:arti_kids/models/pet.dart';
import 'package:arti_kids/models/task.dart';
import 'package:arti_kids/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory directory;
  late TaskService service;
  late DateTime now;
  TaskService open() => TaskService(
    factory: databaseFactoryFfi,
    directory: directory.path,
    now: () => now,
  );

  setUp(() async {
    now = DateTime(2026, 11, 24, 12);
    directory = await Directory.systemTemp.createTemp('artikids-test-');
    service = open();
  });

  tearDown(() async {
    await service.close();
    await directory.delete(recursive: true);
  });

  test(
    'version 1 data, rewards and accessory survive the shop migration',
    () async {
      final task = (await service.tasks()).first;
      await service.complete(task, task.repeats, clinicianConfirmed: false);
      await service.setSetting('accessory', 'star');
      await service.close();

      final old = await databaseFactoryFfi.openDatabase(
        '${directory.path}/artikids.sqlite',
      );
      await old.execute('DROP TABLE character_purchases');
      await old.execute('DROP TABLE pet_events');
      await old.execute('DROP TABLE skin_purchases');
      await old.execute('PRAGMA user_version = 1');
      await old.close();
      service = open();

      final collection = await service.characters();
      expect(collection.selected, Character.cat);
      expect(collection.owned, {Character.cat});
      expect(collection.balance, 120 + task.reward);
      expect((await service.tasks()).single.method, 'camera');
      expect(await service.setting('accessory'), 'star');
      expect((await service.pet()).progress.totalXp, PetProgress.xpPerLesson);
    },
  );

  test(
    'version 2 character and balance are preserved when the pet rooms open',
    () async {
      await service.purchaseCharacter(Character.fox);
      await service.close();
      final old = await databaseFactoryFfi.openDatabase(
        '${directory.path}/artikids.sqlite',
      );
      await old.execute('DROP TABLE pet_events');
      await old.execute('DROP TABLE skin_purchases');
      await old.execute('PRAGMA user_version = 2');
      await old.close();
      service = open();

      final pet = await service.pet();
      expect(pet.skin, PetSkin.classic);
      expect(pet[PetNeed.food], PetNeed.initial);
      expect(pet.balance, 60);
      expect((await service.characters()).selected, Character.fox);
    },
  );

  test(
    'care retries, skins and level progression share one persistent balance',
    () async {
      await Future.wait([
        service.performPetAction(PetAction.apple, 'apple'),
        service.performPetAction(PetAction.apple, 'apple'),
      ]);
      final fed = await service.pet();
      expect(fed[PetNeed.food], 90);
      expect(fed.balance, 115);
      expect(fed.progress.totalXp, 5);
      await service.performPetAction(PetAction.cookie, 'cookie');
      final full = await service.performPetAction(PetAction.apple, 'full');
      expect(full.outcome, PetActionOutcome.full);
      expect(full.pet.balance, 106);
      await service.performPetAction(PetAction.wash, 'wash');
      await service.performPetAction(PetAction.play, 'round-1');
      await service.performPetAction(PetAction.play, 'round-2');
      await service.performPetAction(PetAction.play, 'round-3');
      await Future.wait([
        service.wearSkin(PetSkin.bee),
        service.wearSkin(PetSkin.bee),
      ]);
      expect(await service.wearSkin(PetSkin.astronaut), isNull);
      await service.close();
      service = open();
      final restored = await service.pet();
      expect(restored.skin, PetSkin.bee);
      expect(restored.ownedSkins, {PetSkin.classic, PetSkin.bee});
      expect(restored.balance, 71);
      expect((await service.characters()).balance, 71);
      expect(restored.progress.level, 2);
      expect(restored.progress.xpInLevel, 4);
      now = now.add(const Duration(hours: 2));
      expect((await service.pet())[PetNeed.food], 94);
      now = now.add(const Duration(days: 90));
      expect((await service.pet())[PetNeed.food], PetNeed.minimum);
      await service.clearProfile();
      final cleared = await service.pet();
      expect(cleared.skin, PetSkin.classic);
      expect(cleared.ownedSkins, {PetSkin.classic});
      expect(cleared.progress.totalXp, 0);
      expect(cleared.balance, 0);
      expect(
        (await service.performPetAction(PetAction.apple, 'empty')).outcome,
        PetActionOutcome.insufficientFish,
      );
    },
  );

  test(
    'purchases are atomic, never double charge, and survive reopen',
    () async {
      final same = await Future.wait([
        service.purchaseCharacter(Character.fox),
        service.purchaseCharacter(Character.fox),
      ]);
      expect(same, [true, true]);
      expect(await service.balance(), 60);
      expect(await service.purchaseCharacter(Character.rabbit), isFalse);
      await expectLater(
        service.selectCharacter(Character.rabbit),
        throwsStateError,
      );
      await service.close();
      service = open();

      final collection = await service.characters();
      expect(collection.selected, Character.fox);
      expect(collection.owned, {Character.cat, Character.fox});
      expect(collection.balance, 60);
      await service.selectCharacter(Character.cat);
      expect((await service.characters()).selected, Character.cat);
      expect(await service.balance(), 60);
      await service.clearProfile();
      expect((await service.characters()).owned, {Character.cat});
      expect(await service.balance(), 0);
    },
  );

  test('concurrent purchases cannot spend the same fish twice', () async {
    final purchases = await Future.wait([
      service.purchaseCharacter(Character.fox),
      service.purchaseCharacter(Character.rabbit),
    ]);
    expect(purchases.where((purchased) => purchased), hasLength(1));
    final collection = await service.characters();
    expect(collection.owned, hasLength(2));
    expect(collection.balance, 120 - collection.selected.price);
  });

  test(
    'imports legacy tasks and saves one reward across concurrent requests and reopen',
    () async {
      final legacy = File('${directory.path}/tasks.json');
      await legacy.writeAsString('''
      [
        {"title":"Legacy","date":"2026-01-01","reward":13,"done":false},
        {"id":"old","title":"Old result","date":"2026-01-01","reward":15,"done":true}
      ]
    ''');
      final imported = await service.tasks();
      expect(imported.singleWhere((task) => task.id == 'old').done, isTrue);
      final active = imported.singleWhere((task) => !task.done);
      expect(active.exercise, isNull);
      await service.assign(
        existingId: active.id,
        exercise: Exercise.open,
        day: active.date,
        reward: active.reward,
        repeats: 1,
        holdMs: 500,
      );
      final task = (await service.tasks()).singleWhere((task) => !task.done);
      await Future.wait(
        List.generate(
          2,
          (_) => service.complete(task, 1, clinicianConfirmed: false),
        ),
      );
      await service.close();
      service = open();
      expect(await service.balance(), 133);
      expect(
        (await service.tasks()).singleWhere((t) => t.id == active.id).method,
        'camera',
      );
      expect(await legacy.exists(), isTrue);
    },
  );

  test('invalid migration preserves the source and can be retried', () async {
    final legacy = File('${directory.path}/tasks.json');
    await legacy.writeAsString('[invalid');
    await expectLater(service.tasks(), throwsFormatException);
    expect(await legacy.readAsString(), '[invalid');
    await legacy.writeAsString('[]');
    expect(await service.tasks(), isEmpty);
    expect(await service.balance(), 120);
  });

  test(
    'future and unconfirmed voice tasks cannot change the balance',
    () async {
      final today = localDate(DateTime.now());
      await service.assign(
        exercise: Exercise.vowel,
        day: today,
        reward: 10,
        repeats: 1,
        holdMs: 500,
      );
      await service.assign(
        exercise: Exercise.open,
        day: '2999-01-01',
        reward: 20,
        repeats: 1,
        holdMs: 500,
      );
      final tasks = await service.tasks();
      final voice = tasks.singleWhere(
        (task) => task.exercise == Exercise.vowel,
      );
      final future = tasks.singleWhere((task) => task.date == '2999-01-01');
      expect(future.availableOn(DateTime.now()), isFalse);
      await expectLater(
        service.complete(future, 1, clinicianConfirmed: false),
        throwsStateError,
      );
      await expectLater(
        service.complete(voice, 1, clinicianConfirmed: false),
        throwsStateError,
      );
      expect(await service.balance(), 120);
      await service.complete(voice, 1, clinicianConfirmed: true);
      expect(await service.balance(), 130);
      await service.clearProfile();
      expect(await service.tasks(), isEmpty);
      expect(await service.balance(), 0);
    },
  );
}
