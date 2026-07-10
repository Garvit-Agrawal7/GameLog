import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dio_service.dart';

enum AuthStatus {
  anonymous,
  pendingVerification,
  authenticated,
  invalid,
}

class AuthUser {
  final String id;
  final String? email;
  final Map<String, dynamic> raw;

  const AuthUser({
    required this.id,
    required this.raw,
    this.email,
  });
}

class AuthState {
  final Map<String, dynamic>? payload;
  final AuthStatus status;
  final String? accessToken;
  final AuthUser? user;
  final String? error;

  const AuthState({
    this.payload,
    this.status = AuthStatus.anonymous,
    this.accessToken,
    this.user,
    this.error,
  });

  String? get userUuid => user?.id;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated &&
      accessToken != null &&
      accessToken!.trim().isNotEmpty &&
      user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  void setPendingVerification() {
    state = AuthState(
      payload: state.payload,
      status: AuthStatus.pendingVerification,
      accessToken: state.accessToken,
      user: state.user,
      error: state.error,
    );
  }

  void setAnonymous() {
    state = const AuthState();
  }

  void setPayload(Map<String, dynamic> payload) {
    state = AuthState(
      payload: payload,
      status: state.status,
      accessToken: state.accessToken,
      user: state.user,
      error: state.error,
    );
  }

  void setError(String error) {
    state = AuthState(
      payload: state.payload,
      status: state.status,
      accessToken: state.accessToken,
      user: state.user,
      error: error,
    );
  }

  void setAccessToken(String token) {
    state = AuthState(
      payload: state.payload,
      status: state.status,
      accessToken: token,
      user: state.user,
      error: state.error,
    );
  }

  void setUserUuid(String userUuid) {
    state = AuthState(
      payload: state.payload,
      status: state.status,
      accessToken: state.accessToken,
      user: AuthUser(id: userUuid, raw: const <String, dynamic>{}),
      error: state.error,
    );
  }

  Future<void> persistVerifiedSession({
    required String accessToken,
    required AuthUser user,
  }) async {
    final storage = FlutterSecureStorage();
    await storage.write(key: 'access_token', value: accessToken);
    await storage.write(key: 'user_uuid', value: user.id);
    state = AuthState(
      status: AuthStatus.authenticated,
      accessToken: accessToken,
      user: user,
    );
  }

  Future<void> clearSession() async {
    state = const AuthState();
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'user_uuid');
    await storage.delete(key: 'pending_verification_email');
  }
}

class LoginResult {
  final String accessToken;
  final AuthUser user;

  const LoginResult({
    required this.accessToken,
    required this.user,
  });
}

class RemoteLibraryGame {
  final int id;
  final String title;
  final String coverUrl;
  final List<String> genres;
  final String summary;
  final double rating;
  final int hoursPlayed;
  final int? timeToBeatHours;
  final String? status;
  final int? userRating;
  final int year;
  final bool inLibrary;
  final String lastUpdated;

  const RemoteLibraryGame({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.genres,
    required this.summary,
    required this.rating,
    required this.hoursPlayed,
    required this.timeToBeatHours,
    required this.status,
    required this.userRating,
    required this.year,
    required this.inLibrary,
    required this.lastUpdated,
  });
}

class AuthService {
  AuthService(this._dio);

  final Dio _dio;

  Future<LoginResult> login({
    required String userId,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {
        'identifier': userId,
        'password': password,
      },
    );

    final data = response.data;
    if (data is Map && data['access_token'] is String) {
      final responseUser = data['user'];
      final userId = responseUser is Map
          ? responseUser['id'] ?? responseUser['user_id'] ?? responseUser['uuid']
          : null;
      if (userId is String && userId.trim().isNotEmpty) {
        return LoginResult(
          accessToken: (data['access_token'] as String).trim(),
          user: AuthUser(
            id: userId.trim(),
            email: responseUser is Map ? responseUser['email'] as String? : null,
            raw: responseUser is Map ? Map<String, dynamic>.from(responseUser) : const <String, dynamic>{},
          ),
        );
      }
    }

    throw StateError('Login response did not include a usable session payload.');
  }

  Future<void> signUp({
    required String email,
    required String userId,
    required String password,
  }) async {
    const path = '/auth/signup';
    await _dio.post(
      path,
      data: {
        'email': email,
        'username': userId,
        'password': password,
      },
    );
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    const path = '/auth/verify';
    await _dio.post(
      path,
      data: {
        'email': email,
        'code': code,
      },
    );
  }

  Future<void> sendPasswordReset({
    required String email,
  }) async {
    const path = '/auth/forgot-password';
    await _dio.post(
      path,
      data: {
        'email': email,
      },
    );
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    const path = '/auth/reset-password';
    await _dio.post(
      path,
      data: {
        'token': token,
        'password': password,
      },
    );
  }

  Future<List<RemoteLibraryGame>> fetchLibrary({
    required String userId,
    required String accessToken,
  }) async {
    final response = await _dio.get(
      '/database/users/$userId/library',
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );

    final data = response.data;
    final items = data is List
        ? data
        : data is Map && data['library'] is List
            ? data['library'] as List
            : data is Map && data['data'] is List
                ? data['data'] as List
                : const [];

    return items
      .whereType<Map>()
      .map(
        (item) => RemoteLibraryGame(
          id: (item['game_id'] ?? item['id']) as int,
          title: (item['title'] ?? '') as String,
          coverUrl: (item['cover_url'] ?? item['coverUrl'] ?? '') as String,
          genres: (item['genres'] is List)
            ? List<String>.from(item['genres'] as List)
            : const <String>[],
          summary: (item['summary'] ?? '') as String,
          rating: (item['rating'] is num) ? (item['rating'] as num).toDouble() : 0.0,
          hoursPlayed: (item['hours_played'] is num) ? (item['hours_played'] as num).toInt() : 0,
          timeToBeatHours: item['time_to_beat_hours'] is num
            ? (item['time_to_beat_hours'] as num).toInt()
            : null,
          status: item['status'] as String?,
          userRating: item['user_rating'] is num ? (item['user_rating'] as num).toInt() : null,
          year: (item['year'] is num) ? (item['year'] as num).toInt() : 0,
          inLibrary: item['in_library'] is bool
            ? item['in_library'] as bool
            : item['in_library'] is num
              ? (item['in_library'] as num) != 0
              : true,
          lastUpdated: (item['last_updated'] ?? item['lastUpdated'] ?? DateTime.now().toIso8601String()) as String,
        ),
      )
      .toList();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(dioService));
});
