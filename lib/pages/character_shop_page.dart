import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/task_service.dart';
import '../widgets/character_avatar.dart';

class CharacterShopPage extends StatefulWidget {
  const CharacterShopPage({
    super.key,
    required this.service,
    required this.collection,
  });

  final TaskService service;
  final CharacterCollection collection;

  @override
  State<CharacterShopPage> createState() => _CharacterShopPageState();
}

class _CharacterShopPageState extends State<CharacterShopPage> {
  late CharacterCollection _collection = widget.collection;
  bool _busy = false;
  bool _loadFailed = false;

  Future<void> _change(Character character) async {
    if (_busy || _loadFailed) return;
    setState(() => _busy = true);
    bool? purchased;
    try {
      if (_collection.owned.contains(character)) {
        await widget.service.selectCharacter(character);
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text('Купить персонажа «${character.name}»?'),
            content: Text(
              'Из копилки спишется ${fishAmount(character.price)}.',
            ),
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
        purchased = await widget.service.purchaseCharacter(character);
      }
      if (mounted) await _reload();
      if (mounted && purchased == false) {
        _showMessage('Для покупки пока не хватает рыбок');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Не удалось сохранить выбор. Попробуй ещё раз.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    try {
      final collection = await widget.service.characters();
      if (mounted) {
        setState(() {
          _collection = collection;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Магазин персонажей')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 32).clamp(0.0, 540.0);
            final columns =
                width >= 276 && MediaQuery.textScalerOf(context).scale(14) <= 20
                ? 2
                : 1;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Center(
                  child: SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            avatar: const Icon(
                              Icons.set_meal_rounded,
                              color: Color(0xff7b571f),
                            ),
                            backgroundColor: const Color(0xffffedcf),
                            label: Text(fishAmount(_collection.balance)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_loadFailed) ...[
                          const Text('Не удалось обновить магазин'),
                          TextButton(
                            onPressed: _reload,
                            child: const Text('Повторить'),
                          ),
                        ],
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final character in Character.values)
                              SizedBox(
                                width: columns == 1 ? width : (width - 12) / 2,
                                child: _CharacterCard(
                                  character: character,
                                  collection: _collection,
                                  onPressed: _busy || _loadFailed
                                      ? null
                                      : () => _change(character),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.collection,
    required this.onPressed,
  });

  final Character character;
  final CharacterCollection collection;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final selected = collection.selected == character;
    final owned = collection.owned.contains(character);
    final missing = character.price - collection.balance;
    final color = switch (character) {
      Character.cat => const Color(0xffffefcf),
      Character.fox => const Color(0xffffe4da),
      Character.rabbit => const Color(0xffefe0ff),
      Character.panda => const Color(0xffdff2ea),
    };
    final style = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: SizedBox(
                  width: 102,
                  child: CharacterAvatar(character: character),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              character.name,
              textAlign: TextAlign.center,
              style: style.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            if (!owned)
              Text(fishAmount(character.price), textAlign: TextAlign.center),
            if (!owned && missing > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Не хватает: ${fishAmount(missing)}',
                  textAlign: TextAlign.center,
                  style: style.bodySmall,
                ),
              ),
            const SizedBox(height: 7),
            if (selected)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Выбран', textAlign: TextAlign.center),
              )
            else
              FilledButton.tonal(
                onPressed: owned || missing <= 0 ? onPressed : null,
                child: Text(owned ? 'Выбрать' : 'Купить'),
              ),
          ],
        ),
      ),
    );
  }
}
