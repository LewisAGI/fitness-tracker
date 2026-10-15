import 'dart:io';

import 'package:fitness_tracker/data/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v1 databases gain rir, nullable block time and round minutes', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('fitness-upgrade');
    final path = '${directory.path}/legacy.db';
    final legacy = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, type TEXT NOT NULL)',
        );
        await db.execute('''
          CREATE TABLE sets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            reps INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE session_blocks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            subtype TEXT NOT NULL,
            duration_min INTEGER NOT NULL,
            rpe INTEGER NOT NULL,
            load REAL NOT NULL
          )
        ''');
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        final sessionId = await db.insert('sessions', {
          'date': '2026-10-12',
          'type': 'muay_thai',
        });
        await db.insert('session_blocks', {
          'session_id': sessionId,
          'subtype': 'pads',
          'duration_min': 20,
          'rpe': 7,
          'load': 140,
        });
      },
    );
    await legacy.close();

    final upgraded = await openFitnessDatabase(path: path);
    final columns = await upgraded.rawQuery('PRAGMA table_info(sets)');
    expect(columns.any((column) => column['name'] == 'rir'), isTrue);
    await upgraded.insert('sets', {'session_id': 1, 'reps': 8, 'rir': 2});
    final set = await upgraded.query('sets');
    expect(set.single['rir'], 2);

    final blockColumns = await upgraded.rawQuery('PRAGMA table_info(session_blocks)');
    final duration = blockColumns.firstWhere(
      (column) => column['name'] == 'duration_min',
    );
    expect(duration['notnull'], 0);
    await upgraded.insert('session_blocks', {
      'session_id': 1,
      'subtype': 'other',
      'duration_min': null,
      'rpe': 6,
      'load': 0,
      'label': 'Bagwork',
    });
    final blocks = await upgraded.query('session_blocks', orderBy: 'id');
    expect(blocks.first['duration_min'], 20);
    expect(blocks.last['duration_min'], isNull);
    expect(blocks.last['label'], 'Bagwork');

    final setting = await upgraded.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['round_minutes'],
    );
    expect(setting.single['value'], '3');
    await upgraded.close();
  });
}
