import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mock/mock_data.dart';

// Mutable state notifier for managing library games
class GameLibraryNotifier extends StateNotifier<List<MockGame>> {
  GameLibraryNotifier() : super(List.from(mockGames));

  // Add a game to library
  void addToLibrary(MockGame game, {required String status}) {
    final gameIndex = state.indexWhere((g) => g.id == game.id);
    if (gameIndex != -1) {
      // Game exists, update it
      final updatedGame = state[gameIndex].copyWith(
        inLibrary: true,
        status: status,
      );
      state = [
        ...state.sublist(0, gameIndex),
        updatedGame,
        ...state.sublist(gameIndex + 1),
      ];
    } else {
      // New game, add it
      final newGame = game.copyWith(inLibrary: true, status: status);
      state = [...state, newGame];
    }
  }

  // Remove a game from library
  void removeFromLibrary(int gameId) {
    final gameIndex = state.indexWhere((g) => g.id == gameId);
    if (gameIndex != -1) {
      final updatedGame = state[gameIndex].copyWith(inLibrary: false);
      state = [
        ...state.sublist(0, gameIndex),
        updatedGame,
        ...state.sublist(gameIndex + 1),
      ];
    }
  }

  // Update a game's status
  void updateGameStatus(int gameId, String newStatus) {
    final gameIndex = state.indexWhere((g) => g.id == gameId);
    if (gameIndex != -1) {
      final updatedGame = state[gameIndex].copyWith(status: newStatus);
      state = [
        ...state.sublist(0, gameIndex),
        updatedGame,
        ...state.sublist(gameIndex + 1),
      ];
    }
  }

  // Get a specific game
  MockGame? getGame(int gameId) {
    try {
      return state.firstWhere((g) => g.id == gameId);
    } catch (_) {
      return null;
    }
  }

  // Get games by status
  List<MockGame> getGamesByStatus(String status) {
    return state.where((g) => g.status == status && g.inLibrary).toList();
  }

  // Get all library games
  List<MockGame> getLibraryGames() {
    return state.where((g) => g.inLibrary).toList();
  }
}

// Global provider for the game library state
final gameLibraryProvider =
    StateNotifierProvider<GameLibraryNotifier, List<MockGame>>((ref) {
  return GameLibraryNotifier();
});

// Selector providers for convenience
final libraryGamesProvider = Provider((ref) {
  final games = ref.watch(gameLibraryProvider);
  return games.where((g) => g.inLibrary).toList();
});

final gamesByStatusProvider = Provider.family<List<MockGame>, String>((ref, status) {
  final games = ref.watch(gameLibraryProvider);
  return games.where((g) => g.status == status && g.inLibrary).toList();
});

final gameProvider = Provider.family<MockGame?, int>((ref, gameId) {
  final games = ref.watch(gameLibraryProvider);
  try {
    return games.firstWhere((g) => g.id == gameId);
  } catch (_) {
    return null;
  }
});
