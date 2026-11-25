import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/task_service.dart';

class TaskCreatorPage extends StatefulWidget {
  const TaskCreatorPage({super.key, required this.service, this.legacy});
  final TaskService service;
  final Task? legacy;

  @override
  State<TaskCreatorPage> createState() => _TaskCreatorPageState();
}

class _TaskCreatorPageState extends State<TaskCreatorPage> {
  final _form = GlobalKey<FormState>();
  late final _reward = TextEditingController(
    text: '${widget.legacy?.reward ?? 10}',
  );
  late DateTime _day = DateUtils.dateOnly(
    DateTime.tryParse(widget.legacy?.date ?? '') ?? DateTime.now(),
  );
  Exercise _exercise = Exercise.open;
  int _repeats = 1;
  int _hold = 1000;
  bool _busy = false;

  @override
  void dispose() {
    _reward.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: _day.isBefore(today) ? _day : today,
      lastDate: _day.isAfter(today.add(const Duration(days: 365)))
          ? _day
          : today.add(const Duration(days: 365)),
    );
    if (mounted && day != null) setState(() => _day = day);
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.service.assign(
        existingId: widget.legacy?.id,
        exercise: _exercise,
        day: localDate(_day),
        reward: int.parse(_reward.text.trim()),
        repeats: _repeats,
        holdMs: _hold,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить назначение')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Новое назначение')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.legacy case final task?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(task.title),
            ),
          DropdownButtonFormField<Exercise>(
            initialValue: _exercise,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Упражнение'),
            items: [
              for (final exercise in Exercise.values)
                DropdownMenuItem(value: exercise, child: Text(exercise.title)),
            ],
            onChanged: _busy
                ? null
                : (exercise) => setState(() => _exercise = exercise!),
          ),
          if (_exercise.needsVoice)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Произношение подтверждает присутствующий врач.'),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickDay,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              'Дата · ${MaterialLocalizations.of(context).formatCompactDate(_day)}',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _repeats,
            decoration: const InputDecoration(labelText: 'Число повторов'),
            items: List.generate(
              10,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text('${index + 1}'),
              ),
            ),
            onChanged: _busy
                ? null
                : (value) => setState(() => _repeats = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _hold,
            decoration: const InputDecoration(labelText: 'Время удержания'),
            items: List.generate(
              10,
              (index) => DropdownMenuItem(
                value: (index + 1) * 500,
                child: Text(
                  '${((index + 1) / 2).toString().replaceAll('.', ',')} с',
                ),
              ),
            ),
            onChanged: _busy ? null : (value) => setState(() => _hold = value!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _reward,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Награда в рыбках'),
            validator: (text) {
              final number = int.tryParse(text?.trim() ?? '');
              return number == null || number < 0 || number > 999
                  ? 'Введите число от 0 до 999'
                  : null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Назначить'),
          ),
        ],
      ),
    ),
  );
}
