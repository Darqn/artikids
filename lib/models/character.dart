enum Character {
  cat('cat', 'Котик', 0),
  fox('fox', 'Лисёнок', 60),
  rabbit('rabbit', 'Зайчонок', 90),
  panda('panda', 'Панда', 140);

  const Character(this.id, this.name, this.price);

  final String id;
  final String name;
  final int price;
}

class CharacterCollection {
  const CharacterCollection({
    required this.balance,
    required this.owned,
    required this.selected,
  });

  final int balance;
  final Set<Character> owned;
  final Character selected;
}

String fishAmount(int amount) {
  final last = amount % 10;
  final lastTwo = amount % 100;
  final unit = lastTwo >= 11 && lastTwo <= 14
      ? 'рыбок'
      : switch (last) {
          1 => 'рыбка',
          2 || 3 || 4 => 'рыбки',
          _ => 'рыбок',
        };
  return '$amount $unit';
}
