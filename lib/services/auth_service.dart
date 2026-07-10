import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dio_service.dart';

class AuthState {
  final Map<String, dynamic>? payload;
  final String? error;
  final String? accessToken;
  final String? userUuid;

  const AuthState({this.payload, this.error, this.accessToken, this.userUuid});
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  void setPayload(Map<String, dynamic> payload) {
    state = AuthState(
      payload: payload,
      accessToken: state.accessToken,
      userUuid: state.userUuid,
    );
  }

  void setError(String error) {
    state = AuthState(
      error: error,
      accessToken: state.accessToken,
      userUuid: state.userUuid,
    );
  }

  void setAccessToken(String token) {
    state = AuthState(accessToken: token, userUuid: state.userUuid);
  }

  void setUserUuid(String userUuid) {
    state = AuthState(
      payload: state.payload,
      error: state.error,
      accessToken: state.accessToken,
      userUuid: userUuid,
    );
  }

  Future<void> clearSession() async {
    state = const AuthState();
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'user_uuid');
  }
}

class LoginResult {
  final String accessToken;
  final String userId;

  const LoginResult({
    required this.accessToken,
    required this.userId,
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
      final responseUserId = responseUser is Map && responseUser['id'] is String
          ? responseUser['id'] as String
          : null;

      if (responseUserId == null || responseUserId.trim().isEmpty) {
        throw StateError('Login response did not include a user id.');
      }

      return LoginResult(
        accessToken: data['access_token'] as String,
        userId: responseUserId.trim(),
      );
    }

    throw StateError('Login response did not include an access token.');
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
