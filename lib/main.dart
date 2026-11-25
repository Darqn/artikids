import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/character.dart';
import 'models/pet.dart';
import 'models/task.dart';
import 'pages/character_shop_page.dart';
import 'pages/exercise_page.dart';
import 'pages/history_page.dart';
import 'pages/pet_room_page.dart';
import 'pages/settings_page.dart';
import 'services/observation_source_native.dart'
    if (dart.library.js_interop) 'services/observation_source_web.dart';
import 'services/observations.dart';
import 'services/task_service.dart';
import 'widgets/pet_stage.dart';
import 'widgets/task_tile.dart';

void main() =>
    runApp(MyApp(service: TaskService(), source: createObservationSource()));

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.service, required this.source});
  final TaskService service;
  final ObservationSource source;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Артикидс',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff28765a)),
      scaffoldBackgroundColor: const Color(0xfffff8ec),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xfffff8ec)),
      cardTheme: CardThemeData(
        color: const Color(0xfffffdf8),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.only(bottom: 10),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    home: HomePage(service: service, source: source),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.service, required this.source});
  final TaskService service;
  final ObservationSource source;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<Task>? _tasks;
  CharacterCollection? _characters;
  PetStatus? _pet;
  String _profile = 'Котёнок';
  bool _accessory = false;
  bool _failed = false;
  bool _navigating = false;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final id = ++_loadId;
    try {
      final tasks = await widget.service.tasks();
      final characters = await widget.service.characters();
      final pet = await widget.service.pet();
      final profile = await widget.service.setting('profile');
      final accessory = await widget.service.setting('accessory');
      if (!mounted || id != _loadId) return;
      setState(() {
        _tasks = tasks;
        _characters = characters;
        _pet = pet;
        _failed = false;
        _profile = profile ?? 'Котёнок';
        _accessory =
            accessory == 'star' && tasks.any((task) => task.method != null);
      });
    } catch (_) {
      if (mounted && id == _loadId) setState(() => _failed = true);
    }
  }

  Future<void> _openAdult() async {
    if (_navigating) return;
    _navigating = true;
    try {
      if (!await unlockAdult(context, widget.service, allowSetup: true) ||
          !mounted) {
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsPage(service: widget.service),
        ),
      );
      if (mounted) await _load();
    } finally {
      _navigating = false;
    }
  }

  Future<void> _openPage(Widget page) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      if (mounted) await _load();
    } finally {
      _navigating = false;
    }
  }

  void _start(Task task) {
    if (!task.availableOn(DateTime.now())) return;
    _openPage(
      ExercisePage(
        task: task,
        service: widget.service,
        source: widget.source,
        accessory: _accessory,
        character: _characters!.selected,
        skin: _pet!.skin,
      ),
    );
  }

  void _openRoom(PetRoom room) {
    _openPage(
      PetRoomPage(
        room: room,
        service: widget.service,
        character: _characters!.selected,
        pet: _pet!,
        accessory: _accessory,
      ),
    );
  }

  Future<void> _toggleAccessory() async {
    try {
      await widget.service.setSetting('accessory', _accessory ? '' : 'star');
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить внешность')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    final active =
        tasks
            ?.where(
              (task) =>
                  task.exercise != null && task.availableOn(DateTime.now()),
            )
            .toList() ??
        [];
    final unlocked = tasks?.any((task) => task.method != null) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Артикидс',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (tasks != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                backgroundColor: const Color(0xffffedcf),
                avatar: const Icon(
                  Icons.set_meal_rounded,
                  color: Color(0xff7b571f),
                ),
                label: Text(
                  fishAmount(_characters!.balance),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Кабинет врача',
            onPressed: _openAdult,
            icon: const Icon(Icons.medical_services_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _failed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Не удалось загрузить данные. Старый файл заданий сохранён.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              )
            : tasks == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: const Color(0xfffffcf4),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Привет, $_profile!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          PetStage(
                            character: _characters!.selected,
                            skin: _pet!.skin,
                            accessory: _accessory,
                          ),
                          const SizedBox(height: 9),
                          Text(
                            _characters!.selected.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          PetProgressBar(progress: _pet!.progress),
                          if (unlocked)
                            TextButton.icon(
                              onPressed: _toggleAccessory,
                              icon: Icon(
                                _accessory
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                              ),
                              label: Text(
                                _accessory
                                    ? 'Снять звёздочку'
                                    : 'Надеть звёздочку',
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final room in PetRoom.values)
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: room.tint,
                            ),
                            onPressed: () => _openRoom(room),
                            icon: Icon(room.icon),
                            label: Text(room.label),
                          ),
                        FilledButton.tonalIcon(
                          onPressed: () => _openPage(
                            CharacterShopPage(
                              service: widget.service,
                              collection: _characters!,
                            ),
                          ),
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('Магазин'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Задания',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HistoryPage(tasks: tasks),
                            ),
                          ),
                          icon: const Icon(Icons.history),
                          label: const Text('История'),
                        ),
                      ],
                    ),
                    if (active.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Доступных заданий пока нет'),
                        ),
                      ),
                    for (final task in active)
                      TaskTile(task: task, onStart: () => _start(task)),
                  ],
                ),
              ),
      ),
    );
  }
}
