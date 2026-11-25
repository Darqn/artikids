import 'dart:math';

import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/pet.dart';
import '../services/task_service.dart';
import '../widgets/character_avatar.dart';
import '../widgets/pet_stage.dart';

enum PetRoom {
  care('Уход', Icons.favorite_outline, Color(0xffffe2d1)),
  games('Игры', Icons.sports_esports_outlined, Color(0xffdfeec8)),
  wardrobe('Гардероб', Icons.checkroom_outlined, Color(0xffffecc1));

  const PetRoom(this.label, this.icon, this.tint);

  final String label;
  final IconData icon;
  final Color tint;
}

class PetRoomPage extends StatefulWidget {
  const PetRoomPage({
    super.key,
    required this.room,
    required this.service,
    required this.character,
    required this.pet,
    required this.accessory,
  });

  final PetRoom room;
  final TaskService service;
  final Character character;
  final PetStatus pet;
  final bool accessory;

  @override
  State<PetRoomPage> createState() => _PetRoomPageState();
}

class _PetRoomPageState extends State<PetRoomPage> {
  static const _starsPerRound = 5;
  static const _gameCells = 9;
  final _random = Random();
  late PetStatus _pet = widget.pet;
  bool _busy = false;
  String? _feedback;
  AvatarDance? _dance;
  int _reaction = 0;
  String? _roundId;
  int _target = 0;
  int _stars = 0;

  Future<bool> _act(PetAction action, {String? eventId}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      final result = await widget.service.performPetAction(
        action,
        eventId ?? TaskService.newPetEventId(),
      );
      if (!mounted) return false;
      final completed = result.outcome == PetActionOutcome.completed;
      setState(() {
        _pet = result.pet;
        _feedback = switch (result.outcome) {
          PetActionOutcome.completed =>
            '${action.reaction} +${action.xp} опыта',
          PetActionOutcome.full => switch (action.need) {
            PetNeed.food => 'Питомец уже сыт',
            PetNeed.clean => 'Питомец уже чистый',
            PetNeed.mood => 'У питомца отличное настроение',
          },
          PetActionOutcome.insufficientFish => 'Пока не хватает рыбок',
        };
        if (completed) {
          _reaction++;
          _dance = switch (action) {
            PetAction.apple ||
            PetAction.cookie ||
            PetAction.play => AvatarDance.hops,
            PetAction.wash || PetAction.hug => AvatarDance.sway,
          };
        }
      });
      return completed;
    } catch (_) {
      if (mounted) {
        setState(() => _feedback = 'Не удалось сохранить. Попробуй ещё раз.');
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _wear(PetSkin skin) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!_pet.ownedSkins.contains(skin)) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text('Купить скин «${skin.label}»?'),
            content: Text('Цена — ${fishAmount(skin.cost)}.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Купить'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
      }
      final pet = await widget.service.wearSkin(skin);
      if (!mounted) return;
      setState(() {
        if (pet == null) {
          _feedback = 'Пока не хватает рыбок';
          return;
        }
        _pet = pet;
        _feedback = skin == PetSkin.classic
            ? 'Обычный образ'
            : 'Готово! Новый образ «${skin.label}»';
        _reaction++;
        _dance = AvatarDance.sway;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _feedback = 'Не удалось сохранить образ. Попробуй ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startGame() {
    setState(() {
      _roundId = TaskService.newPetEventId();
      _stars = 0;
      _target = _random.nextInt(_gameCells);
      _feedback = null;
      _dance = null;
    });
  }

  void _catchStar() {
    if (_busy || _roundId == null || _stars >= _starsPerRound) return;
    setState(() {
      _stars++;
      _target = (_target + 1 + _random.nextInt(_gameCells - 1)) % _gameCells;
    });
    if (_stars == _starsPerRound) _finishGame();
  }

  Future<void> _finishGame() async {
    final id = _roundId;
    if (id == null || _stars != _starsPerRound || _busy) return;
    final saved = await _act(PetAction.play, eventId: id);
    if (mounted && saved) setState(() => _roundId = null);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.room.label)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
              children: [
                PetStage(
                  character: widget.character,
                  skin: _pet.skin,
                  accessory: widget.accessory,
                  happy: _dance != null,
                  dance: _dance,
                  avatarKey: ValueKey(_reaction),
                ),
                const SizedBox(height: 12),
                PetProgressBar(progress: _pet.progress),
                if (widget.room != PetRoom.games)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: const Icon(Icons.set_meal_outlined),
                      label: Text(fishAmount(_pet.balance)),
                    ),
                  ),
                if (_feedback case final feedback?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Semantics(liveRegion: true, child: Text(feedback)),
                  ),
                const SizedBox(height: 10),
                ...switch (widget.room) {
                  PetRoom.care => _care(),
                  PetRoom.games => [_game()],
                  PetRoom.wardrobe => _wardrobe(),
                },
              ],
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _care() => [
    for (final need in PetNeed.values)
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          children: [
            SizedBox(width: 112, child: Text(need.label)),
            Expanded(
              child: LinearProgressIndicator(
                value: _pet[need] / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                semanticsLabel: need.label,
              ),
            ),
          ],
        ),
      ),
    const SizedBox(height: 8),
    for (final (action, icon) in [
      (PetAction.apple, Icons.eco_outlined),
      (PetAction.cookie, Icons.cookie_outlined),
      (PetAction.wash, Icons.water_drop_outlined),
      (PetAction.hug, Icons.favorite_outline),
    ])
      Card(
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(action.label),
          trailing: FilledButton.tonal(
            onPressed:
                _busy || _pet.balance < action.cost || _pet[action.need] == 100
                ? null
                : () => _act(action),
            child: Text(switch (action) {
              PetAction.wash => 'Умыть',
              PetAction.hug => 'Обнять',
              _ => fishAmount(action.cost),
            }),
          ),
        ),
      ),
  ];

  Widget _game() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PetAction.play.label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text('Нажимай на звёздочки. Поймай пять за раунд.'),
          const SizedBox(height: 13),
          if (_roundId == null)
            FilledButton(
              onPressed: _startGame,
              child: Text(_stars == 0 ? 'Играть' : 'Сыграть ещё'),
            )
          else ...[
            Text(
              'Поймано $_stars из $_starsPerRound',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (_stars == _starsPerRound)
              FilledButton(
                onPressed: _busy ? null : _finishGame,
                child: const Text('Сохранить результат'),
              )
            else
              GridView(
                primary: false,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 54,
                ),
                children: [
                  for (var cell = 0; cell < _gameCells; cell++)
                    if (cell == _target)
                      IconButton.filledTonal(
                        onPressed: _catchStar,
                        tooltip: 'Поймать звезду',
                        icon: const Icon(
                          Icons.star_rounded,
                          color: Color(0xff8c5305),
                          size: 32,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xffffdda0),
                        ),
                      )
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xffe9f3e5),
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                ],
              ),
          ],
        ],
      ),
    ),
  );

  List<Widget> _wardrobe() => [
    for (final skin in PetSkin.values)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 75,
                decoration: BoxDecoration(
                  color: widget.room.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: CharacterAvatar(character: widget.character, skin: skin),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skin.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (!_pet.ownedSkins.contains(skin))
                      Text(fishAmount(skin.cost)),
                    if (!_pet.ownedSkins.contains(skin) &&
                        _pet.balance < skin.cost)
                      Text(
                        'Не хватает ${fishAmount(skin.cost - _pet.balance)}',
                      ),
                    if (_pet.skin == skin)
                      const Text('Надет')
                    else
                      TextButton(
                        onPressed:
                            _busy ||
                                (!_pet.ownedSkins.contains(skin) &&
                                    _pet.balance < skin.cost)
                            ? null
                            : () => _wear(skin),
                        child: Text(
                          _pet.ownedSkins.contains(skin) ? 'Надеть' : 'Купить',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
  ];
}
