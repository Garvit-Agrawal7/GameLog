import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_library_provider.dart';
import 'app_database.dart';
import 'dao/games_dao.dart';

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final database = AppDatabase();
  await database.init();
  return database;
});

final gamesProvider = FutureProvider<List<GameModel>>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return database.gamesDao.getAllGames();
});

final gamesByStatusProvider =
    FutureProvider.family<List<GameModel>, String>((ref, status) async {
  final database = await ref.watch(databaseProvider.future);
  return database.gamesDao.getGamesByStatus(status);
});

final searchHistoryProvider = FutureProvider<List<String>>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return database.searchHistoryDao.getRecentSearches(limit: 8);
});

class LibraryStats {
  final int playingCount;
  final int completedCount;
  final int totalHours;
  final double averageRating;

  LibraryStats({
    required this.playingCount,
    required this.completedCount,
    required this.totalHours,
    required this.averageRating,
  });

  factory LibraryStats.empty() => LibraryStats(
    playingCount: 0,
    completedCount: 0,
    totalHours: 0,
    averageRating: 0.0,
  );
}

final libraryStatsProvider = FutureProvider<LibraryStats>((ref) async {
  // Watch gameLibraryProvider to refresh stats when library changes
  ref.watch(gameLibraryProvider);

  final database = await ref.watch(databaseProvider.future);
  final dao = database.gamesDao;

  final results = await Future.wait([
    dao.getPlayingCount(),
    dao.getCompletedCount(),
    dao.getHoursPlayed(),
    dao.getAverageRating(),
  ]);

  return LibraryStats(
    playingCount: results[0] as int,
    completedCount: results[1] as int,
    totalHours: results[2] as int,
    averageRating: results[3] as double,
  );
});
