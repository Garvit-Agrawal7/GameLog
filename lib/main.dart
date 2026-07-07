import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';

import 'database/app_database.dart';
import 'main_shell.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';

const String _backendBaseUrl = 'http://192.168.1.4:8000';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  await database.init();

  final container = ProviderContainer();

  _initDeepLinkListener(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GameLogApp(),
    ),
  );
}

void _initDeepLinkListener(ProviderContainer container) {
  final appLinks = AppLinks();

  appLinks.uriLinkStream.listen((uri) async {
    if (uri.scheme == 'gamelog' && uri.host == 'auth' && uri.path == '/complete') {
      final fragment = uri.fragment;
      if (!fragment.startsWith('session=')) return;

      final sessionToken = fragment.replaceFirst('session=', '');
      await _fetchSteamData(container, sessionToken);
    }
  });
}

Future<void> _fetchSteamData(ProviderContainer container, String sessionToken) async {
  final dio = Dio();
  try {
    final response = await dio.get('$_backendBaseUrl/auth/session/$sessionToken');
    container.read(authProvider.notifier).setPayload(response.data);
  } catch (e) {
    container.read(authProvider.notifier).setError(e.toString());
  }
}

class GameLogApp extends StatelessWidget {
  const GameLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GameLog',
      theme: darkTheme,
      home: const MainShell(),
    );
  }
}
