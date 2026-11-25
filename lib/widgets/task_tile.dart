import 'package:flutter/material.dart';

import '../models/task.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, this.onStart});
  final Task task;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: const Color(0xffffedcf),
        foregroundColor: const Color(0xff644621),
        child: Icon(
          task.exercise?.needsVoice == true
              ? Icons.graphic_eq
              : Icons.tag_faces,
        ),
      ),
      title: Text(
        task.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${task.repeats} повт. · +${task.reward} рыбок'),
      trailing: FilledButton(onPressed: onStart, child: const Text('Начать')),
    ),
  );
}
