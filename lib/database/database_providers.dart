import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'daos/games_dao.dart';

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

