import 'package:sqlite3/sqlite3.dart';

class SearchHistoryDao {
  final Database _db;

  SearchHistoryDao(this._db);

  Future<List<String>> getRecentSearches({int limit = 10}) async {
    final rows = _db.select(
      'SELECT query FROM search_history_table ORDER BY last_searched DESC LIMIT ?',
      [limit],
    );
    return rows
        .map((row) => row['query'] as String)
        .where((query) => query.trim().isNotEmpty)
        .toList();
  }

  Future<void> saveSearchQuery(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return;
    }

    _db.execute(
      'INSERT INTO search_history_table (query, last_searched) VALUES (?, ?) '
      'ON CONFLICT(query) DO UPDATE SET last_searched = excluded.last_searched',
      [normalized, DateTime.now().toIso8601String()],
    );
  }

  Future<void> clearSearchHistory() async {
    _db.execute('DELETE FROM search_history_table');
  }
}
