import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game_modal.dart';
import 'database/app_database.dart';
import 'database/dao/games_dao.dart';
import 'services/auth_service.dart';
import 'services/dio_service.dart';

class GameLibraryNotifier extends AsyncNotifier<List<GameModal>> {

  late AppDatabase _database;

  Future<List<GameModal>> _loadLibraryFromDb() async {
    final gameModels = await _database.gamesDao.getAllGames();
    return gameModels.map(_toGameModal).toList();
  }

  List<GameModel> _libraryOnlyGames(List<GameModel> games) {
    return games.where((game) => game.inLibrary && game.id != null).toList();
  }

  String? _resolveUserId() {
    final authState = ref.read(authProvider);
    if (authState.userUuid != null && authState.userUuid!.trim().isNotEmpty) {
      return authState.userUuid!.trim();
    }

    return _database.getStoredUserUuid();
  }

  Map<String, dynamic> _toLibraryGamePayload(GameModel model) {
    return {
      'game_id': model.id,
      'title': model.title,
      'cover_url': model.coverUrl,
      'genres': model.genres,
      'summary': model.summary,
      'rating': model.rating,
      'hours_played': model.hoursPlayed,
      'time_to_beat_hours': model.timeToBeatHours,
      'status': model.status,
      'user_rating': model.userRating,
      'year': model.year,
      'in_library': model.inLibrary,
      'last_updated': model.lastUpdated,
    };
  }

  Future<void> _syncLibraryToServer() async {
    final userId = _resolveUserId();
    if (userId == null) return;

    final dio = ref.read(dioService);
    final allGames = await _database.gamesDao.getAllGames();
    final payload = _libraryOnlyGames(allGames).map(_toLibraryGamePayload).toList();

    await dio.put(
      '/database/users/$userId/library',
      data: payload,
    );
  }

  Future<void> _syncLibraryFromServer({
    required String userId,
    required String accessToken,
  }) async {
    final auth = ref.read(authServiceProvider);
    final remoteGames = await auth.fetchLibrary(
      userId: userId,
      accessToken: accessToken,
    );

    await _database.gamesDao.clearAllGames();

    for (final remoteGame in remoteGames) {
      await _database.gamesDao.insertGame(
        GameModel(
          id: remoteGame.id,
          title: remoteGame.title,
          coverUrl: remoteGame.coverUrl,
          genres: remoteGame.genres,
          summary: remoteGame.summary,
          rating: remoteGame.rating,
          hoursPlayed: remoteGame.hoursPlayed,
          timeToBeatHours: remoteGame.timeToBeatHours,
          status: remoteGame.status,
          userRating: remoteGame.userRating,
          year: remoteGame.year,
          inLibrary: remoteGame.inLibrary,
          lastUpdated: remoteGame.lastUpdated,
        ),
      );
    }
  }

  @override
  Future<List<GameModal>> build() async {
    _database = AppDatabase();
    await _database.init();
    final authState = ref.watch(authProvider);
    final storedUserUuid = _database.getStoredUserUuid();
    final userId = authState.userUuid ?? storedUserUuid;

    if (storedUserUuid != null && authState.userUuid == null) {
      ref.read(authProvider.notifier).setUserUuid(storedUserUuid);
    }

    final accessToken = authState.accessToken;
    if (userId != null &&
        userId.trim().isNotEmpty &&
        accessToken != null &&
        accessToken.trim().isNotEmpty &&
        authState.status == AuthStatus.authenticated) {
      await _syncLibraryFromServer(
        userId: userId.trim(),
        accessToken: accessToken.trim(),
      );
    }

    return _loadLibraryFromDb();
  }

  Future<void> addToLibrary(
      GameModal game, {
        required String status,
        int? userRating,
      }) async {
    final gameModel = _toGameModel(game);
    final updatedModel = gameModel.copyWith(
      inLibrary: true,
      status: status,
      userRating: userRating,
      lastUpdated: DateTime.now().toIso8601String(),
    );

    final existing = await _database.gamesDao.getGameById(game.id);

    if (existing != null) {
      await _database.gamesDao.updateGame(updatedModel);
    } else {
      await _database.gamesDao.insertGame(updatedModel);
    }

    try {
      await _syncLibraryToServer();
    } catch (e, st) {
      state = AsyncValue.data(await _loadLibraryFromDb());
      Error.throwWithStackTrace(e, st);
    }

    state = AsyncValue.data(await _loadLibraryFromDb());
  }

  Future<void> removeFromLibrary(int gameId) async {
    await _database.gamesDao.deleteGame(gameId);
    try {
      await _syncLibraryToServer();
    } catch (e, st) {
      state = AsyncValue.data(await _loadLibraryFromDb());
      Error.throwWithStackTrace(e, st);
    }

    state = AsyncValue.data(await _loadLibraryFromDb());
  }

  Future<void> updateGameStatus(int gameId, String newStatus) async {
    await _database.gamesDao.updateGameStatus(gameId, newStatus);
    try {
      await _syncLibraryToServer();
    } catch (e, st) {
      state = AsyncValue.data(await _loadLibraryFromDb());
      Error.throwWithStackTrace(e, st);
    }

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

final gameLibraryProvider =
AsyncNotifierProvider<GameLibraryNotifier, List<GameModal>>(() {
  return GameLibraryNotifier();
});

final libraryGamesProvider = Provider((ref) {
  final gamesAsync = ref.watch(gameLibraryProvider);
  return gamesAsync
      .whenData((games) => games.where((g) => g.inLibrary).toList())
      .value ??
      [];
});

final gamesByStatusProvider =
Provider.family<List<GameModal>, String>((ref, status) {
  final gamesAsync = ref.watch(gameLibraryProvider);
  return gamesAsync
      .whenData((games) => games
      .where((g) => g.status == status && g.inLibrary)
      .toList())
      .value ??
      [];
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

final recentlyCompletedProvider = Provider<List<GameModal>>((ref) {
  final gamesAsync = ref.watch(gameLibraryProvider);
  return gamesAsync
      .whenData((games) {
    final completed =
    games.where((g) => g.status == 'completed' && g.inLibrary).toList();
    completed.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return completed.take(4).toList();
  })
      .value ??
      [];
});

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
