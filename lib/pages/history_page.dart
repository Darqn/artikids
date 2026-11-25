import 'package:flutter/material.dart';

import '../models/task.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.tasks});
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.done).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('История')),
      body: completed.isEmpty
          ? const Center(child: Text('Здесь появятся выполненные задания'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final task in completed)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(_when(task)),
                          Text(switch (task.method) {
                            'clinician' =>
                              'Камера подтвердила движение, врач подтвердил звук',
                            'camera' => 'Камера подтвердила движение',
                            _ => 'Завершено в предыдущей версии',
                          }),
                          if (task.confirmedRepeats case final repeats?)
                            Text(
                              'Повторов: $repeats из ${task.repeats} · +${task.reward} рыбок',
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _when(Task task) {
    final date = DateTime.tryParse(task.completedAt ?? '')?.toLocal();
    if (date == null) return task.date;
    return '${localDate(date)} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
