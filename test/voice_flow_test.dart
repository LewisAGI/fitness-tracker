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
    expect(VoiceEndWord.endsLog('nearly done'), isFalse);
    expect(VoiceEndWord.endsLog('not quite done'), isFalse);
    expect(VoiceEndWord.endsLog('not  done'), isFalse);
    expect(VoiceEndWord.endsLog('all done'), isTrue);
    expect(VoiceEndWord.endsLog('done'), isTrue);
    expect(VoiceEndWord.endsLog("I'm done"), isTrue);
    expect(VoiceEndWord.strip("Bench press I'm done"), 'Bench press');
    expect(VoiceEndWord.strip('Squats done.'), 'Squats');
    expect(VoiceEndWord.strip('Bench all done'), 'Bench');
    expect(VoiceEndWord.strip("Bench I'm finished"), 'Bench');
    expect(VoiceEndWord.strip("Bench I am that's it"), 'Bench');
    expect(VoiceEndWord.strip("I'm all done"), '');
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
    flow.onSpeech('nearly done', isFinal: true);
    flow.onSpeech('not quite done', isFinal: true);
    flow.onSpeech('not  done', isFinal: true);
    flow.onSpeech('done', isFinal: false);
    flow.onSpeech('done three sets of bench', isFinal: true);
    expect(stops, 0);
    expect(confirms, isEmpty);
  });

  test("that's it, thats it and finished end only the final result", () {
    expect(VoiceEndWord.endsLog("bench that's it"), isTrue);
    expect(VoiceEndWord.endsLog('bench thats it'), isTrue);
    expect(VoiceEndWord.endsLog('bench finished'), isTrue);
    expect(VoiceEndWord.endsLog("that's not it"), isFalse);
    expect(VoiceEndWord.endsLog('not finished'), isFalse);
    expect(VoiceEndWord.endsLog('nearly finished'), isFalse);
    expect(VoiceEndWord.endsLog("that's it then bench"), isFalse);
    expect(VoiceEndWord.endsLog('finished the pads'), isFalse);
    expect(VoiceEndWord.strip("Bench Press that's it"), 'Bench Press');
    expect(VoiceEndWord.strip('Squats finished'), 'Squats');
    expect(VoiceEndWord.endsLog('not done'), isFalse);
    expect(VoiceEndWord.endsLog('not quite done'), isFalse);
    expect(VoiceEndWord.endsLog('not yet finished'), isFalse);
    expect(VoiceEndWord.endsLog('not really done'), isFalse);
    expect(VoiceEndWord.endsLog('not fully done'), isFalse);
    expect(VoiceEndWord.strip('not yet finished'), 'not yet finished');

    final confirms = <String>[];
    var stops = 0;
    final flow = VoiceLogFlow(
      onStop: () => stops++,
      onConfirm: confirms.add,
    );
    flow.onSpeech("Bench press that's it", isFinal: false);
    flow.onSpeech('not finished', isFinal: true);
    flow.onSpeech("that's not it", isFinal: true);
    flow.onSpeech('nearly finished', isFinal: true);
    expect(stops, 0);
    expect(confirms, isEmpty);

    flow.onSpeech("Bench press that's it", isFinal: true);
    expect(stops, 1);
    expect(confirms.single, 'Bench press');

    final again = VoiceLogFlow(onStop: () {}, onConfirm: confirms.add);
    again.onSpeech('Rows finished', isFinal: true);
    expect(confirms.last, 'Rows');
    final parsed = VoiceParser.seeded().parse(confirms.last);
    expect(parsed.normalised, isNot(contains('finished')));
    expect(parsed.sessions.single.raw, 'Rows');
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
