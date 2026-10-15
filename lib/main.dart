import 'package:flutter/material.dart';

import 'app.dart';
import 'data/store.dart';
import 'services/checkin_scheduler.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.init();
  final notifications = LocalNotifications();
  await notifications.init(
    onPayload: (payload) {
      store.pendingSlot.value = payload;
    },
  );
  final scheduler = CheckInScheduler(notifications);
  await scheduler.reschedule(store.schedule);
  runApp(FitnessApp(store: store, scheduler: scheduler));
}
