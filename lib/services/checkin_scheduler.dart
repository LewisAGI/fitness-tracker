class CheckInSchedule {
  const CheckInSchedule({
    required this.morningEnabled,
    required this.morningHour,
    required this.morningMinute,
    required this.eveningEnabled,
    required this.eveningHour,
    required this.eveningMinute,
  });

  static const morningId = 801;
  static const eveningId = 2101;

  final bool morningEnabled;
  final int morningHour;
  final int morningMinute;
  final bool eveningEnabled;
  final int eveningHour;
  final int eveningMinute;

  static const defaults = CheckInSchedule(
    morningEnabled: true,
    morningHour: 8,
    morningMinute: 0,
    eveningEnabled: true,
    eveningHour: 21,
    eveningMinute: 0,
  );

  CheckInSchedule copyWith({
    bool? morningEnabled,
    int? morningHour,
    int? morningMinute,
    bool? eveningEnabled,
    int? eveningHour,
    int? eveningMinute,
  }) {
    return CheckInSchedule(
      morningEnabled: morningEnabled ?? this.morningEnabled,
      morningHour: morningHour ?? this.morningHour,
      morningMinute: morningMinute ?? this.morningMinute,
      eveningEnabled: eveningEnabled ?? this.eveningEnabled,
      eveningHour: eveningHour ?? this.eveningHour,
      eveningMinute: eveningMinute ?? this.eveningMinute,
    );
  }
}

class ScheduledSlot {
  const ScheduledSlot({
    required this.id,
    required this.hour,
    required this.minute,
    required this.title,
    required this.payload,
  });

  final int id;
  final int hour;
  final int minute;
  final String title;
  final String payload;
}

abstract class NotificationPort {
  Future<void> cancel(int id);
  Future<void> scheduleDaily(ScheduledSlot slot);
  Future<void> requestPermissions();
  Future<void> refreshTimezone();
}

class CheckInScheduler {
  CheckInScheduler(this.port);

  final NotificationPort port;

  Future<List<ScheduledSlot>> reschedule(CheckInSchedule schedule) async {
    await port.cancel(CheckInSchedule.morningId);
    await port.cancel(CheckInSchedule.eveningId);
    final scheduled = <ScheduledSlot>[];
    if (schedule.morningEnabled) {
      final slot = ScheduledSlot(
        id: CheckInSchedule.morningId,
        hour: schedule.morningHour,
        minute: schedule.morningMinute,
        title: 'Morning',
        payload: 'morning',
      );
      await port.scheduleDaily(slot);
      scheduled.add(slot);
    }
    if (schedule.eveningEnabled) {
      final slot = ScheduledSlot(
        id: CheckInSchedule.eveningId,
        hour: schedule.eveningHour,
        minute: schedule.eveningMinute,
        title: 'Evening',
        payload: 'evening',
      );
      await port.scheduleDaily(slot);
      scheduled.add(slot);
    }
    return scheduled;
  }

  Future<void> requestPermissions() => port.requestPermissions();

  Future<void> onResume(CheckInSchedule schedule) async {
    await port.refreshTimezone();
    await reschedule(schedule);
  }
}
