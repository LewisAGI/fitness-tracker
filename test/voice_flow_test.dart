import 'package:fitness_tracker/services/voice_end_word.dart';
import 'package:fitness_tracker/services/voice_log_flow.dart';
import 'package:fitness_tracker/services/voice_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('done and I am done are end words only at the end', () {
    expect(VoiceEndWord.endsLog('bench press done'), isTrue);
    expect(VoiceEndWord.endsLog("bench press I'm done"), isTrue);
    expect(VoiceEndWord.endsLog('bench press im done.'), isTrue);
    expect(VoiceEndWord.endsLog('bench press i am done!'), isTrue);
    expect(VoiceEndWord.endsLog('done bench press'), isFalse);
    expect(VoiceEndWord.endsLog('abandoned the set'), isFalse);
    expect(VoiceEndWord.endsLog("I'm not done"), isFalse);
    expect(VoiceEndWord.endsLog('well done'), isFalse);
    expect(VoiceEndWord.endsLog('never done'), isFalse);
    expect(VoiceEndWord.endsLog('almost done'), isFalse);
    expect(VoiceEndWord.endsLog('all done'), isFalse);
    expect(VoiceEndWord.endsLog('not  done'), isFalse);
    expect(VoiceEndWord.strip("bench press I'm done").toLowerCase(), 'bench press');
    expect(VoiceEndWord.strip('squats done.').toLowerCase(), 'squats');
  });

  test('saying done stops listening and opens confirm without the word', () {
    final confirms = <String>[];
    var stops = 0;
    final flow = VoiceLogFlow(
      onStop: () => stops++,
      onConfirm: confirms.add,
    );

    flow.onSpeech('bench press 4 sets of 8 at 70');
    expect(stops, 0);
    expect(confirms, isEmpty);

    flow.onSpeech("bench press 4 sets of 8 at 70 I'm done", isFinal: true);
    expect(stops, 1);
    expect(confirms, hasLength(1));
    expect(confirms.single.toLowerCase(), isNot(contains('done')));
    expect(confirms.single.toLowerCase(), contains('bench press'));

    flow.onSpeech('ignored after close');
    flow.onRelease('bench press again');
    expect(stops, 1);
    expect(confirms, hasLength(1));
  });

  test('release without done still confirms and strips a trailing done', () {
    final confirms = <String>[];
    final flow = VoiceLogFlow(onStop: () {}, onConfirm: confirms.add);
    flow.onRelease('ran 5k in 28 minutes done');
    final parsed = VoiceParser.seeded().parse(confirms.single);
    expect(parsed.sessions.single.distanceKm, 5);
    expect(parsed.sessions.single.durationMin, 28);
    expect(parsed.normalised, isNot(contains('done')));
  });

  test("I'm not done and well done do not end the log", () {
    final confirms = <String>[];
    var stops = 0;
    final flow = VoiceLogFlow(
      onStop: () => stops++,
      onConfirm: confirms.add,
    );
    flow.onSpeech("I'm not done", isFinal: true);
    flow.onSpeech('well done', isFinal: true);
    flow.onSpeech('never done', isFinal: true);
    flow.onSpeech('almost done', isFinal: true);
    flow.onSpeech('all done', isFinal: true);
    flow.onSpeech('not  done', isFinal: true);
    flow.onSpeech('done', isFinal: false);
    flow.onSpeech('done three sets of bench', isFinal: true);
    expect(stops, 0);
    expect(confirms, isEmpty);
  });

  test('empty release stops without a confirm card', () {
    var confirms = 0;
    var stops = 0;
    final flow = VoiceLogFlow(
      onStop: () => stops++,
      onConfirm: (_) => confirms++,
    );
    flow.onRelease('   ');
    expect(stops, 1);
    expect(confirms, 0);
  });
}
