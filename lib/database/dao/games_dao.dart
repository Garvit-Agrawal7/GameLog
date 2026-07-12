import 'package:sqlite3/sqlite3.dart';
import 'dart:convert';

class GameModel {
  final int? id;
  final String title;
  final String coverUrl;
  final List<String> genres;
  final String summary;
  final double rating;
  final int hoursPlayed;
  final int? timeToBeatHours;
  final String? status;
  final int? userRating;
  final int year;
  final bool inLibrary;
  final String lastUpdated;

  GameModel({
    this.id,
    required this.title,
    required this.coverUrl,
    required this.genres,
    required this.summary,
    required this.rating,
    required this.hoursPlayed,
    this.timeToBeatHours,
    this.status,
    this.userRating,
    required this.year,
    required this.inLibrary,
    required this.lastUpdated,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'cover_url': coverUrl,
      'genres': jsonEncode(genres),
      'summary': summary,
      'rating': rating,
      'hours_played': hoursPlayed,
      'time_to_beat_hours': timeToBeatHours,
      'status': status,
      'year': year,
      'in_library': inLibrary ? 1 : 0,
      'last_updated': lastUpdated,
      'user_rating': userRating,
    };
  }

  GameModel copyWith({
    int? id,
    String? title,
    String? coverUrl,
    List<String>? genres,
    String? summary,
    double? rating,
    int? hoursPlayed,
    int? timeToBeatHours,
    String? status,
    bool statusIsNull = false,
    int? year,
    int? userRating,
    bool? inLibrary,
    String? lastUpdated,
  }) {
    return GameModel(
      id: id ?? this.id,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      genres: genres ?? this.genres,
      summary: summary ?? this.summary,
      rating: rating ?? this.rating,
      hoursPlayed: hoursPlayed ?? this.hoursPlayed,
      timeToBeatHours: timeToBeatHours ?? this.timeToBeatHours,
      status: statusIsNull ? null : (status ?? this.status),
      year: year ?? this.year,
      userRating: userRating ?? this.userRating,
      inLibrary: inLibrary ?? this.inLibrary,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static GameModel fromRow(Row row) {
    final genresJson = row['genres'] as String;
    final List<String> genresList = List<String>.from(jsonDecode(genresJson));
    final rawLastUpdated = row['last_updated'];
    final rawUserRating = row['user_rating'];

    return GameModel(
      id: row['id'] as int?,
      title: row['title'] as String,
      coverUrl: row['cover_url'] as String,
      genres: genresList,
      summary: row['summary'] as String,
      rating: row['rating'] as double,
      hoursPlayed: row['hours_played'] as int,
      timeToBeatHours: row['time_to_beat_hours'] as int?,
      status: row['status'] as String?,
      year: row['year'] as int,
      inLibrary: (row['in_library'] as int) == 1,
      userRating: rawUserRating is int ? rawUserRating : (rawUserRating is num ? rawUserRating.toInt() : null),
      lastUpdated: (rawLastUpdated is String && rawLastUpdated.isNotEmpty)
          ? rawLastUpdated
          : DateTime.now().toIso8601String(),
    );
  }
}

class GamesDao {
  final Database _db;

  GamesDao(this._db);

  void _ensureUserRatingColumnExists() {
    final pragma = _db.select('PRAGMA table_info(games_table)');
    final hasUserRating = pragma.any((col) => (col['name'] as String) == 'user_rating');
    if (!hasUserRating) {
      try {
        _db.execute('ALTER TABLE games_table ADD COLUMN user_rating INTEGER');
      } catch (_) {
        // Column already exists
      }
    }
  }

  Future<int> getPlayingCount() async {
    final total = _db.select(
        'SELECT COUNT(*) as count FROM games_table WHERE status = ?',
        ['playing']
    );
    final count =  total.first['count'] as int;
    return count.toInt();
  }

  Future<int> getCompletedCount() async {
    final result = _db.select(
      'SELECT COUNT(*) as count FROM games_table WHERE status = ?',
      ['completed'],
    );
    return result.first['count'] as int;
  }

  Future<int> getHoursPlayed() async {
    final hoursPlayed = _db.select(
      'SELECT COALESCE(SUM(CASE '
      'WHEN hours_played > 0 THEN hours_played '
      'WHEN status = \'completed\' THEN COALESCE(time_to_beat_hours, 0) '
      'ELSE 0 '
      'END), 0) as total '
      'FROM games_table',
    );

    final hoursPlayedTotal = hoursPlayed.first['total'];

    return hoursPlayedTotal.toInt();
  }

  Future<double> getAverageRating() async {
    final result = _db.select(
      'SELECT COALESCE(SUM(rating), 0) as total_rating, COUNT(*) as completed_count '
      'FROM games_table '
      'WHERE in_library = 1 AND rating > 0 AND status = ?',
      ['completed'],
    );
    final row = result.first;
    final totalRating = row['total_rating'];
    final completedCount = row['completed_count'];

    if (totalRating is num && completedCount is num && completedCount > 0) {
      return (totalRating.toDouble() / completedCount.toDouble()) / 10;
    }

    return 0.0;
  }

  Future<List<GameModel>> getAllGames() async {
    final rows = _db.select('SELECT * FROM games_table ORDER BY title ASC');
    return rows.map((row) => GameModel.fromRow(row)).toList();
  }

  Future<List<GameModel>> getGamesByStatus(String status) async {
    final rows = _db.select(
      'SELECT * FROM games_table WHERE status = ? ORDER BY title ASC',
      [status],
    );
    return rows.map((row) => GameModel.fromRow(row)).toList();
  }

  Future<GameModel?> getGameById(int id) async {
    final rows = _db.select(
      'SELECT * FROM games_table WHERE id = ?',
      [id],
    );
    return rows.isEmpty ? null : GameModel.fromRow(rows.first);
  }

  Future<int> insertGame(GameModel game) async {
    _ensureUserRatingColumnExists();
    _db.execute(
      'INSERT OR REPLACE INTO games_table (id, title, cover_url, genres, summary, rating, hours_played, time_to_beat_hours, status, year, in_library, last_updated, user_rating) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        game.id,
        game.title,
        game.coverUrl,
        jsonEncode(game.genres),
        game.summary,
        game.rating,
        game.hoursPlayed,
        game.timeToBeatHours,
        game.status,
        game.year,
        game.inLibrary ? 1 : 0,
        game.lastUpdated,
        game.userRating,
      ],
    );
    // Get the last inserted id
    final result = _db.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  Future<void> updateGame(GameModel game) async {
    _ensureUserRatingColumnExists();
    _db.execute(
      'UPDATE games_table SET title = ?, cover_url = ?, genres = ?, summary = ?, rating = ?, '
          'hours_played = ?, time_to_beat_hours = ?, status = ?, year = ?, in_library = ?, last_updated = ?, user_rating = ? WHERE id = ?',
      [
        game.title,
        game.coverUrl,
        jsonEncode(game.genres),
        game.summary,
        game.rating,
        game.hoursPlayed,
        game.timeToBeatHours,
        game.status,
        game.year,
        game.inLibrary ? 1 : 0,
        game.lastUpdated,
        game.userRating,
        game.id,
      ],
    );
  }

  Future<void> deleteGame(int id) async {
    _db.execute('DELETE FROM games_table WHERE id = ?', [id]);
  }

  Future<void> updateGameStatus(int id, String status) async {
    _db.execute(
      'UPDATE games_table SET status = ?, last_updated = ? WHERE id = ?',
      [status, DateTime.now().toIso8601String(), id],
    );
  }

  Future<void> clearAllGames() async {
    _db.execute('DELETE FROM games_table');
  }

  Future<String?> getTopGenre() async {
    final rows = _db.select('SELECT genres FROM games_table WHERE in_library = 1');
    
    final genreCount = <String, int>{};
    
    for (final row in rows) {
      final genresJson = row['genres'] as String;
      try {
        final List<String> genresList = List<String>.from(jsonDecode(genresJson));
        for (final genre in genresList) {
          genreCount[genre] = (genreCount[genre] ?? 0) + 1;
        }
      } catch (_) {}
    }
    
    final sortedGenres = genreCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedGenres.isEmpty ? null : sortedGenres.first.key;
  }
}
