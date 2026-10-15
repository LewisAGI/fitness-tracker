import 'package:fitness_tracker/services/checkin_parser.dart';
import 'package:fitness_tracker/services/checkin_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingNotifications implements NotificationPort {
  final List<String> calls = [];
  final List<ScheduledSlot> active = [];

  @override
  Future<void> cancel(int id) async {
    calls.add('cancel:$id');
    active.removeWhere((slot) => slot.id == id);
  }

  @override
  Future<void> scheduleDaily(ScheduledSlot slot) async {
    calls.add('schedule:${slot.id}:${slot.hour}:${slot.minute}:${slot.payload}');
    active.removeWhere((existing) => existing.id == slot.id);
    active.add(slot);
  }

  @override
  Future<void> requestPermissions() async {
    calls.add('permissions');
  }

  @override
  Future<void> refreshTimezone() async {
    calls.add('timezone');
  }
}

void main() {
  test('defaults schedule morning at 08:00 and evening at 21:00', () async {
    final port = RecordingNotifications();
    final scheduled = await CheckInScheduler(port).reschedule(CheckInSchedule.defaults);
    expect(scheduled.map((slot) => (slot.payload, slot.hour, slot.minute)), [
      ('morning', 8, 0),
      ('evening', 21, 0),
    ]);
    expect(port.calls.take(2), [
      'cancel:${CheckInSchedule.morningId}',
      'cancel:${CheckInSchedule.eveningId}',
    ]);
  });

  test('turning a check-in off cancels it and leaves the other', () async {
    final port = RecordingNotifications();
    final scheduler = CheckInScheduler(port);
    await scheduler.reschedule(CheckInSchedule.defaults);
    port.calls.clear();
    final scheduled = await scheduler.reschedule(
      CheckInSchedule.defaults.copyWith(morningEnabled: false),
    );
    expect(scheduled.map((slot) => slot.payload), ['evening']);
    expect(port.active.map((slot) => slot.payload), ['evening']);
    expect(port.calls, contains('cancel:${CheckInSchedule.morningId}'));
    expect(
      port.calls.where((call) => call.startsWith('schedule:${CheckInSchedule.morningId}')),
      isEmpty,
    );
  });

  test('changing the time cancels and reschedules that check-in', () async {
    final port = RecordingNotifications();
    final scheduler = CheckInScheduler(port);
    await scheduler.reschedule(CheckInSchedule.defaults);
    await scheduler.reschedule(
      CheckInSchedule.defaults.copyWith(eveningHour: 20, eveningMinute: 30),
    );
    final evening = port.active.singleWhere(
      (slot) => slot.id == CheckInSchedule.eveningId,
    );
    expect(evening.hour, 20);
    expect(evening.minute, 30);
    expect(
      port.calls,
      contains('schedule:${CheckInSchedule.eveningId}:20:30:evening'),
    );
  });

  test('resume refreshes the timezone and reschedules', () async {
    final port = RecordingNotifications();
    final scheduler = CheckInScheduler(port);
    await scheduler.onResume(CheckInSchedule.defaults);
    expect(port.calls.first, 'timezone');
    expect(port.calls, contains('schedule:${CheckInSchedule.morningId}:8:0:morning'));
    expect(port.calls, contains('schedule:${CheckInSchedule.eveningId}:21:0:evening'));
  });

  test('turning a check-in back on schedules it again', () async {
    final port = RecordingNotifications();
    final scheduler = CheckInScheduler(port);
    await scheduler.reschedule(
      CheckInSchedule.defaults.copyWith(eveningEnabled: false),
    );
    await scheduler.reschedule(CheckInSchedule.defaults);
    expect(port.active.map((slot) => slot.payload), ['morning', 'evening']);
  });

  test('morning voice check-in reads readiness fields', () {
    final parsed = parseCheckIn(
      'sore 6, energy 4, slept 7 hours, sleep quality 8, mood 5, stress 3',
    );
    expect(parsed.soreness, 6);
    expect(parsed.energy, 4);
    expect(parsed.sleepHours, 7);
    expect(parsed.sleepQuality, 8);
    expect(parsed.mood, 5);
    expect(parsed.stress, 3);
  });

  test('evening voice check-in reads the day', () {
    final parsed = parseCheckIn('session feel 7, ate 8, stress 4, energy 6 done');
    expect(parsed.sessionFeel, 7);
    expect(parsed.ateWell, 8);
    expect(parsed.stress, 4);
    expect(parsed.energy, 6);
    expect(parsed.normalised.toLowerCase(), isNot(contains('done')));
  });
}
