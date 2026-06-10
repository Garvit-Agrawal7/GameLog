import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mock/mock_data.dart';
import 'database/app_database.dart';
import 'database/dao/games_dao.dart';
import 'igdb_service.dart';

// Async notifier for managing library games with database persistence
class GameLibraryNotifier extends AsyncNotifier<List<MockGame>> {
  late AppDatabase _database;

  Future<List<MockGame>> _loadLibraryFromDb() async {
    final gameModels = await _database.gamesDao.getAllGames();
    return gameModels.map(_convertToMockGame).toList();
  }

  @override
  Future<List<MockGame>> build() async {
    _database = AppDatabase();
    await _database.init();
    return _loadLibraryFromDb();
  }

  // Add a game to library with status
  Future<void> addToLibrary(MockGame game, {required String status, int? userRating}) async {
    final timeToBeatHours = game.timeToBeatHours ?? await IgdbService().fetchHastilyTimeToBeatHours(game.id);
    final gameToPersist = game.copyWith(timeToBeatHours: timeToBeatHours);

    // Persist to database first with current timestamp
    final gameModel = _convertToGameModel(gameToPersist);
    final updatedModel = gameModel.copyWith(
      inLibrary: true,
      status: status,
      userRating: userRating,
    );
    
    final existing = await _database.gamesDao.getGameById(gameToPersist.id);

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
    // Persist to database
    await _database.gamesDao.updateGameStatus(gameId, newStatus);

    // Reload after write so the UI state always reflects the DB
    state = AsyncValue.data(await _loadLibraryFromDb());
  }

  MockGame _convertToMockGame(GameModel model) {
    return MockGame(
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

  GameModel _convertToGameModel(MockGame game, {String? lastUpdated}) {
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
    AsyncNotifierProvider<GameLibraryNotifier, List<MockGame>>(() {
  return GameLibraryNotifier();
});

// Selector providers for convenience
final libraryGamesProvider = Provider((ref) {
  final gamesAsync = ref.watch(gameLibraryProvider);
  return gamesAsync.whenData((games) => games.where((g) => g.inLibrary).toList()).value ?? [];
});

final gamesByStatusProvider = Provider.family<List<MockGame>, String>((ref, status) {
  final gamesAsync = ref.watch(gameLibraryProvider);
  return gamesAsync
      .whenData((games) => games.where((g) => g.status == status && g.inLibrary).toList())
      .value ?? [];
});

final gameProvider = Provider.family<MockGame?, int>((ref, gameId) {
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
final recentlyCompletedProvider = Provider<List<MockGame>>((ref) {
  final gamesAsync = ref.watch(gameLibraryProvider);
  return gamesAsync
      .whenData((games) {
        final completed = games
            .where((g) =>
                g.status == 'completed' &&
                g.inLibrary &&
                (g.userRating ?? 0) >= 7)
            .toList();
        // Sort by lastUpdated descending (most recent first)
        completed.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        return completed.take(4).toList();
      })
      .value ??
      [];
});

