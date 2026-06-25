import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_modal.dart';

class IgdbRateLimitException implements Exception {
  IgdbRateLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

final igdbAccessTokenProvider = Provider<String>((ref) {
  throw UnimplementedError('Token must be set via override before app starts');
});

final igdbServiceProvider = Provider<IgdbService>((ref) {
  final token = ref.watch(igdbAccessTokenProvider);
  return IgdbService(token: token);
});

class IgdbService {
  IgdbService({
    required String token,
    Dio? dio,
    String? clientId,
  })  : _dio = dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.igdb.com/v4',
              headers: {
                'Accept': 'application/json',
                'Client-ID': clientId ?? dotenv.env['CLIENT_ID']!,
                'Authorization': 'Bearer $token',
              },
            ),
          );

  final Dio _dio;

  final Map<String, List<GameModal>> _searchCache = {};

  static Future<String> fetchAccessToken() async {
    final clientId = dotenv.env['CLIENT_ID']!;
    final clientSecret = dotenv.env['CLIENT_SECRET']!;
    final dio = Dio();

    final response = await dio.post(
      'https://id.twitch.tv/oauth2/token',
      queryParameters: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'client_credentials',
      },
      options: Options(headers: {'Accept': 'application/json'}),
    );

    final data = response.data as Map<String, dynamic>;
    final accessToken = data['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('IGDB access token missing');
    }
    return accessToken;
  }

  Future<List<GameModal>> enrichGames(List<GameModal> seeds) async {
    if (seeds.isEmpty) {
      return seeds;
    }

    final enriched = <GameModal>[];
    const batchSize = 10;

    for (var index = 0; index < seeds.length; index += batchSize) {
      final batch = seeds.sublist(index, index + batchSize > seeds.length ? seeds.length : index + batchSize);
      enriched.addAll(await _enrichGames(batch));
    }

    return enriched;
  }

  Future<List<GameModal>> searchGames(String query, {int limit = 10}) async {
    final trimmedQuery = query.trim();
    final cacheKey = trimmedQuery.toLowerCase();
    if (trimmedQuery.isEmpty) return const [];

    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    try {
      final response = await _dio.post(
        '/games',
        data: _buildSearch(trimmedQuery, limit),
      );

      if (response.data is! List || (response.data as List).isEmpty) {
        return const [];
      }
      final result = (response.data as List)
          .whereType<Map<String, dynamic>>()
          .map(_payloadToGameModal)
          .toList();

      // Stores result for future searches
      _searchCache[cacheKey] = result;

      return result;

    } on DioException catch (e) {
      if (e.response?.statusCode == 429) throw IgdbRateLimitException('Slow Down bruh');
      rethrow;
    }
  }

  Future<List<GameModal>> fetchSimilarGames(int gameId) async {
    try {
      final response = await _dio.post(
        '/games',
        data: '''
          fields
            similar_games.name,
            similar_games.summary,
            similar_games.cover.image_id,
            similar_games.genres.name,
            similar_games.first_release_date,
            similar_games.rating,
            similar_games.rating_count;
  
          where id = $gameId;
          limit 1;
        ''',
      );

      if (response.data is! List || (response.data as List).isEmpty) {
        return const [];
      }

      final game =
        (response.data as List)
          .whereType<Map<String, dynamic>>()
          .firstOrNull;

      if (game == null) return const [];

      final similarGames =
        (game['similar_games'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .where(
            (g) =>
            g['rating'] != null &&
            g['rating_count'] != null,
          )
          .toList() ??
          [];

      final rankedGames = _calculateRatingOrder(
        similarGames,
        minimumVotes: 50,
      );

      return rankedGames.map(_payloadToGameModal).toList();

    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw IgdbRateLimitException('Slow Down bruh');
      }
      rethrow;
    }
  }

  Future<List<GameModal>> fetchTrendingGames({int limit = 10}) async {
    final yearStart = DateTime(DateTime.now().year).millisecondsSinceEpoch ~/ 1000;
    final response = await _dio.post(
      '/games',
      data: 'fields name,summary,cover.image_id,genres.name,first_release_date,rating,rating_count; '
          'where first_release_date > $yearStart & rating != null & rating_count != null & game_type = (0,8,9); '
          'sort rating_count desc; '
          'limit $limit;',
    );

    if (response.data is! List || (response.data as List).isEmpty) return const [];

    final games = (response.data as List).whereType<Map<String, dynamic>>().toList();
    final rankedGames = _calculateRatingOrder(games);

    return rankedGames.take(limit).map(_payloadToGameModal).toList();
  }

  Future<List<GameModal>> fetchUpcomingGames({int limit = 10}) async {
    final yearEnd = DateTime.now().add(Duration(days: 365)).millisecondsSinceEpoch ~/ 1000;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final response = await _dio.post(
      '/games',
      data: 'fields name,summary,cover.image_id,genres.name,first_release_date,rating; '
          'where first_release_date > $now & first_release_date < $yearEnd & hypes != null & game_type = 0; '
          'sort hypes desc; '
          'limit $limit;',
    );

    if (response.data is! List || (response.data as List).isEmpty) return const [];

    return (response.data as List).whereType<Map<String, dynamic>>().map(_payloadToGameModal).toList();
  }

  Future<List<GameModal>> fetchByGenre(String genre, {int limit = 10}) async {
    try {
      final response = await _dio.post(
        '/games',
        data: 'fields name,summary,cover.image_id,genres.name,first_release_date,rating,rating_count; '
            'where genres.name = "${genre.replaceAll('"', '\\"')}" '
            '& rating != null & rating_count != null & game_type = (0,8,9); '
            'sort rating_count desc; '
            'limit $limit;',
      );

      if (response.data is! List || (response.data as List).isEmpty) return const [];

      final games = (response.data as List).whereType<Map<String, dynamic>>().toList();
      final rankedGames = _calculateRatingOrder(games, minimumVotes: 50);

      return rankedGames.take(limit).map(_payloadToGameModal).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw IgdbRateLimitException('Slow Down bruh');
      }
      rethrow;
    }
  }

  Future<GameModal> _fetchGameByTitle(GameModal seed) async {
    try {
      final response = await _dio.post(
        '/games',
        data: _buildQuery(seed.title),
      );

      if (response.data is! List || (response.data as List).isEmpty) {
        return seed;
      }

      final payload = response.data as List;
      final data = _pickBestMatch(seed.title, payload) ?? payload.first as Map<String, dynamic>;
      final coverId = _readCoverId(data);
      final genres = _readGenres(data);
      final rating = _readRating(data);
      final summary = data['summary'] as String?;
      final year = _readYear(data);


      return GameModal(
        id: seed.id,
        title: data['name'] as String? ?? seed.title,
        coverUrl: coverId != null ? _coverUrl(coverId) : seed.coverUrl,
        genres: genres.isNotEmpty ? genres : seed.genres,
        summary: summary?.isNotEmpty == true ? summary! : seed.summary,
        rating: rating ?? seed.rating,
        hoursPlayed: seed.hoursPlayed,
        status: seed.status,
        year: year ?? seed.year,
        inLibrary: seed.inLibrary,
        lastUpdated: seed.lastUpdated,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw IgdbRateLimitException('Slow Down bruh');
      }
      return seed;
    } catch (e) {
      return seed;
    }
  }

  Future<List<GameModal>> _enrichGames(List<GameModal> batch) async {
    if (batch.isEmpty) {
      return const [];
    }

    if (batch.length == 1) {
      return [await _fetchGameByTitle(batch.first)];
    }

    try {
      final response = await _dio.post(
        '/multiquery',
        data: _buildMultiQuery(batch),
      );

      if (response.data is! List || (response.data as List).isEmpty) {
        return Future.wait(batch.map(_fetchGameByTitle));
      }

      final resultByIndex = <int, List<dynamic>>{};
      for (final item in (response.data as List).whereType<Map<String, dynamic>>()) {
        final name = item['name'];
        final result = item['result'];
        if (name is! String || result is! List) {
          continue;
        }

        final index = int.tryParse(name);
        if (index != null) {
          resultByIndex[index] = result;
        }
      }

      final enriched = <GameModal>[];
      for (var i = 0; i < batch.length; i++) {
        final seed = batch[i];
        final payload = resultByIndex[i];
        if (payload == null || payload.isEmpty) {
          enriched.add(seed);
          continue;
        }

        final data = _pickBestMatch(seed.title, payload) ?? payload.first as Map<String, dynamic>;
        final coverId = _readCoverId(data);
        final genres = _readGenres(data);
        final rating = _readRating(data);
        final summary = data['summary'] as String? ?? data['description'] as String?;
        final year = _readYear(data);

        enriched.add(
          GameModal(
            id: seed.id,
            title: data['name'] as String? ?? seed.title,
            coverUrl: coverId != null ? _coverUrl(coverId) : seed.coverUrl,
            genres: genres.isNotEmpty ? genres : seed.genres,
            summary: summary?.isNotEmpty == true ? summary! : seed.summary,
            rating: rating ?? seed.rating,
            hoursPlayed: seed.hoursPlayed,
            status: seed.status,
            year: year ?? seed.year,
            inLibrary: seed.inLibrary,
            lastUpdated: seed.lastUpdated,
          ),
        );
      }

      return enriched;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw IgdbRateLimitException('Slow Down bruh');
      }
      return Future.wait(batch.map(_fetchGameByTitle));
    } catch (_) {
      return Future.wait(batch.map(_fetchGameByTitle));
    }
  }

  String _buildMultiQuery(List<GameModal> batch) {
    final buffer = StringBuffer();
    for (var i = 0; i < batch.length; i++) {
      final escapedTitle = batch[i].title.replaceAll('"', '\\"');
      buffer.writeln('query games "$i" {');
      buffer.writeln('  search "$escapedTitle";');
      buffer.writeln('  fields name,summary,cover.image_id,genres.name,first_release_date,rating;');
      buffer.writeln('  limit 5;');
      buffer.writeln('};');
      if (i < batch.length - 1) {
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  String _buildQuery(String title) {
    final escapedTitle = title.replaceAll('"', '\\"');
    return 'search "$escapedTitle"; '
        'fields name,summary,cover.image_id,genres.name,first_release_date,rating; '
        'limit 5;';
  }

  String _buildSearch(String query, int limit) {
    final newQuery = query.replaceAll('"', '\\"');
    return 'search "$newQuery"; '
        'fields name,summary,cover.image_id,genres.name,first_release_date,rating; '
        'where game_type = (0, 8, 9); '
        'limit $limit;';
  }

  GameModal _payloadToGameModal(Map<String, dynamic> data) {
    final id = data['id'] is int ? data['id'] as int : data.hashCode;
    final coverId = _readCoverId(data);
    final genres = _readGenres(data);
    final rating = _readRating(data);
    final summary = data['summary'] as String?;
    final year = _readYear(data);

    return GameModal(
      id: id,
      title: data['name'] as String? ?? 'Unknown Game',
      coverUrl: coverId != null
          ? _coverUrl(coverId)
          : '',
      genres: genres,
      summary: summary?.isNotEmpty == true ? summary! : '',
      rating: rating ?? 0,
      hoursPlayed: 0,
      timeToBeatHours: null,
      year: year ?? DateTime.now().year,
      lastUpdated: '',
    );
  }


  Map<String, dynamic>? _pickBestMatch(String seedTitle, List<dynamic> payload) {
    final target = _normalizeTitle(seedTitle);
    Map<String, dynamic>? bestMatch;
    var bestScore = -1;

    for (final item in payload.whereType<Map<String, dynamic>>()) {
      final name = item['name'];
      if (name is! String || name.trim().isEmpty) {
        continue;
      }

      final score = _scoreTitleMatch(target, _normalizeTitle(name), item['first_release_date']);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }
    return bestScore >= 60 ? bestMatch : null;
  }

  List<Map<String, dynamic>> _calculateRatingOrder(
      List<Map<String, dynamic>> games, {
        int minimumVotes = 100,
      }) {
    if (games.isEmpty) return games;

    final globalAverage = games.fold<double>(0, (sum, g) => sum + ((g['rating'] as num?)?.toDouble() ?? 0),) / games.length;

    final scored = games.map((game) {
      final rating = (game['rating'] as num).toDouble();
      final votes = (game['rating_count'] as num).toInt();

      final weightedScore =
          ((votes / (votes + minimumVotes)) * rating) +
              ((minimumVotes / (votes + minimumVotes)) * globalAverage);

      return (
      game: game,
      score: weightedScore,
      );
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((e) => e.game).toList();
  }

  int _scoreTitleMatch(String target, String candidate, Object? releaseDate) {
    if (candidate == target) {
      return 1000;
    }

    var score = 0;

    if (candidate.startsWith(target) || target.startsWith(candidate)) {
      score += 500;
    }

    final targetTokens = target.split(' ').where((token) => token.isNotEmpty).toSet();
    final candidateTokens = candidate.split(' ').where((token) => token.isNotEmpty).toSet();
    final overlap = targetTokens.intersection(candidateTokens).length;
    score += overlap * 40;

    final targetLength = targetTokens.length;
    final candidateLength = candidateTokens.length;
    score -= (targetLength - candidateLength).abs() * 3;

    if (releaseDate is int) {
      score += 10;
    }

    return score;
  }

  String _normalizeTitle(String input) {
    const replacements = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'œ': 'oe',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
    };

    final lowered = input.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lowered.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char);
    }

    return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  String? _readCoverId(Map<String, dynamic> data) {
    final cover = data['cover'];
    if (cover is Map<String, dynamic>) {
      return cover['image_id'] as String?;
    }
    return null;
  }

  List<String> _readGenres(Map<String, dynamic> data) {
    final raw = data['genres'];
    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map<String, dynamic>>()
        .map((genre) => genre['name'])
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }

  double? _readRating(Map<String, dynamic> data) {
    final rating = data['rating'];
    if (rating is num) {
      return rating.toDouble();
    }
    return null;
  }

  int? _readYear(Map<String, dynamic> data) {
    final release = data['first_release_date'];
    if (release is int) {
      return DateTime.fromMillisecondsSinceEpoch(release * 1000).year;
    }
    return null;
  }

  String _coverUrl(String imageId) {
    return 'https://images.igdb.com/igdb/image/upload/t_720p/$imageId.jpg';
  }

  Future<int?> fetchTimeToBeat(int gameId) async {
    try {
      final response = await _dio.post(
        '/game_time_to_beats',
        data: 'fields hastily; where game_id = $gameId; limit 1;',
      );

      if (response.data is! List || (response.data as List).isEmpty) {
        return null;
      }

      final item = (response.data as List).firstWhere(
        (e) => e is Map<String, dynamic>,
        orElse: () => null,
      ) as Map<String, dynamic>?;
      if (item == null) {
        return null;
      }

      final hastily = item['hastily'];
      if (hastily is num) {
        return (hastily.toDouble() / 3600).round();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
