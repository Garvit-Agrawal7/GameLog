import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'daos/games_dao.dart';
import 'game_converter.dart';
import '../mock/mock_data.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  late Database _db;
  late GamesDao gamesDao;

  factory AppDatabase() {
    return _instance;
  }

  AppDatabase._internal();

  Future<void> init() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'my_game_list.db'));

    if (kDebugMode) {
      print('Database path: ${file.path}');
    }

    _db = sqlite3.open(file.path);
    gamesDao = GamesDao(_db);
    await _createTables();
    await _seedDatabaseIfEmpty();
  }

  Future<void> _createTables() async {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS games_table (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        cover_url TEXT NOT NULL,
        genres TEXT NOT NULL,
        summary TEXT NOT NULL,
        rating REAL NOT NULL,
        hours_played INTEGER NOT NULL,
        time_to_beat_hours INTEGER,
        status TEXT,
        year INTEGER NOT NULL,
        in_library INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _seedDatabaseIfEmpty() async {
    try {
      final rows = _db.select('SELECT COUNT(*) as count FROM games_table');
      final count = rows.first['count'] as int;
      
      if (count == 0) {
        if (kDebugMode) {
          print('Database is empty, seeding with mock data...');
        }
        final games = GameConverter.fromMockGamesList(mockGames);
        for (final game in games) {
          await gamesDao.insertGame(game);
        }
        if (kDebugMode) {
          print('Database seeded with ${games.length} games');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error seeding database: $e');
      }
    }
  }

  Database get database => _db;

  Future<void> close() async {
    _db.close();
  }
}

