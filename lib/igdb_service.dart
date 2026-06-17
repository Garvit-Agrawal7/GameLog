import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'game_modal.dart';

class IgdbRateLimitException implements Exception {
  IgdbRateLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

class IgdbService {
  IgdbService({
    Dio? dio,
    String? clientId,
    String? clientSecret,
  })  : _dio = dio ?? Dio(),
        _clientId = clientId ?? dotenv.env['CLIENT_ID']!,
        _clientSecret = clientSecret ?? dotenv.env['CLIENT_SECRET']!;

  final Dio _dio;
  final String _clientId;
  final String _clientSecret;

  String? _accessToken;
  DateTime? _tokenExpiry;
  Future<String>? _tokenRequest;

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
    if (trimmedQuery.isEmpty) return const [];

    try {
      final token = await _getAccessToken();
      final response = await _dio.post(
        'https://api.igdb.com/v4/games',
        data: _buildSearch(trimmedQuery, limit),
        options: Options(
          headers: {
            'Client-ID': _clientId,
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.data is! List || (response.data as List).isEmpty) {
        return const [];
      }
      return await Future.wait(
        (response.data as List)
            .whereType<Map<String, dynamic>>()
            .map(_payloadToGameModal),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) throw IgdbRateLimitException('Slow Down bruh');
      rethrow;
    }
  }

  Future<List<GameModal>> fetchSimilarGames(int gameId) async {
    try {
      final token = await _getAccessToken();

      final response = await _dio.post(
        'https://api.igdb.com/v4/games',
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
        options: Options(
          headers: {
            'Client-ID': _clientId,
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
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

      return Future.wait(
        rankedGames
          .map(_payloadToGameModal),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw IgdbRateLimitException('Slow Down bruh');
      }
      rethrow;
    }
  }

  Future<List<GameModal>> fetchTrendingGames({int limit = 10}) async {
    final yearStart = DateTime(DateTime.now().year).millisecondsSinceEpoch ~/ 1000;
    final token = await _getAccessToken();
    final response = await _dio.post(
      'https://api.igdb.com/v4/games',
      data: 'fields name,cover.image_id,genres.name,first_release_date,rating,rating_count; '
          'where first_release_date > $yearStart & rating != null & rating_count != null & game_type = (0,8,9); '
          'sort rating_count desc; '
          'limit ${limit * 3};',
      options: Options(headers: {
        'Client-ID': _clientId,
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }),
    );

    if (response.data is! List || (response.data as List).isEmpty) return const [];

    final games = (response.data as List).whereType<Map<String, dynamic>>().toList();

    final rankedGames = _calculateRatingOrder(games);

    return await Future.wait(
      rankedGames.take(limit).map(_payloadToGameModal),
    );
  }

  Future<List<GameModal>> fetchUpcomingGames({int limit = 10}) async {
    final yearEnd = DateTime.now().add(Duration(days: 365)).millisecondsSinceEpoch ~/ 1000;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final token = await _getAccessToken();
    final response = await _dio.post(
      'https://api.igdb.com/v4/games',
      data: 'fields name,summary,cover.image_id,genres.name,first_release_date,rating; '
          'where first_release_date > $now & first_release_date < $yearEnd & hypes != null & game_type = 0; '
          'sort hypes desc; '
          'limit $limit;',
      options: Options(headers: {
        'Client-ID': _clientId,
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }),
    );

    if (response.data is! List || (response.data as List).isEmpty) return const [];

    return await Future.wait(
      (response.data as List).whereType<Map<String, dynamic>>().map(_payloadToGameModal),
    );
  }

  Future<List<GameModal>> fetchByGenre(String genre, {int limit = 10}) async {
    try {
      final token = await _getAccessToken();
      final response = await _dio.post(
        'https://api.igdb.com/v4/games',
        data: 'fields name,cover.image_id,genres.name,first_release_date,rating,rating_count; '
            'where genres.name = "${genre.replaceAll('"', '\\"')}" '
            '& rating != null & rating_count != null & game_type = (0,8,9); '
            'sort rating_count desc; '
            'limit ${limit * 3};',
        options: Options(headers: {
          'Client-ID': _clientId,
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        }),
      );

      if (response.data is! List || (response.data as List).isEmpty) return const [];

      final games = (response.data as List).whereType<Map<String, dynamic>>().toList();

      final rankedGames = _calculateRatingOrder(games, minimumVotes: 50);

      return await Future.wait(
        rankedGames.take(limit).map(_payloadToGameModal),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw IgdbRateLimitException('Slow Down bruh');
      }
      rethrow;
    }
  }

  Future<GameModal> _fetchGameByTitle(GameModal seed) async {
    try {
      final token = await _getAccessToken();
      const requestUrl = 'https://api.igdb.com/v4/games';
      final response = await _dio.post(
        requestUrl,
        data: _buildQuery(seed.title),
        options: Options(
          headers: {
            'Client-ID': _clientId,
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
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
      final token = await _getAccessToken();
      const requestUrl = 'https://api.igdb.com/v4/multiquery';
      final response = await _dio.post(
        requestUrl,
        data: _buildMultiQuery(batch),
        options: Options(
          headers: {
            'Client-ID': _clientId,
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
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

  Future<String> _getAccessToken() {
    final currentToken = _accessToken;
    final currentExpiry = _tokenExpiry;
    if (currentToken != null &&
        currentExpiry != null &&
        DateTime.now().isBefore(currentExpiry)) {
      return Future.value(currentToken);
    }

    final pendingRequest = _tokenRequest;
    if (pendingRequest != null) {
      return pendingRequest;
    }

    final request = _requestAccessToken();
    _tokenRequest = request.whenComplete(() {
      _tokenRequest = null;
    });
    return _tokenRequest!;
  }

  Future<String> _requestAccessToken() async {
    final response = await _dio.post(
      'https://id.twitch.tv/oauth2/token',
      queryParameters: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'grant_type': 'client_credentials',
      },
      options: Options(headers: {'Accept': 'application/json'}),
    );

    final data = response.data as Map<String, dynamic>;
    _accessToken = data['access_token'] as String?;
    final expiresIn = data['expires_in'] as int? ?? 0;
    final cacheSeconds = expiresIn > 30 ? expiresIn - 30 : 0;
    _tokenExpiry = DateTime.now().add(Duration(seconds: cacheSeconds));

    if (_accessToken == null || _accessToken!.isEmpty) {
      throw StateError('IGDB access token missing');
    }

    return _accessToken!;
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
        'fields name,cover.image_id,genres.name,first_release_date; '
        'where game_type = (0, 8, 9); '
        'limit $limit;';
  }

  Future<GameModal> _payloadToGameModal(Map<String, dynamic> data) async {
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
          : 'https://picsum.photos/seed/igdb-$id/800/1200',
      genres: genres,
      summary: summary?.isNotEmpty == true ? summary! : '',
      rating: rating ?? 0,
      hoursPlayed: 0,
      timeToBeatHours: await fetchTimeToBeat(id),
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
    return 'https://images.igdb.com/igdb/image/upload/t_1080p/$imageId.jpg';
  }

  Future<int?> fetchTimeToBeat(int gameId) async {
    try {
      final token = await _getAccessToken();
      const requestUrl = 'https://api.igdb.com/v4/game_time_to_beats';
      final response = await _dio.post(
        requestUrl,
        data: 'fields hastily; where game_id = $gameId; limit 1;',
        options: Options(
          headers: {
            'Client-ID': _clientId,
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
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
