import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game_modal.dart';
import 'database/app_database.dart';
import 'database/dao/games_dao.dart';

// Async notifier for managing library games with database persistence
class GameLibraryNotifier extends AsyncNotifier<List<GameModal>> {
  late AppDatabase _database;

  Future<List<GameModal>> _loadLibraryFromDb() async {
    final gameModels = await _database.gamesDao.getAllGames();
    return gameModels.map(_toGameModal).toList();
  }

  @override
  Future<List<GameModal>> build() async {
    _database = AppDatabase();
    await _database.init();
    return _loadLibraryFromDb();
  }

  // Add a game to library with status
  Future<void> addToLibrary(GameModal game, {required String status, int? userRating}) async {
    final gameModel = _toGameModel(game);
    final updatedModel = gameModel.copyWith(
      inLibrary: true,
      status: status,
      userRating: userRating,
    );
    
    final existing = await _database.gamesDao.getGameById(game.id);

    if (existing != null) {
      await _database.gamesDao.updateGame(updatedModel);
    } else {
      await _database.gamesDao.insertGame(updatedModel);
    }

    // Reload the library so Riverpod state matches the database
    state = AsyncValue.data(await _loadLibraryFromDb());
  }

  // Remove a game from library
  Future<void> removeFromLibrary(int gameId) async {
    // Delete the row from the database
    await _database.gamesDao.deleteGame(gameId);

    // Reload the library so the removed game is disappears from UI
    final refreshed = await _loadLibraryFromDb();
    state = AsyncValue.data(refreshed);
  }

  // Update a game's status
  Future<void> updateGameStatus(int gameId, String newStatus) async {
    await _database.gamesDao.updateGameStatus(gameId, newStatus);
    state = AsyncValue.data(await _loadLibraryFromDb());
  }

  GameModal _toGameModal(GameModel model) {
    return GameModal(
      id: model.id ?? 0,
      title: model.title,
      coverUrl: model.coverUrl,
      genres: model.genres,
      summary: model.summary,
      rating: model.rating,
      hoursPlayed: model.hoursPlayed,
      status: model.status,
      userRating: model.userRating,
      year: model.year,
      inLibrary: model.inLibrary,
      timeToBeatHours: model.timeToBeatHours,
      lastUpdated: model.lastUpdated,
    );
  }

  GameModel _toGameModel(GameModal game, {String? lastUpdated}) {
    return GameModel(
      id: game.id,
      title: game.title,
      coverUrl: game.coverUrl,
      genres: game.genres,
      summary: game.summary,
      rating: game.rating,
      hoursPlayed: game.hoursPlayed,
      status: game.status,
      userRating: game.userRating,
      year: game.year,
      inLibrary: game.inLibrary,
      timeToBeatHours: game.timeToBeatHours,
      lastUpdated: lastUpdated ?? DateTime.now().toIso8601String(),
    );
  }
}

// Global async provider for the game library state
final gameLibraryProvider =
    AsyncNotifierProvider<GameLibraryNotifier, List<GameModal>>(() {
  return GameLibraryNotifier();
});

// Selector providers for convenience
final libraryGamesProvider = Provider((ref) {
  final gamesAsync = ref.watch(gameLibraryProvider);
  return gamesAsync.whenData((games) => games.where((g) => g.inLibrary).toList()).value ?? [];
});

final gamesByStatusProvider = Provider.family<List<GameModal>, String>((ref, status) {
  final gamesAsync = ref.watch(gameLibraryProvider);
  return gamesAsync
      .whenData((games) => games.where((g) => g.status == status && g.inLibrary).toList())
      .value ?? [];
});

final gameProvider = Provider.family<GameModal?, int>((ref, gameId) {
  final gamesAsync = ref.watch(gameLibraryProvider);
  return gamesAsync.whenData((games) {
    try {
      return games.firstWhere((g) => g.id == gameId);
    } catch (_) {
      return null;
    }
  }).value;
});

// Provider to get recently completed games (sorted by last_updated)
final recentlyCompletedProvider = Provider<List<GameModal>>((ref) {
  final gamesAsync = ref.watch(gameLibraryProvider);
  return gamesAsync
      .whenData((games) {
        final completed = games
            .where((g) =>
                g.status == 'completed' &&
                g.inLibrary)
            .toList();
        // Sort by lastUpdated descending (most recent first)
        completed.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        return completed.take(4).toList();
      })
      .value ??
      [];
});

// Provider to get top genre from the database
final topGenreProvider = Provider<String?>((ref) {
  final libraryGames = ref.watch(libraryGamesProvider);
  if (libraryGames.isEmpty) return null;

  final genreCount = <String, int>{};
  for (final game in libraryGames) {
    for (final genre in game.genres) {
      genreCount[genre] = (genreCount[genre] ?? 0) + 1;
    }
  }

  final sorted = genreCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.isEmpty ? null : sorted.first.key;
});
