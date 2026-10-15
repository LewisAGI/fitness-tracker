import 'package:flutter/material.dart';

import 'app.dart';
import 'data/store.dart';
import 'services/checkin_scheduler.dart';
import 'services/notifications.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await startApp());
}

Future<Widget> startApp({
  String? databasePath,
  NotificationPort? notifications,
}) async {
  final store = Store();
  try {
    await store.init(path: databasePath);
  } on StateError catch (error) {
    if (error.message.startsWith('Cannot open a v')) {
      return const DatabaseErrorApp();
    }
    rethrow;
  }
  final port = notifications ?? LocalNotifications();
  if (port is LocalNotifications) {
    await port.init(
      onPayload: (payload) {
        store.pendingSlot.value = payload;
      },
    );
  }
  final scheduler = CheckInScheduler(port);
  final allowed = await scheduler.requestPermissions();
  if (!allowed) {
    await store.setSchedule(
      store.schedule.copyWith(morningEnabled: false, eveningEnabled: false),
    );
    await store.setNotificationsDenied(true);
  }
  await scheduler.reschedule(store.schedule);
  return FitnessApp(store: store, scheduler: scheduler);
}

class DatabaseErrorApp extends StatelessWidget {
  const DatabaseErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Scaffold(
        body: Center(
          child: Tooltip(
            message: 'Database',
            child: Icon(Icons.error_outline, color: AppColors.accent, size: 48),
          ),
        ),
      ),
    );
  }
}
