import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../models/character.dart';
import '../models/pet.dart';
import '../models/task.dart';
import 'task_storage_native.dart'
    if (dart.library.js_interop) 'task_storage_web.dart';

class TaskService {
  TaskService({
    DatabaseFactory? factory,
    String? directory,
    DateTime Function()? now,
  }) : _factory = factory ?? taskDatabaseFactory,
       _directory = directory,
       _now = now ?? DateTime.now;

  final DatabaseFactory _factory;
  final String? _directory;
  final DateTime Function() _now;
  Future<Database>? _opening;

  Future<Database> get _db => _opening ??= _open();

  Future<Database> _open() async {
    try {
      final directory = _directory ?? await taskDirectory();
      return await _factory.openDatabase(
        '$directory/artikids.sqlite',
        options: OpenDatabaseOptions(
          version: 3,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
            await db.rawQuery('PRAGMA secure_delete = ON');
          },
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE assignments (
                id TEXT PRIMARY KEY, profile_id INTEGER NOT NULL DEFAULT 1,
                title TEXT NOT NULL, day TEXT NOT NULL, reward INTEGER NOT NULL,
                exercise TEXT, exercise_version INTEGER NOT NULL DEFAULT 1,
                repeats INTEGER NOT NULL DEFAULT 1, hold_ms INTEGER NOT NULL DEFAULT 1000,
                completed_at TEXT, legacy_done INTEGER NOT NULL DEFAULT 0
              )
            ''');
            await db.execute('''
              CREATE TABLE results (
                assignment_id TEXT PRIMARY KEY REFERENCES assignments(id) ON DELETE CASCADE,
                confirmed_repeats INTEGER NOT NULL, method TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE fish (
                assignment_id TEXT PRIMARY KEY REFERENCES assignments(id) ON DELETE CASCADE,
                amount INTEGER NOT NULL
              )
            ''');
            await db.execute(
              'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
            );
            await _createPurchases(db);
            await _createPetTables(db);
            final legacy = await readLegacyTasks(directory);
            final raw =
                legacy ?? await rootBundle.loadString('assets/tasks.json');
            final tasks = jsonDecode(raw) as List<dynamic>;
            var index = 0;
            for (final item in tasks) {
              final task = item as Map<String, dynamic>;
              final id = task['id']?.toString() ?? 'import-$index';
              final isDone = task['done'] == true;
              await db.insert('assignments', {
                'id': id,
                'title': task['title'] as String,
                'day': task['date'] as String,
                'reward': task['reward'] as int,
                'exercise': legacy != null
                    ? null
                    : Exercise.fromId(task['exercise'])?.id,
                'completed_at': isDone ? task['completedAt'] as String? : null,
                'legacy_done': isDone ? 1 : 0,
              });
              index++;
            }
            await db.insert('settings', {
              'key': 'startingFish',
              'value': '120',
            });
          },
          onUpgrade: (db, oldVersion, _) async {
            if (oldVersion < 2) await _createPurchases(db);
            if (oldVersion < 3) await _createPetTables(db);
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> _createPurchases(Database db) => db.execute('''
    CREATE TABLE character_purchases (
      character_id TEXT PRIMARY KEY, cost INTEGER NOT NULL CHECK(cost > 0)
    )
  ''');

  Future<void> _createPetTables(Database db) async {
    await db.execute('''
      CREATE TABLE pet_events (
        id TEXT PRIMARY KEY, cost INTEGER NOT NULL CHECK(cost >= 0),
        xp INTEGER NOT NULL CHECK(xp > 0), need TEXT NOT NULL,
        value INTEGER NOT NULL CHECK(value BETWEEN 0 AND 100), time_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE skin_purchases (
        skin_id TEXT PRIMARY KEY, cost INTEGER NOT NULL CHECK(cost > 0)
      )
    ''');
  }

  Future<List<Task>> tasks() async {
    final rows = await (await _db).rawQuery('''
      SELECT assignments.*, results.confirmed_repeats, results.method
      FROM assignments LEFT JOIN results ON results.assignment_id = assignments.id
      ORDER BY assignments.completed_at DESC, assignments.day, assignments.rowid
    ''');
    return rows.map(Task.fromRow).toList();
  }

  Future<void> assign({
    String? existingId,
    required Exercise exercise,
    required String day,
    required int reward,
    required int repeats,
    required int holdMs,
  }) async {
    if (reward < 0 ||
        reward > 999 ||
        repeats < 1 ||
        repeats > 10 ||
        holdMs < 500 ||
        holdMs > 5000) {
      throw ArgumentError('Недопустимые параметры задания');
    }
    final db = await _db;
    final values = {
      'exercise': exercise.id,
      'day': day,
      'reward': reward,
      'repeats': repeats,
      'hold_ms': holdMs,
    };
    if (existingId == null) {
      await db.insert('assignments', {
        ...values,
        'id': _randomToken(),
        'title': exercise.title,
      });
      return;
    }
    final changed = await db.update(
      'assignments',
      values,
      where:
          'id = ? AND exercise IS NULL AND completed_at IS NULL AND legacy_done = 0',
      whereArgs: [existingId],
    );
    if (changed != 1) throw StateError('Назначение уже изменилось');
  }

  Future<int> complete(
    Task task,
    int repeats, {
    required bool clinicianConfirmed,
  }) async {
    final exercise = task.exercise;
    if (exercise == null ||
        repeats != task.repeats ||
        clinicianConfirmed != exercise.needsVoice) {
      throw StateError('Условия завершения не выполнены');
    }
    return (await _db).transaction((tx) async {
      final previous = await tx.query(
        'fish',
        where: 'assignment_id = ?',
        whereArgs: [task.id],
      );
      if (previous.isNotEmpty) return previous.single['amount'] as int;
      final changed = await tx.update(
        'assignments',
        {'completed_at': DateTime.now().toUtc().toIso8601String()},
        where:
            'id = ? AND exercise = ? AND repeats = ? AND day <= ? AND completed_at IS NULL AND legacy_done = 0',
        whereArgs: [task.id, exercise.id, repeats, localDate(DateTime.now())],
      );
      if (changed != 1) throw StateError('Назначение недоступно');
      final saved = await tx.query(
        'assignments',
        columns: ['reward'],
        where: 'id = ?',
        whereArgs: [task.id],
      );
      final reward = saved.single['reward'] as int;
      await tx.insert('results', {
        'assignment_id': task.id,
        'confirmed_repeats': repeats,
        'method': clinicianConfirmed ? 'clinician' : 'camera',
      });
      await tx.insert('fish', {'assignment_id': task.id, 'amount': reward});
      return reward;
    });
  }

  Future<int> balance() async => _balance(await _db);

  Future<int> _balance(DatabaseExecutor db) async {
    final rows = await db.rawQuery('''
      SELECT COALESCE((SELECT CAST(value AS INTEGER) FROM settings WHERE key = 'startingFish'), 0)
        + COALESCE((SELECT SUM(amount) FROM fish), 0)
        - COALESCE((SELECT SUM(cost) FROM character_purchases), 0)
        - COALESCE((SELECT SUM(cost) FROM skin_purchases), 0)
        - COALESCE((SELECT SUM(cost) FROM pet_events), 0) AS total
    ''');
    return rows.single['total'] as int;
  }

  Future<CharacterCollection> characters() async =>
      (await _db).transaction((tx) async {
        final rows = await tx.query(
          'character_purchases',
          columns: ['character_id'],
        );
        final ids = rows.map((row) => row['character_id']).toSet();
        final owned = {
          Character.cat,
          ...Character.values.where((character) => ids.contains(character.id)),
        };
        final selectedId = await _setting(tx, 'character');
        final selected = owned.firstWhere(
          (character) => character.id == selectedId,
          orElse: () => Character.cat,
        );
        return CharacterCollection(
          balance: await _balance(tx),
          owned: Set.unmodifiable(owned),
          selected: selected,
        );
      });

  Future<bool> purchaseCharacter(Character character) async =>
      (await _db).transaction((tx) async {
        if (await _ownsCharacter(tx, character)) return true;
        if (await _balance(tx) < character.price) return false;
        await tx.insert('character_purchases', {
          'character_id': character.id,
          'cost': character.price,
        });
        await _setSetting(tx, 'character', character.id);
        return true;
      });

  Future<void> selectCharacter(Character character) async =>
      (await _db).transaction((tx) async {
        if (!await _ownsCharacter(tx, character)) {
          throw StateError('Сначала купите персонажа');
        }
        await _setSetting(tx, 'character', character.id);
      });

  Future<bool> _ownsCharacter(DatabaseExecutor db, Character character) async {
    if (character == Character.cat) return true;
    final rows = await db.query(
      'character_purchases',
      where: 'character_id = ?',
      whereArgs: [character.id],
    );
    return rows.isNotEmpty;
  }

  Future<PetStatus> pet() async =>
      (await _db).transaction((tx) => _pet(tx, _now()));

  Future<PetStatus> _pet(DatabaseExecutor db, DateTime now) async {
    final latest = await db.rawQuery('''
      SELECT need, value, time_ms FROM pet_events
      WHERE rowid IN (SELECT MAX(rowid) FROM pet_events GROUP BY need)
    ''');
    final rowsByNeed = {for (final row in latest) row['need']: row};
    final values = <PetNeed, int>{};
    for (final need in PetNeed.values) {
      final row = rowsByNeed[need.id];
      if (row == null) continue;
      final elapsed = now.millisecondsSinceEpoch - (row['time_ms'] as int);
      values[need] = need.afterHours(
        row['value'] as int,
        max(0, elapsed ~/ 3600000),
      );
    }
    final skins = await db.query('skin_purchases', columns: ['skin_id']);
    final ids = skins.map((row) => row['skin_id']).toSet();
    final owned = {
      PetSkin.classic,
      ...PetSkin.values.where((skin) => ids.contains(skin.id)),
    };
    final selectedId = await _setting(db, 'skin');
    final scores = await db.rawQuery(
      '''
      SELECT COALESCE((SELECT SUM(xp) FROM pet_events), 0)
        + (SELECT COUNT(*) FROM results) * ? AS total
    ''',
      [PetProgress.xpPerLesson],
    );
    return PetStatus(
      balance: await _balance(db),
      skin: owned.firstWhere(
        (skin) => skin.id == selectedId,
        orElse: () => PetSkin.classic,
      ),
      ownedSkins: Set.unmodifiable(owned),
      progress: PetProgress(scores.single['total'] as int),
      needs: Map.unmodifiable(values),
    );
  }

  static String newPetEventId() => _randomToken();

  Future<PetActionResult> performPetAction(
    PetAction action,
    String eventId,
  ) async => (await _db).transaction((tx) async {
    final now = _now();
    final pet = await _pet(tx, now);
    final existing = await tx.query(
      'pet_events',
      where: 'id = ?',
      whereArgs: [eventId],
    );
    if (existing.isNotEmpty) {
      return (outcome: PetActionOutcome.completed, pet: pet);
    }
    if (pet[action.need] == 100 && action != PetAction.play) {
      return (outcome: PetActionOutcome.full, pet: pet);
    }
    if (pet.balance < action.cost) {
      return (outcome: PetActionOutcome.insufficientFish, pet: pet);
    }
    await tx.insert('pet_events', {
      'id': eventId,
      'cost': action.cost,
      'xp': action.xp,
      'need': action.need.id,
      'value': min(100, pet[action.need] + action.boost),
      'time_ms': now.millisecondsSinceEpoch,
    });
    return (outcome: PetActionOutcome.completed, pet: await _pet(tx, now));
  });

  /// Buys a skin if needed and puts it on in the same transaction.
  Future<PetStatus?> wearSkin(PetSkin skin) async =>
      (await _db).transaction((tx) async {
        final now = _now();
        final pet = await _pet(tx, now);
        if (!pet.ownedSkins.contains(skin)) {
          if (pet.balance < skin.cost) return null;
          await tx.insert('skin_purchases', {
            'skin_id': skin.id,
            'cost': skin.cost,
          });
        }
        await _setSetting(tx, 'skin', skin.id);
        return _pet(tx, now);
      });

  Future<String?> setting(String key) async {
    return _setting(await _db, key);
  }

  Future<String?> _setting(DatabaseExecutor db, String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    await _setSetting(await _db, key, value);
  }

  Future<void> _setSetting(
    DatabaseExecutor db,
    String key,
    String value,
  ) async {
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> setOrVerifyPin(String pin, {required bool create}) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) return false;
    return (await _db).transaction((tx) async {
      final rows = await tx.query('settings', where: "key = 'pin'");
      if (rows.isEmpty) {
        if (!create) return false;
        final salt = _randomToken();
        await tx.insert('settings', {
          'key': 'pin',
          'value': '$salt:${_pinHash(salt, pin)}',
        });
        return true;
      }
      if (create) return false;
      final saved = (rows.single['value'] as String).split(':');
      return _pinHash(saved.first, pin) == saved.last;
    });
  }

  Future<void> clearProfile() async {
    // Remove the already imported copy so the old profile cannot reappear.
    await removeLegacyTasks(_directory ?? await taskDirectory());
    await (await _db).transaction((tx) async {
      await tx.delete('assignments');
      await tx.delete('character_purchases');
      await tx.delete('pet_events');
      await tx.delete('skin_purchases');
      await tx.delete(
        'settings',
        where:
            "key IN ('profile', 'accessory', 'startingFish', 'character', 'skin')",
      );
    });
  }

  Future<void> close() async {
    final db = _opening;
    _opening = null;
    if (db != null) await (await db).close();
  }

  static String _randomToken() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(18, (_) => random.nextInt(256)));
  }

  static String _pinHash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
