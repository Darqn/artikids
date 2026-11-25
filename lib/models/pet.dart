enum PetNeed {
  food('food', 'Сытость', 3),
  clean('clean', 'Чистота', 2),
  mood('mood', 'Настроение', 2);

  const PetNeed(this.id, this.label, this.lossPerHour);
  final String id;
  final String label;
  final int lossPerHour;

  static const initial = 65;
  static const minimum = 20;

  int afterHours(int value, int hours) =>
      (value - lossPerHour * hours).clamp(minimum, 100);
}

enum PetAction {
  apple('Яблоко', PetNeed.food, 5, 25, 5),
  cookie('Печенье', PetNeed.food, 9, 45, 8),
  wash('Купание', PetNeed.clean, 0, 30, 5),
  hug('Объятие', PetNeed.mood, 0, 25, 5),
  play('Поймай звёздочки', PetNeed.mood, 0, 35, 12);

  const PetAction(this.label, this.need, this.cost, this.boost, this.xp);
  final String label;
  final PetNeed need;
  final int cost;
  final int boost;
  final int xp;

  String get reaction => switch (this) {
    apple || cookie => 'Ням! Спасибо за угощение',
    wash => 'Теперь чисто и свежо!',
    hug => 'Какое тёплое объятие!',
    play => 'Все звёздочки пойманы!',
  };
}

enum PetSkin {
  classic('classic', 'Обычный', 0),
  bee('bee', 'Пчёлка', 35),
  gardener('gardener', 'Садовник', 50),
  astronaut('astronaut', 'Космонавт', 75);

  const PetSkin(this.id, this.label, this.cost);
  final String id;
  final String label;
  final int cost;
}

class PetProgress {
  const PetProgress(this.totalXp);

  static const xpPerLesson = 20;
  static const xpPerLevel = 50;

  final int totalXp;
  int get level => totalXp ~/ xpPerLevel + 1;
  int get xpInLevel => totalXp % xpPerLevel;
  double get fraction => xpInLevel / xpPerLevel;
}

class PetStatus {
  const PetStatus({
    required this.balance,
    this.skin = PetSkin.classic,
    this.ownedSkins = const {PetSkin.classic},
    this.progress = const PetProgress(0),
    this.needs = const {},
  });

  final int balance;
  final PetSkin skin;
  final Set<PetSkin> ownedSkins;
  final PetProgress progress;
  final Map<PetNeed, int> needs;

  int operator [](PetNeed need) => needs[need] ?? PetNeed.initial;
}

enum PetActionOutcome { completed, full, insufficientFish }

typedef PetActionResult = ({PetActionOutcome outcome, PetStatus pet});
