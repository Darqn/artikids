enum Exercise {
  open('open', 'Открой рот', 'Открой рот и подержи'),
  smile('smile', 'Улыбнись', 'Улыбнись и подержи улыбку'),
  vowel('vowel-a', 'Открой рот и скажи «а»', 'Открой рот и протяни «а»');

  const Exercise(this.id, this.title, this.instruction);
  final String id;
  final String title;
  final String instruction;
  bool get needsVoice => this == vowel;

  static Exercise? fromId(Object? id) {
    for (final exercise in values) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }
}

String localDate(DateTime date) => date.toIso8601String().split('T').first;

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.reward,
    required this.date,
    this.exercise,
    this.repeats = 1,
    this.holdMs = 1000,
    this.completedAt,
    this.method,
    this.confirmedRepeats,
    this.legacyDone = false,
  });

  final String id;
  final String title;
  final int reward;
  final String date;
  final Exercise? exercise;
  final int repeats;
  final int holdMs;
  final String? completedAt;
  final String? method;
  final int? confirmedRepeats;
  final bool legacyDone;

  bool get done => completedAt != null || legacyDone;
  bool availableOn(DateTime now) =>
      !done && date.compareTo(localDate(now)) <= 0;

  factory Task.fromRow(Map<String, Object?> row) => Task(
    id: row['id'] as String,
    title: row['title'] as String,
    reward: row['reward'] as int,
    date: row['day'] as String,
    exercise: Exercise.fromId(row['exercise']),
    repeats: row['repeats'] as int,
    holdMs: row['hold_ms'] as int,
    completedAt: row['completed_at'] as String?,
    method: row['method'] as String?,
    confirmedRepeats: row['confirmed_repeats'] as int?,
    legacyDone: row['legacy_done'] == 1,
  );
}
