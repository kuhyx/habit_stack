// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:habit_stack/screens/habit_list_screen.dart';
import 'package:habit_stack/services/habit_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HabitStorageService.init();
  runApp(const HabitStackApp());
}

/// Root widget: bootstraps the theme and points at [HabitListScreen].
class HabitStackApp extends StatelessWidget {
  /// Creates a [HabitStackApp].
  const HabitStackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Stack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF66BB6A)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF66BB6A),
          brightness: Brightness.dark,
        ),
      ),
      home: const HabitListScreen(),
    );
  }
}
