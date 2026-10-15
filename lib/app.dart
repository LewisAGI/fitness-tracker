import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/store.dart';
import 'screens/shell.dart';
import 'services/checkin_scheduler.dart';
import 'services/speech_capture.dart';
import 'theme/app_theme.dart';

class FitnessApp extends StatelessWidget {
  const FitnessApp({
    super.key,
    required this.store,
    required this.scheduler,
    this.speech,
  });

  final Store store;
  final CheckInScheduler scheduler;
  final SpeechCapture? speech;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Tracker',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'GB'),
      supportedLocales: const [Locale('en', 'GB')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(),
      home: HomeShell(store: store, scheduler: scheduler, speech: speech),
    );
  }
}
