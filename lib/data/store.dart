import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/training.dart';
import '../services/checkin_scheduler.dart';
import '../services/dates.dart';
import '../services/export_summary.dart';
import '../services/load_model.dart';
import '../services/overload.dart';
import '../services/patterns.dart';
import '../services/readiness.dart';
import '../services/rules.dart';
import '../services/voice_parser.dart';
import 'database.dart';

class DayBundle {
  const DayBundle({
    required this.date,
    required this.sessions,
    required this.plans,
    required this.warnings,
    this.morning,
    this.evening,
  });

  final DateTime date;
  final List<Session> sessions;
  final List<PlanItem> plans;
  final List<StoredWarning> warnings;
  final CheckIn? morning;
  final CheckIn? evening;
}

class WeekBundle {
  const WeekBundle({
    required this.start,
    required this.days,
    required this.suggestions,
  });

  final DateTime start;
  final List<DayBundle> days;
  final List<StoredSuggestion> suggestions;
}

class Store extends ChangeNotifier {
  Store({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final ValueNotifier<String?> pendingSlot = ValueNotifier(null);

  Database? _db;
  List<Exercise> exercises = [];
  CheckInSchedule schedule = CheckInSchedule.defaults;
  int roundMinutes = 3;
  var notificationsDenied = false;
  Future<void> _weekGate = Future<void>.value();
  var _inflight = 0;
  final List<Completer<void>> _idle = [];

  /// Completes when screen reloads started by the last change have finished.
  /// Widget tests await this so a sqflite lock timer is not still pending.
  Future<void> get settled {
    if (_inflight == 0) {
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _idle.add(waiter);
    return waiter.future;
  }

  Future<T> _track<T>(Future<T> future) {
    _inflight++;
    return future.whenComplete(() {
      _inflight--;
      if (_inflight == 0) {
        final waiters = List<Completer<void>>.of(_idle);
        _idle.clear();
        for (final waiter in waiters) {
          if (!waiter.isCompleted) {
            waiter.complete();
          }
        }
      }
    });
  }

  DateTime now() => _clock();

  Future<void> init({String? path}) async {
    _db = await openFitnessDatabase(path: path);
    exercises = await _readExercises();
    schedule = await _readSchedule();
    roundMinutes = int.tryParse(await _setting('round_minutes') ?? '') ?? 3;
    notificationsDenied = (await _setting('notifications_denied') ?? '0') == '1';
    notifyListeners();
  }

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('Store.init has not finished.');
    }
    return database;
  }

  Exercise? exerciseById(int? id) {
    if (id == null) {
      return null;
    }
    for (final exercise in exercises) {
      if (exercise.id == id) {
        return exercise;
      }
    }
    return null;
  }

  Future<void> addAlias(int exerciseId, String alias) async {
    final cleaned = alias.toLowerCase().trim();
    if (cleaned.length < 2 || cleaned.length > 40) {
      return;
    }
    final exercise = exerciseById(exerciseId);
    if (exercise == null) {
      return;
    }
    final existing = exercise.aliases.map((item) => item.toLowerCase()).toSet()
      ..add(exercise.name.toLowerCase());
    if (existing.contains(cleaned)) {
      return;
    }
    final aliases = [...exercise.aliases, cleaned];
    await db.update(
      'exercises',
      {'aliases': jsonEncode(aliases)},
      where: 'id = ?',
      whereArgs: [exerciseId],
    );
    exercises = await _readExercises();
    notifyListeners();
  }

  Future<void> setSchedule(CheckInSchedule next) async {
    schedule = next;
    await _putSetting('morning_enabled', next.morningEnabled ? '1' : '0');
    await _putSetting(
      'morning_hm',
      fmtHm(next.morningHour, next.morningMinute),
    );
    await _putSetting('evening_enabled', next.eveningEnabled ? '1' : '0');
    await _putSetting(
      'evening_hm',
      fmtHm(next.eveningHour, next.eveningMinute),
    );
    notifyListeners();
  }

  Future<void> setNotificationsDenied(bool denied) async {
    notificationsDenied = denied;
    await _putSetting('notifications_denied', denied ? '1' : '0');
    notifyListeners();
  }

  Future<void> setRoundMinutes(int minutes) async {
    final next = minutes < 1 ? 1 : minutes;
    roundMinutes = next;
    await _putSetting('round_minutes', '$next');
    notifyListeners();
  }

  Future<DayBundle> loadDay(DateTime day) {
    return _track(_readDay(day));
  }

  Future<DayBundle> _readDay(DateTime day) async {
    final date = isoDate(day);
    final sessions = await _sessionsBetween(date, date);
    final plans = await _plansBetween(date, date);
    final warnings = await _warningsBetween(date, date);
    final morning = await _checkIn(date, 'morning');
    final evening = await _checkIn(date, 'evening');
    return DayBundle(
      date: dateOnly(day),
      sessions: sessions,
      plans: plans,
      warnings: warnings,
      morning: morning,
      evening: evening,
    );
  }

  Future<WeekBundle> loadWeek(DateTime anchor) {
    // Plan reloads on every store change. Overlapping refreshes both insert
    // the same suggestion row and hit the unique key.
    final run = _weekGate.then((_) => _loadWeek(anchor));
    _weekGate = run.then((_) {}, onError: (Object _, StackTrace _) {});
    return _track(run);
  }

  Future<WeekBundle> _loadWeek(DateTime anchor) async {
    final start = weekStart(anchor);
    await refreshWarnings(start);
    await refreshSuggestions(start.subtract(const Duration(days: 7)));
    final days = <DayBundle>[];
    for (var i = 0; i < 7; i++) {
      days.add(await loadDay(start.add(Duration(days: i))));
    }
    final suggestions = await suggestionsForWeek(isoDate(start.subtract(const Duration(days: 7))));
    return WeekBundle(start: start, days: days, suggestions: suggestions);
  }

  Future<Set<String>> markedDays(DateTime month) {
    return _track(_readMarkedDays(month));
  }

  Future<Set<String>> _readMarkedDays(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1, 0);
    final sessions = await _sessionsBetween(isoDate(start), isoDate(end));
    final checkins = await _checkInsBetween(isoDate(start), isoDate(end));
    return {
      for (final session in sessions) session.date,
      for (final checkIn in checkins) checkIn.date,
    };
  }

  Future<void> saveParse(ParseResult result, {DateTime? on}) async {
    final day = dateOnly(on ?? now());
    final time = fmtHm(now().hour, now().minute);
    await db.transaction((txn) async {
      await _writeParse(txn, result, isoDate(day), time);
    });
    notifyListeners();
  }

  Future<void> replaceSession(int id, ParseResult result) async {
    final rows = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return;
    }
    final date = rows.first['date'] as String;
    final time = rows.first['start_time'] as String?;
    await db.transaction((txn) async {
      await txn.delete('sets', where: 'session_id = ?', whereArgs: [id]);
      await txn.delete(
        'session_blocks',
        where: 'session_id = ?',
        whereArgs: [id],
      );
      if (result.sessions.isEmpty) {
        await txn.delete('sessions', where: 'id = ?', whereArgs: [id]);
        return;
      }
      final first = result.sessions.first;
      await txn.update(
        'sessions',
        {
          'type': first.type,
          'duration_min': first.durationMin,
          'rpe': first.rpe,
          'raw_transcript': first.raw,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _writeSessionChildren(txn, id, first);
      for (final extra in result.sessions.skip(1)) {
        await _insertSession(txn, extra, date, time);
      }
    });
    notifyListeners();
  }

  Future<void> deleteSession(int id) async {
    await db.transaction((txn) async {
      await txn.delete('sessions', where: 'id = ?', whereArgs: [id]);
    });
    notifyListeners();
  }

  Future<void> _writeParse(
    DatabaseExecutor txn,
    ParseResult result,
    String date,
    String? time,
  ) async {
    if (result.plans.isNotEmpty) {
      final start = weekStart(parseIsoDate(date));
      for (final plan in result.plans) {
        await txn.insert('plan_items', {
          'date': isoDate(start.add(Duration(days: plan.weekday - 1))),
          'type': plan.type,
          'muscle_groups': jsonEncode(plan.muscleGroups),
          'intensity': plan.intensity,
          'duration_min_est': plan.durationMin,
        });
      }
    }
    for (final session in result.sessions) {
      await _insertSession(txn, session, date, time);
    }
  }

  Future<void> _insertSession(
    DatabaseExecutor txn,
    ParsedSession session,
    String date,
    String? time,
  ) async {
    final id = await txn.insert('sessions', {
      'date': date,
      'start_time': time,
      'type': session.type,
      'duration_min': session.durationMin,
      'rpe': session.rpe,
      'raw_transcript': session.raw,
    });
    await _writeSessionChildren(txn, id, session);
  }

  Future<void> _writeSessionChildren(
    DatabaseExecutor txn,
    int id,
    ParsedSession session,
  ) async {
    for (final set in session.sets) {
      final count = set.sets;
      final named = set.rirSetIndex;
      if (named != null && count != null && (named < 0 || named >= count)) {
        await _insertSet(
          txn,
          sessionId: id,
          set: set,
          setCount: count,
          rpe: session.rpe,
          rir: null,
        );
      } else if (named != null && count != null && count > 1) {
        for (var i = 0; i < count; i++) {
          await _insertSet(
            txn,
            sessionId: id,
            set: set,
            setCount: 1,
            rpe: session.rpe,
            rir: i == named ? set.rir : null,
          );
        }
      } else if (set.rirLastOnly && count != null && count > 1) {
        for (var i = 0; i < count; i++) {
          await _insertSet(
            txn,
            sessionId: id,
            set: set,
            setCount: 1,
            rpe: session.rpe,
            rir: i == count - 1 ? set.rir : null,
          );
        }
      } else {
        await _insertSet(
          txn,
          sessionId: id,
          set: set,
          setCount: set.sets,
          rpe: session.rpe,
          rir: set.rir,
        );
      }
      if (set.exerciseId != null) {
        await _putSetting('last_exercise_id', '${set.exerciseId}', txn);
      }
    }
    if (session.distanceKm != null && session.sets.isEmpty) {
      final run = exerciseByName('Run');
      final hike = exerciseByName('Hike');
      final idForType = session.type == 'hike' ? hike?.id : run?.id;
      await txn.insert('sets', {
        'session_id': id,
        'exercise_id': idForType,
        'distance_km': session.distanceKm,
        'duration_s': session.durationMin == null ? null : session.durationMin! * 60,
      });
    }
    for (final block in session.blocks) {
      await txn.insert('session_blocks', {
        'session_id': id,
        'subtype': block.subtype,
        'duration_min': block.durationMin,
        'rpe': block.rpe,
        'load': block.load,
        'label': block.spoken,
      });
    }
  }

  Future<void> addPlan({
    required DateTime date,
    required String type,
    List<String> muscleGroups = const [],
    String? intensity,
    int? durationMin,
  }) async {
    await db.insert('plan_items', {
      'date': isoDate(date),
      'type': type,
      'muscle_groups': jsonEncode(muscleGroups),
      'intensity': intensity,
      'duration_min_est': durationMin,
    });
    notifyListeners();
  }

  Future<void> deletePlan(int id) async {
    await db.delete('plan_items', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<CheckIn?> checkInOn(String date, String slot) => _checkIn(date, slot);

  Future<void> saveCheckIn(CheckIn checkIn) async {
    await db.insert('checkins', {
      'date': checkIn.date,
      'slot': checkIn.slot,
      'soreness': checkIn.soreness,
      'energy': checkIn.energy,
      'sleep_quality': checkIn.sleepQuality,
      'sleep_hours': checkIn.sleepHours,
      'mood': checkIn.mood,
      'stress': checkIn.stress,
      'session_feel': checkIn.sessionFeel,
      'ate_well': checkIn.ateWell,
      'raw_transcript': checkIn.rawTranscript,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _learn(checkIn.date);
    notifyListeners();
  }

  Future<Exercise?> lastExercise() async {
    final raw = await _setting('last_exercise_id');
    if (raw == null) {
      return null;
    }
    return exerciseById(int.tryParse(raw));
  }

  Future<List<StoredPattern>> patterns() {
    return _track(_readPatterns());
  }

  Future<List<StoredPattern>> _readPatterns() async {
    final rows = await db.query('patterns', orderBy: 'key');
    return rows
        .map(
          (row) => StoredPattern(
            key: row['key'] as String,
            n: row['n'] as int,
            meanNextReadiness: (row['mean_next_readiness'] as num).toDouble(),
            meanNextFatigue: (row['mean_next_fatigue'] as num).toDouble(),
            lastUpdated: row['last_updated'] as String,
          ),
        )
        .toList();
  }

  Future<List<StoredSuggestion>> suggestionsForWeek(String weekStart) async {
    final rows = await db.query(
      'overload_suggestions',
      where: 'week_start = ?',
      whereArgs: [weekStart],
      orderBy: 'exercise_name',
    );
    return rows.map(_suggestion).toList();
  }

  Future<void> refreshWarnings(DateTime weekStart) async {
    final end = weekStart.add(const Duration(days: 6));
    final historyStart = weekStart.subtract(const Duration(days: 56));
    final sessions = await _sessionsBetween(
      isoDate(historyStart),
      isoDate(end),
    );
    final plans = await _plansBetween(isoDate(weekStart), isoDate(end));
    final checkins = await _checkInsBetween(isoDate(weekStart), isoDate(end));
    final scores = _scoresByDay(checkins);
    final previous = <double>[];
    for (var i = 4; i >= 1; i--) {
      final start = weekStart.subtract(Duration(days: 7 * i));
      final weekEnd = start.add(const Duration(days: 7));
      final total = sessions
          .where((session) {
            final day = parseIsoDate(session.date);
            return !day.isBefore(start) && day.isBefore(weekEnd);
          })
          .fold<double>(0, (sum, session) => sum + loadOf(session));
      if (total > 0) {
        previous.add(total);
      }
    }
    final warnings = evaluateRules(
      RulesInput(
        plans: [for (final plan in plans) _planFact(plan)],
        sessions: [for (final session in sessions) _sessionFact(session)],
        readinessByDay: {
          for (final entry in scores.entries) entry.key: entry.value.readiness,
        },
        historicalLoads: [for (final session in sessions) loadOf(session)],
        previousWeekLoads: previous,
        patterns: await _samples(),
      ),
    );
    await db.delete(
      'warnings_log',
      where: 'date >= ? AND date <= ?',
      whereArgs: [isoDate(weekStart), isoDate(end)],
    );
    for (final warning in warnings) {
      await db.insert('warnings_log', {
        'date': isoDate(warning.date),
        'rule': warning.rule,
        'shown': 1,
        'level': warning.level.name,
        'evidence_json': jsonEncode({
          'evidence': warning.evidence,
          'muscle_groups': warning.muscleGroups,
          'evidence_dates': [
            for (final date in warning.evidenceDates) isoDate(date),
          ],
        }),
      });
    }
  }

  Future<void> refreshSuggestions(DateTime sourceWeek) async {
    final end = sourceWeek.add(const Duration(days: 6));
    final sessions = await _sessionsBetween(isoDate(sourceWeek), isoDate(end));
    final checkins = await _checkInsBetween(isoDate(sourceWeek), isoDate(end));
    final scores = _scoresByDay(checkins);
    final plans = await _plansBetween(isoDate(sourceWeek), isoDate(end));
    final historyStart = sourceWeek.subtract(const Duration(days: 21));
    final history = await _sessionsBetween(
      isoDate(historyStart),
      isoDate(end),
    );
    final warnings = evaluateRules(
      RulesInput(
        plans: [for (final plan in plans) _planFact(plan)],
        sessions: [for (final session in history) _sessionFact(session)],
        readinessByDay: {
          for (final entry in scores.entries) entry.key: entry.value.readiness,
        },
        patterns: await _samples(),
      ),
    );
    final muscles = warnedMuscles(warnings);
    final priorRows = await suggestionsForWeek(
      isoDate(sourceWeek.subtract(const Duration(days: 7))),
    );
    final priorByExercise = {for (final row in priorRows) row.exerciseId: row};
    final grouped = <int, List<WorkingSet>>{};
    final names = <int, String>{};
    final groups = <int, List<String>>{};
    for (final session in sessions) {
      for (final set in session.sets) {
        final id = set.exerciseId;
        final weight = set.weightKg;
        final reps = set.reps;
        if (id == null || weight == null || reps == null) {
          continue;
        }
        final exercise = exerciseById(id);
        if (exercise == null || exercise.category != 'strength') {
          continue;
        }
        grouped.putIfAbsent(id, () => []);
        final count = set.setCount ?? 1;
        for (var i = 0; i < count; i++) {
          grouped[id]!.add(
            WorkingSet(weightKg: weight, reps: reps, rir: set.rir),
          );
        }
        names[id] = exercise.name;
        groups[id] = exercise.muscleGroups;
      }
    }
    final suggestions = suggestWeek(
      lifts: [
        for (final entry in grouped.entries)
          LiftWeekInput(
            exerciseId: entry.key,
            exerciseName: names[entry.key]!,
            muscleGroups: groups[entry.key] ?? const [],
            sets: entry.value,
            priorRepLow: priorByExercise[entry.key]?.repLow,
            priorRepHigh: priorByExercise[entry.key]?.repHigh,
          ),
      ],
      context: WeekContext(
        meanReadiness: meanReadiness(scores.values.map((score) => score.readiness)),
        warnedMuscles: muscles,
      ),
    );
    await db.delete(
      'overload_suggestions',
      where: 'week_start = ?',
      whereArgs: [isoDate(sourceWeek)],
    );
    for (final suggestion in suggestions) {
      await db.insert('overload_suggestions', {
        'week_start': isoDate(sourceWeek),
        'exercise_id': suggestion.exerciseId,
        'exercise_name': suggestion.exerciseName,
        'working_weight_kg': suggestion.workingWeightKg,
        'reps_csv': suggestion.reps.join(','),
        'rep_low': suggestion.repLow,
        'rep_high': suggestion.repHigh,
        'action': suggestion.action.name,
        'suggested_weight_kg': suggestion.suggestedWeightKg,
        'aim_reps': suggestion.aimReps,
        'card': suggestion.card,
        'muscle_groups': jsonEncode(suggestion.muscleGroups),
      });
    }
    await _stampPlans(
      sourceWeek.add(const Duration(days: 7)),
      suggestions,
    );
  }

  Future<ExportFiles> exportRange({
    required DateTime start,
    required DateTime end,
    required String kind,
  }) async {
    final sessions = await _sessionsBetween(isoDate(start), isoDate(end));
    final plans = await _plansBetween(isoDate(start), isoDate(end));
    final checkins = await _checkInsBetween(isoDate(start), isoDate(end));
    final warnings = await _warningsBetween(isoDate(start), isoDate(end));
    final scores = _scoresByDay(checkins);
    final suggestionRows = await db.query(
      'overload_suggestions',
      where: 'week_start >= ? AND week_start <= ?',
      whereArgs: [
        isoDate(start.subtract(const Duration(days: 7))),
        isoDate(end),
      ],
    );
    return buildExport(
      ExportSnapshot(
        kind: kind,
        start: start,
        end: end,
        sessions: sessions,
        plans: plans,
        checkins: checkins,
        warnings: warnings,
        patterns: await patterns(),
        suggestions: suggestionRows.map(_suggestion).toList(),
        readinessByDay: {
          for (final entry in scores.entries) entry.key: entry.value.readiness,
        },
        fatigueByDay: {
          for (final entry in scores.entries) entry.key: entry.value.fatigue,
        },
      ),
    );
  }

  Future<void> importSummary(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('import');
    }
    if (decoded is! Map || decoded['schema'] != 'fitness-summary-v1') {
      throw const FormatException('import');
    }
    final sessions = decoded['sessions'];
    final checkins = decoded['checkins'];
    final plan = decoded['plan'];
    if (sessions is! List || checkins is! List || plan is! List) {
      throw const FormatException('import');
    }
    for (final item in sessions) {
      if (item is! Map || item['date'] is! String || item['type'] is! String) {
        throw const FormatException('import');
      }
      if (item['sets'] is! List || item['blocks'] is! List) {
        throw const FormatException('import');
      }
    }
    for (final item in checkins) {
      if (item is! Map || item['date'] is! String || item['slot'] is! String) {
        throw const FormatException('import');
      }
    }
    for (final item in plan) {
      if (item is! Map || item['date'] is! String || item['type'] is! String) {
        throw const FormatException('import');
      }
    }
    await db.transaction((txn) async {
      for (final item in sessions) {
        final existing = await txn.query(
          'sessions',
          where:
              "date = ? AND ifnull(start_time, '') = ? AND type = ? AND ifnull(raw_transcript, '') = ?",
          whereArgs: [
            item['date'],
            item['start_time'] ?? '',
            item['type'],
            item['raw_transcript'] ?? '',
          ],
        );
        if (existing.isNotEmpty) {
          continue;
        }
        final id = await txn.insert('sessions', {
          'date': item['date'],
          'start_time': item['start_time'],
          'type': item['type'],
          'duration_min': item['duration_min'],
          'rpe': item['rpe'],
          'notes': item['notes'],
          'raw_transcript': item['raw_transcript'],
        });
        for (final set in item['sets'] as List) {
          if (set is! Map) {
            throw const FormatException('import');
          }
          await txn.insert('sets', {
            'session_id': id,
            'exercise_id': set['exercise_id'],
            'set_count': set['set_count'],
            'reps': set['reps'],
            'weight_kg': set['weight_kg'],
            'distance_km': set['distance_km'],
            'duration_s': set['duration_s'],
            'rpe': set['rpe'],
            'bodyweight': set['bodyweight'] == true ? 1 : 0,
            'rir': set['rir'],
          });
        }
        for (final block in item['blocks'] as List) {
          if (block is! Map) {
            throw const FormatException('import');
          }
          await txn.insert('session_blocks', {
            'session_id': id,
            'subtype': block['subtype'],
            'duration_min': block['duration_min'],
            'rpe': block['rpe'] ?? 0,
            'load': block['load'] ?? 0,
            'label': block['label'],
          });
        }
      }
      for (final item in checkins) {
        await txn.insert('checkins', {
          'date': item['date'],
          'slot': item['slot'],
          'soreness': item['soreness'],
          'energy': item['energy'],
          'sleep_quality': item['sleep_quality'],
          'sleep_hours': item['sleep_hours'],
          'mood': item['mood'],
          'stress': item['stress'],
          'session_feel': item['session_feel'],
          'ate_well': item['ate_well'],
          'raw_transcript': item['raw_transcript'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final item in plan) {
        final muscles = _musclesJson(item['muscle_groups']);
        final existing = await txn.query(
          'plan_items',
          where:
              "date = ? AND type = ? AND muscle_groups = ? AND ifnull(intensity, '') = ?",
          whereArgs: [
            item['date'],
            item['type'],
            muscles,
            item['intensity'] ?? '',
          ],
        );
        if (existing.isNotEmpty) {
          continue;
        }
        await txn.insert('plan_items', {
          'date': item['date'],
          'type': item['type'],
          'muscle_groups': muscles,
          'intensity': item['intensity'],
          'duration_min_est': item['duration_min_est'],
          'suggestion': item['suggestion'],
        });
      }
    });
    notifyListeners();
  }

  Future<void> _insertSet(
    DatabaseExecutor txn, {
    required int sessionId,
    required ParsedSet set,
    required int? setCount,
    required int? rpe,
    required int? rir,
  }) async {
    await txn.insert('sets', {
      'session_id': sessionId,
      'exercise_id': set.exerciseId,
      'set_count': setCount,
      'reps': set.reps,
      'weight_kg': set.weightKg,
      'bodyweight': set.bodyweight ? 1 : 0,
      'rpe': rpe,
      'rir': rir,
    });
  }

  Exercise? exerciseByName(String name) {
    for (final exercise in exercises) {
      if (exercise.name.toLowerCase() == name.toLowerCase()) {
        return exercise;
      }
    }
    return null;
  }

  Future<void> _stampPlans(
    DateTime targetWeek,
    List<OverloadSuggestion> suggestions,
  ) async {
    final plans = await _plansBetween(
      isoDate(targetWeek),
      isoDate(targetWeek.add(const Duration(days: 6))),
    );
    for (final plan in plans) {
      if (plan.type != 'gym') {
        continue;
      }
      final lines = suggestions
          .where((suggestion) => _planMatches(plan, suggestion))
          .map((suggestion) => suggestion.card)
          .toList();
      await db.update(
        'plan_items',
        {'suggestion': lines.isEmpty ? null : lines.join('\n')},
        where: 'id = ?',
        whereArgs: [plan.id],
      );
    }
  }

  bool _planMatches(PlanItem plan, OverloadSuggestion suggestion) {
    if (plan.muscleGroups.isEmpty) {
      return true;
    }
    final planned = plan.muscleGroups.map((item) => item.toLowerCase()).toSet();
    if (planned.any(legGroups.contains)) {
      return isLowerBody(suggestion.muscleGroups);
    }
    return suggestion.muscleGroups.any(
      (muscle) => planned.contains(muscle.toLowerCase()),
    );
  }

  Future<void> _learn(String outcomeDate) async {
    final morning = await _checkIn(outcomeDate, 'morning');
    final evening = await _checkIn(outcomeDate, 'evening');
    final score = scoreCheckIns(
      soreness: morning?.soreness,
      energy: morning?.energy,
      sleepQuality: morning?.sleepQuality,
      mood: morning?.mood,
      stress: morning?.stress,
      eveningEnergy: evening?.energy,
      ateWell: evening?.ateWell,
      sessionFeel: evening?.sessionFeel,
      eveningStress: evening?.stress,
    );
    if (score == null) {
      return;
    }
    final day = parseIsoDate(outcomeDate);
    final previous = await _sessionsBetween(
      isoDate(day.subtract(const Duration(days: 1))),
      isoDate(day.subtract(const Duration(days: 1))),
    );
    final earlier = await _sessionsBetween(
      isoDate(day.subtract(const Duration(days: 2))),
      isoDate(day.subtract(const Duration(days: 2))),
    );
    final book = PatternBook()..samples.addAll(await _samples());
    book.learn(
      outcomeDay: day,
      dayMinus1: previous.map(_signatureInput).toList(),
      dayMinus2: earlier.map(_signatureInput).toList(),
      readiness: score.readiness,
      fatigue: score.fatigue,
    );
    await db.delete('pattern_samples');
    await db.delete('patterns');
    for (final sample in book.samples) {
      await db.insert('pattern_samples', {
        'pattern_key': sample.key,
        'outcome_date': isoDate(sample.outcomeDate),
        'readiness': sample.readiness,
        'fatigue': sample.fatigue,
      });
    }
    final keys = book.samples.map((sample) => sample.key).toSet();
    for (final key in keys) {
      final stats = book.stats(key);
      await db.insert('patterns', {
        'key': key,
        'n': stats.n,
        'mean_next_readiness': stats.meanReadiness,
        'mean_next_fatigue': stats.meanFatigue,
        'last_updated': isoDate(now()),
      });
    }
  }

  DaySignatureInput _signatureInput(Session session) {
    return DaySignatureInput(
      type: session.type,
      rpe: session.rpe,
      muscleGroups: _muscles(session),
      subtypes: [for (final block in session.blocks) block.subtype],
      load: loadOf(session),
    );
  }

  SessionFact _sessionFact(Session session) {
    return SessionFact(
      at: _at(session),
      type: session.type,
      load: loadOf(session),
      rpe: session.rpe,
      muscleGroups: _muscles(session),
      subtypes: [for (final block in session.blocks) block.subtype],
    );
  }

  PlanFact _planFact(PlanItem plan) {
    return PlanFact(
      date: parseIsoDate(plan.date),
      type: plan.type,
      load: planLoadOf(plan),
      intensity: plan.intensity,
      muscleGroups: plan.muscleGroups,
      durationMin: plan.durationMinEst,
    );
  }

  List<String> _muscles(Session session) {
    final muscles = <String>{};
    for (final set in session.sets) {
      muscles.addAll(set.muscleGroups);
    }
    return muscles.toList();
  }

  DateTime _at(Session session) {
    final day = parseIsoDate(session.date);
    final time = session.startTime;
    if (time == null || !time.contains(':')) {
      return DateTime(day.year, day.month, day.day, 12);
    }
    final parts = time.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  Map<String, ReadinessScore> _scoresByDay(List<CheckIn> checkins) {
    final grouped = <String, List<CheckIn>>{};
    for (final checkIn in checkins) {
      grouped.putIfAbsent(checkIn.date, () => []).add(checkIn);
    }
    final scores = <String, ReadinessScore>{};
    for (final entry in grouped.entries) {
      CheckIn? morning;
      CheckIn? evening;
      for (final checkIn in entry.value) {
        if (checkIn.slot == 'morning') {
          morning = checkIn;
        } else {
          evening = checkIn;
        }
      }
      final score = scoreCheckIns(
        soreness: morning?.soreness,
        energy: morning?.energy,
        sleepQuality: morning?.sleepQuality,
        mood: morning?.mood,
        stress: morning?.stress,
        eveningEnergy: evening?.energy,
        ateWell: evening?.ateWell,
        sessionFeel: evening?.sessionFeel,
        eveningStress: evening?.stress,
      );
      if (score != null) {
        scores[entry.key] = score;
      }
    }
    return scores;
  }

  Future<List<PatternSample>> _samples() async {
    final rows = await db.query('pattern_samples');
    return [
      for (final row in rows)
        PatternSample(
          key: row['pattern_key'] as String,
          outcomeDate: parseIsoDate(row['outcome_date'] as String),
          readiness: (row['readiness'] as num).toDouble(),
          fatigue: (row['fatigue'] as num).toDouble(),
        ),
    ];
  }

  Future<List<Exercise>> _readExercises() async {
    final rows = await db.query('exercises', orderBy: 'name');
    return [
      for (final row in rows)
        Exercise(
          id: row['id'] as int,
          name: row['name'] as String,
          category: row['category'] as String,
          muscleGroups: decodeStrings(row['muscle_groups'] as String?),
          aliases: decodeStrings(row['aliases'] as String?),
          defaultLoadFactor: (row['default_load_factor'] as num).toDouble(),
        ),
    ];
  }

  Future<CheckInSchedule> _readSchedule() async {
    final morning = await _setting('morning_hm') ?? '08:00';
    final evening = await _setting('evening_hm') ?? '21:00';
    final morningParts = morning.split(':');
    final eveningParts = evening.split(':');
    return CheckInSchedule(
      morningEnabled: (await _setting('morning_enabled') ?? '1') == '1',
      morningHour: int.parse(morningParts[0]),
      morningMinute: int.parse(morningParts[1]),
      eveningEnabled: (await _setting('evening_enabled') ?? '1') == '1',
      eveningHour: int.parse(eveningParts[0]),
      eveningMinute: int.parse(eveningParts[1]),
    );
  }

  Future<String?> _setting(String key) async {
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> _putSetting(
    String key,
    String value, [
    DatabaseExecutor? exec,
  ]) async {
    await (exec ?? db).insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Session>> _sessionsBetween(String start, String end) async {
    final rows = await db.query(
      'sessions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      orderBy: 'date, start_time, id',
    );
    final sessions = <Session>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final setRows = await db.query(
        'sets',
        where: 'session_id = ?',
        whereArgs: [id],
        orderBy: 'id',
      );
      final blockRows = await db.query(
        'session_blocks',
        where: 'session_id = ?',
        whereArgs: [id],
        orderBy: 'id',
      );
      sessions.add(
        Session(
          id: id,
          date: row['date'] as String,
          startTime: row['start_time'] as String?,
          type: row['type'] as String,
          durationMin: row['duration_min'] as int?,
          rpe: row['rpe'] as int?,
          notes: row['notes'] as String?,
          rawTranscript: row['raw_transcript'] as String?,
          sets: [
            for (final set in setRows)
              SetRow(
                id: set['id'] as int,
                sessionId: id,
                exerciseId: set['exercise_id'] as int?,
                exerciseName: exerciseById(set['exercise_id'] as int?)?.name,
                setCount: set['set_count'] as int?,
                reps: set['reps'] as int?,
                weightKg: (set['weight_kg'] as num?)?.toDouble(),
                distanceKm: (set['distance_km'] as num?)?.toDouble(),
                durationS: set['duration_s'] as int?,
                rpe: set['rpe'] as int?,
                bodyweight: (set['bodyweight'] as int? ?? 0) == 1,
                rir: set['rir'] as int?,
                muscleGroups:
                    exerciseById(set['exercise_id'] as int?)?.muscleGroups ??
                    const [],
              ),
          ],
          blocks: [
            for (final block in blockRows)
              SessionBlock(
                id: block['id'] as int,
                sessionId: id,
                subtype: block['subtype'] as String,
                durationMin: block['duration_min'] as int?,
                rpe: block['rpe'] as int,
                load: (block['load'] as num?)?.toDouble() ?? 0,
                label: block['label'] as String?,
              ),
          ],
        ),
      );
    }
    return sessions;
  }

  Future<List<PlanItem>> _plansBetween(String start, String end) async {
    final rows = await db.query(
      'plan_items',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      orderBy: 'date, id',
    );
    return [
      for (final row in rows)
        PlanItem(
          id: row['id'] as int,
          date: row['date'] as String,
          type: row['type'] as String,
          muscleGroups: decodeStrings(row['muscle_groups'] as String?),
          intensity: row['intensity'] as String?,
          durationMinEst: row['duration_min_est'] as int?,
          suggestion: row['suggestion'] as String?,
        ),
    ];
  }

  Future<List<CheckIn>> _checkInsBetween(String start, String end) async {
    final rows = await db.query(
      'checkins',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      orderBy: 'date, slot',
    );
    return rows.map(_checkInFrom).toList();
  }

  Future<CheckIn?> _checkIn(String date, String slot) async {
    final rows = await db.query(
      'checkins',
      where: 'date = ? AND slot = ?',
      whereArgs: [date, slot],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _checkInFrom(rows.first);
  }

  CheckIn _checkInFrom(Map<String, Object?> row) {
    return CheckIn(
      id: row['id'] as int,
      date: row['date'] as String,
      slot: row['slot'] as String,
      soreness: row['soreness'] as int?,
      energy: row['energy'] as int?,
      sleepQuality: row['sleep_quality'] as int?,
      sleepHours: (row['sleep_hours'] as num?)?.toDouble(),
      mood: row['mood'] as int?,
      stress: row['stress'] as int?,
      sessionFeel: row['session_feel'] as int?,
      ateWell: row['ate_well'] as int?,
      rawTranscript: row['raw_transcript'] as String?,
    );
  }

  Future<List<StoredWarning>> _warningsBetween(String start, String end) async {
    final rows = await db.query(
      'warnings_log',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      orderBy: 'date, id',
    );
    return [
      for (final row in rows)
        () {
          final payload = jsonDecode(row['evidence_json'] as String);
          final map = payload is Map ? payload : const <String, Object?>{};
          return StoredWarning(
            id: row['id'] as int,
            date: row['date'] as String,
            rule: row['rule'] as String,
            shown: (row['shown'] as int) == 1,
            level: row['level'] as String,
            evidence: map['evidence'] as String? ?? '',
            muscleGroups: [
              for (final item in (map['muscle_groups'] as List? ?? const []))
                item.toString(),
            ],
            evidenceDates: [
              for (final item in (map['evidence_dates'] as List? ?? const []))
                item.toString(),
            ],
          );
        }(),
    ];
  }

  StoredSuggestion _suggestion(Map<String, Object?> row) {
    return StoredSuggestion(
      id: row['id'] as int? ?? 0,
      weekStart: row['week_start'] as String,
      exerciseId: row['exercise_id'] as int,
      exerciseName: row['exercise_name'] as String,
      workingWeightKg: (row['working_weight_kg'] as num).toDouble(),
      repsCsv: row['reps_csv'] as String,
      repLow: row['rep_low'] as int,
      repHigh: row['rep_high'] as int,
      action: row['action'] as String,
      suggestedWeightKg: (row['suggested_weight_kg'] as num).toDouble(),
      aimReps: row['aim_reps'] as int?,
      card: row['card'] as String,
      muscleGroups: decodeStrings(row['muscle_groups'] as String?),
    );
  }
}

double loadOf(Session session) {
  return sessionLoad(
    type: session.type,
    durationMin: session.durationMin,
    rpe: session.rpe,
    setCount: session.sets.fold<int>(
      0,
      (sum, set) => sum + (set.setCount ?? 1),
    ),
    blocks: [
      for (final block in session.blocks)
        BlockLoad(durationMin: block.durationMin ?? 0, rpe: block.rpe),
    ],
  );
}

double planLoadOf(PlanItem plan) {
  final minutes =
      plan.durationMinEst ??
      switch (plan.type) {
        'muay_thai' => 60,
        'run' => 30,
        'hike' => 90,
        'yoga' => 30,
        _ => 45,
      };
  final rpe = resolvedRpe(
    type: plan.type,
    intensity: plan.intensity,
  );
  return (minutes * rpe).toDouble();
}

String _musclesJson(Object? value) {
  if (value is String) {
    return value;
  }
  if (value is List) {
    return jsonEncode(value);
  }
  return '[]';
}

String sessionLine(Session session) {
  if (session.sets.length == 1 && session.type == 'gym') {
    final set = session.sets.single;
    final name = set.exerciseName ?? '?';
    final load = set.bodyweight
        ? 'bodyweight'
        : set.weightKg == null
        ? null
        : '${_trim(set.weightKg!)} kg';
    final core = '$name · ${set.setCount ?? 1}×${set.reps ?? '-'}';
    return load == null ? core : '$core · $load';
  }
  final bits = <String>[_label(session.type)];
  final distance = session.sets
      .map((set) => set.distanceKm)
      .whereType<double>()
      .toList();
  if (distance.isNotEmpty) {
    bits.add('${_trim(distance.first)} km');
  }
  if (session.durationMin != null) {
    bits.add('${session.durationMin} min');
  }
  if (session.rpe != null) {
    bits.add('RPE ${session.rpe}');
  }
  return bits.join(' · ');
}

String _label(String type) => switch (type) {
  'muay_thai' => 'Muay Thai',
  'gym' => 'Gym',
  'run' => 'Run',
  'hike' => 'Hike',
  'yoga' => 'Yoga',
  _ => 'Other',
};

String _trim(double value) {
  if ((value - value.round()).abs() < 0.001) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

String planLine(PlanItem plan) {
  final bits = <String>[_label(plan.type)];
  if (plan.muscleGroups.isNotEmpty) {
    bits.add(plan.muscleGroups.join(', '));
  }
  if (plan.intensity != null) {
    bits.add(plan.intensity!);
  }
  return bits.join(' · ');
}
