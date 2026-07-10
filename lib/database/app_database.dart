import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'dao/games_dao.dart';
import 'dao/search_history_dao.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  late Database _db;
  late GamesDao gamesDao;
  late SearchHistoryDao searchHistoryDao;
  bool _initialized = false;

  factory AppDatabase() {
    return _instance;
  }

  AppDatabase._internal();

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'gamelog.db'));

    _db = sqlite3.open(file.path);
    gamesDao = GamesDao(_db);
    searchHistoryDao = SearchHistoryDao(_db);
    
    // Enable foreign keys and set synchronous mode for data safety
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA synchronous = FULL');
    
    await _createTables();
    _initialized = true;
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
        in_library INTEGER NOT NULL DEFAULT 1,
        last_updated TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        user_rating INTEGER
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS search_history_table (
        query TEXT PRIMARY KEY COLLATE NOCASE,
        last_searched TEXT NOT NULL
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS auth_state_table (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_uuid TEXT,
        access_token TEXT
      )
    ''');

      await _migrateSchema();
  }
  
  Future<void> _migrateSchema() async {
    try {
      // Check existing table columns and add any new optional columns.
      final pragma = _db.select('PRAGMA table_info(games_table)');
      final columnNames = pragma.map((col) => col['name'] as String).toSet();

      if (!columnNames.contains('last_updated')) {
        _db.execute('ALTER TABLE games_table ADD COLUMN last_updated TEXT');
        _db.execute(
          'UPDATE games_table SET last_updated = CURRENT_TIMESTAMP WHERE last_updated IS NULL OR last_updated = ""'
        );
      } else {
        // Ensure older rows have a timestamp
        _db.execute(
          'UPDATE games_table SET last_updated = CURRENT_TIMESTAMP WHERE last_updated IS NULL OR last_updated = ""'
        );
      }

      if (!columnNames.contains('user_rating')) {
        _db.execute('ALTER TABLE games_table ADD COLUMN user_rating INTEGER');
        // Existing rows will have NULL for user_rating which is acceptable
      }
    } catch (e) {}
  }


  Database get database => _db;

  String? getStoredUserUuid() {
    final rows = _db.select('SELECT user_uuid FROM auth_state_table WHERE id = 1');
    if (rows.isEmpty) return null;
    final value = rows.first['user_uuid'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  Future<void> close() async {
    _db.close();
  }
}
