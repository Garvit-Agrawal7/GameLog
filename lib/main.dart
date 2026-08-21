import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'database/app_database.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/dio_service.dart';
import 'screens/auth_screen.dart';
import 'screens/reset_password_screen.dart';
import 'main_shell.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  await database.init();

  final container = ProviderContainer();

  const storage = FlutterSecureStorage();
  final storedUserUuid = await storage.read(key: 'user_uuid');
  final storedAccessToken = await storage.read(key: 'access_token');
  if (storedUserUuid != null) {
    container.read(authProvider.notifier).setUserUuid(storedUserUuid);
  }
  if (storedAccessToken != null) {
    container.read(authProvider.notifier).setAccessToken(storedAccessToken);
  }

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

  appLinks.getInitialAppLink().then((uri) {
    if (uri != null) {
      _handleDeepLink(container, uri);
    }
  });

  appLinks.uriLinkStream.listen((uri) async {
    _handleDeepLink(container, uri);
  });
}

Future<void> _handleDeepLink(ProviderContainer container, Uri uri) async {
  if (uri.scheme == 'gamelog' && uri.host == 'auth' && uri.path == '/complete') {
    final fragment = uri.fragment;
    if (!fragment.startsWith('session=')) return;

    final sessionToken = fragment.replaceFirst('session=', '');
    await _fetchProviderData(container, sessionToken);
  }
  if (uri.scheme == 'gamelog' && uri.host == 'reset-password' && uri.path.isEmpty) {
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) return;

    const storage = FlutterSecureStorage();
    final lastConsumedCode = await storage.read(key: 'consumed_reset_code');
    if (lastConsumedCode == code) return;
    await storage.write(key: 'consumed_reset_code', value: code);

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(code: code),
      ),
    );
  }
}

Future<void> _fetchProviderData(ProviderContainer container, String sessionToken) async {
  final dio = container.read(dioService);
  try {
    final response = await dio.get('/auth/session/$sessionToken');
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
      navigatorKey: navigatorKey,
      home: const AppRoot(),
    );
  }
}

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      final hadToken = previous?.accessToken != null && previous!.accessToken!.trim().isNotEmpty;
      final hasToken = next.accessToken != null && next.accessToken!.trim().isNotEmpty;

      if (hadToken && !hasToken) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
              (route) => false,
        );
      }
    });

    final authState = ref.watch(authProvider);
    final isLoggedIn = authState.accessToken != null &&
        authState.accessToken!.trim().isNotEmpty &&
        authState.userUuid != null &&
        authState.userUuid!.trim().isNotEmpty;

    return isLoggedIn ? const MainShell() : const AuthScreen();
  }
}
