// coverage:ignore-file
import 'package:habit_stack/screens/habit_list_screen.dart';
import 'package:habit_stack/services/habit_storage_service.dart';
import 'package:habit_stack/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

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
      // No title: on web it becomes the tab text (textgate).
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: const HabitListScreen(),
    );
  }
}
