import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/task_service.dart';
import 'history_page.dart';
import 'task_creator_page.dart';

Future<bool> unlockAdult(
  BuildContext context,
  TaskService service, {
  bool allowSetup = false,
}) async {
  try {
    final create = await service.setting('pin') == null;
    if (!context.mounted) return false;
    if (create && !allowSetup) return false;
    return await showDialog<bool>(
          context: context,
          builder: (_) => _PinDialog(service: service, create: create),
        ) ??
        false;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось прочитать локальные данные. Попробуйте ещё раз.',
          ),
        ),
      );
    }
    return false;
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.service, required this.create});
  final TaskService service;
  final bool create;
  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final valid = await widget.service.setOrVerifyPin(
        _code.text,
        create: widget.create,
      );
      if (!mounted) return;
      if (valid) {
        Navigator.pop(context, true);
        return;
      }
      setState(
        () => _error = widget.create
            ? 'Введите от 4 до 8 цифр'
            : 'Код не подошёл',
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось проверить код');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.create ? 'Создайте код взрослого' : 'Введите код взрослого',
    ),
    content: TextField(
      controller: _code,
      maxLength: 8,
      autofocus: true,
      obscureText: true,
      keyboardType: TextInputType.number,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: 'От 4 до 8 цифр',
        errorText: _error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: const Text('Продолжить'),
      ),
    ],
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.service});
  final TaskService service;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Task>? _tasks;
  String _profile = 'Котёнок';
  bool _error = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final tasks = await widget.service.tasks();
      final profile = await widget.service.setting('profile');
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _profile = profile ?? 'Котёнок';
        _error = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _assign([Task? legacy]) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TaskCreatorPage(service: widget.service, legacy: legacy),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _rename() async {
    var name = _profile;
    final value = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Имя для занятий'),
        content: TextFormField(
          initialValue: name,
          autofocus: true,
          maxLength: 24,
          onChanged: (value) => name = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, name.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (mounted && value != null && value.isNotEmpty) {
      await _write(() => widget.service.setSetting('profile', value));
    }
  }

  Future<void> _clear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Удалить данные ребёнка?'),
        content: const Text(
          'Будут удалены назначения, история, рыбки, персонажи, скины и прогресс питомца.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (mounted && confirm == true) await _write(widget.service.clearProfile);
  }

  Future<void> _write(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) await _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить изменения')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    return Scaffold(
      appBar: AppBar(title: const Text('Кабинет врача')),
      body: _error
          ? Center(
              child: FilledButton(
                onPressed: _reload,
                child: const Text('Повторить загрузку'),
              ),
            )
          : tasks == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.face_retouching_natural),
                    title: Text(_profile),
                    subtitle: const Text('Локальный профиль'),
                    trailing: IconButton(
                      onPressed: _busy ? null : _rename,
                      tooltip: 'Изменить имя',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _assign(),
                  icon: const Icon(Icons.add),
                  label: const Text('Назначить упражнение'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistoryPage(tasks: tasks),
                          ),
                        ),
                  icon: const Icon(Icons.history),
                  label: const Text('История занятий'),
                ),
                const SizedBox(height: 20),
                Text(
                  'Назначения',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (tasks.every((task) => task.done))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Активных назначений пока нет'),
                  ),
                for (final task in tasks.where((task) => !task.done))
                  Card(
                    child: ListTile(
                      title: Text(task.title),
                      subtitle: Text(
                        task.exercise == null
                            ? '${task.date} · требуется выбрать упражнение'
                            : '${task.date} · ${task.repeats} повт.',
                      ),
                      trailing: task.exercise == null
                          ? IconButton(
                              tooltip: 'Выбрать упражнение',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: _busy ? null : () => _assign(task),
                            )
                          : null,
                    ),
                  ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _busy ? null : _clear,
                  child: const Text('Удалить данные ребёнка'),
                ),
              ],
            ),
    );
  }
}
