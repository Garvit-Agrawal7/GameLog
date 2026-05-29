import 'package:my_game_list/mock/mock_data.dart';
import 'daos/games_dao.dart';

class GameConverter {
  static GameModel fromMockGame(MockGame mockGame) {
    return GameModel(
      id: mockGame.id,
      title: mockGame.title,
      coverUrl: mockGame.coverUrl,
      genres: mockGame.genres,
      summary: mockGame.summary,
      rating: mockGame.rating,
      hoursPlayed: mockGame.hoursPlayed,
      timeToBeatHours: mockGame.timeToBeatHours,
      status: mockGame.status,
      year: mockGame.year,
      inLibrary: mockGame.inLibrary,
    );
  }

  static List<GameModel> fromMockGamesList(List<MockGame> mockGames) {
    return mockGames.map((game) => fromMockGame(game)).toList();
  }
}

