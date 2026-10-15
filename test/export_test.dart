import 'dart:convert';

import 'package:fitness_tracker/models/training.dart';
import 'package:fitness_tracker/services/export_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('week export includes sessions, check-ins, warnings and lift cards', () {
    final files = buildExport(
      ExportSnapshot(
        kind: 'week',
        start: DateTime(2026, 10, 5),
        end: DateTime(2026, 10, 11),
        sessions: [
          Session(
            id: 1,
            date: '2026-10-05',
            type: 'gym',
            rpe: 6,
            sets: const [
              SetRow(
                exerciseName: 'Bench press',
                setCount: 2,
                reps: 7,
                weightKg: 80,
              ),
            ],
          ),
        ],
        plans: const [
          PlanItem(
            date: '2026-10-12',
            type: 'gym',
            muscleGroups: ['legs'],
            intensity: 'hard',
            suggestion: 'Bench: 80 kg x 7,7 -> keep 80, aim 8s',
          ),
        ],
        checkins: const [
          CheckIn(
            date: '2026-10-05',
            slot: 'morning',
            soreness: 4,
            energy: 7,
            sleepQuality: 8,
            sleepHours: 7.5,
          ),
          CheckIn(
            date: '2026-10-05',
            slot: 'evening',
            sessionFeel: 6,
            ateWell: 8,
            stress: 3,
            energy: 5,
          ),
        ],
        warnings: const [
          StoredWarning(
            date: '2026-10-06',
            rule: 'back_to_back_hard',
            shown: true,
            level: 'upgraded',
            evidence: 'Last 3 times: Thai hard → legs heavy. Next-day fatigue 8, 7, 9.',
          ),
        ],
        patterns: const [
          StoredPattern(
            key: 'muay_thai:hard>gym:legs_heavy',
            n: 3,
            meanNextReadiness: 50,
            meanNextFatigue: 8,
            lastUpdated: '2026-10-12',
          ),
        ],
        suggestions: const [
          StoredSuggestion(
            weekStart: '2026-10-05',
            exerciseId: 1,
            exerciseName: 'Bench press',
            workingWeightKg: 80,
            repsCsv: '7,7',
            repLow: 8,
            repHigh: 12,
            action: 'keep',
            suggestedWeightKg: 80,
            aimReps: 8,
            card: 'Bench: 80 kg x 7,7 -> keep 80, aim 8s',
          ),
        ],
        readinessByDay: const {'2026-10-07': 62},
        fatigueByDay: const {'2026-10-07': 4},
      ),
    );

    final json = jsonDecode(files.json) as Map<String, dynamic>;
    expect(json['schema'], 'fitness-summary-v1');
    expect(json['sessions'], hasLength(1));
    expect(json['checkins'], hasLength(2));
    expect(json['overload_suggestions'][0]['card'], contains('keep 80, aim 8s'));
    expect(json['warnings'][0]['next_day_readiness'], 62);
    expect(files.markdown, contains('Bench: 80 kg x 7,7 -> keep 80, aim 8s'));
    expect(files.markdown, contains('fitness-summary-v1'));
    expect(files.markdown, contains('Morning'));
    expect(files.json, contains('session_feel'));
  });
}
