import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_database.dart';
import 'main_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  print('CLIENT_ID: ${dotenv.env['CLIENT_ID']}');

  final database = AppDatabase();
  await database.init();

  runApp(const MyGameListApp());
}

class MyGameListApp extends StatelessWidget {
  const MyGameListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Game Dex',
        theme: darkTheme,
        home: const MainShell(),
      ),
    );
  }
}
