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
  final int year;
  final bool inLibrary;

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
    required this.year,
    required this.inLibrary,
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
    int? year,
    bool? inLibrary,
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
      status: status ?? this.status,
      year: year ?? this.year,
      inLibrary: inLibrary ?? this.inLibrary,
    );
  }

  static GameModel fromRow(Row row) {
    final genresJson = row['genres'] as String;
    final List<String> genresList = List<String>.from(jsonDecode(genresJson));
    
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
    );
  }
}

class GamesDao {
  final Database _db;

  GamesDao(this._db);

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
    _db.execute(
      'INSERT INTO games_table (title, cover_url, genres, summary, rating, hours_played, time_to_beat_hours, status, year, in_library) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        game.title,
        game.coverUrl,
        game.genres,
        game.summary,
        game.rating,
        game.hoursPlayed,
        game.timeToBeatHours,
        game.status,
        game.year,
        game.inLibrary ? 1 : 0,
      ],
    );
    // Get the last inserted id
    final result = _db.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  Future<void> updateGame(GameModel game) async {
    _db.execute(
      'UPDATE games_table SET title = ?, cover_url = ?, genres = ?, summary = ?, rating = ?, '
      'hours_played = ?, time_to_beat_hours = ?, status = ?, year = ?, in_library = ? WHERE id = ?',
      [
        game.title,
        game.coverUrl,
        game.genres,
        game.summary,
        game.rating,
        game.hoursPlayed,
        game.timeToBeatHours,
        game.status,
        game.year,
        game.inLibrary ? 1 : 0,
        game.id,
      ],
    );
  }

  Future<void> deleteGame(int id) async {
    _db.execute('DELETE FROM games_table WHERE id = ?', [id]);
  }

  Future<void> updateGameStatus(int id, String status) async {
    _db.execute('UPDATE games_table SET status = ? WHERE id = ?', [status, id]);
  }

  Future<void> clearAllGames() async {
    _db.execute('DELETE FROM games_table');
  }
}

