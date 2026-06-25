import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_database.dart';
import 'services/igdb_service.dart';
import 'main_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final token = await IgdbService.fetchAccessToken();

  final database = AppDatabase();
  await database.init();

  runApp(MyGameListApp(igdbToken: token));
}

class MyGameListApp extends StatelessWidget {
  const MyGameListApp({super.key, required this.igdbToken});

  final String igdbToken;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [igdbAccessTokenProvider.overrideWithValue(igdbToken)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'GameLog',
        theme: darkTheme,
        home: const MainShell(),
      ),
    );
  }
}
