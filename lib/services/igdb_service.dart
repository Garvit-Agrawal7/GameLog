import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_modal.dart';
import 'dio_service.dart';

class IgdbRateLimitException implements Exception {
  IgdbRateLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

final igdbServiceProvider = Provider<IgdbService>((ref) {
  return IgdbService(ref.watch(dioService));
});

class IgdbService {
  IgdbService(this._dio);

  final Dio _dio;

  final Map<String, List<GameModal>> _searchCache = {};

  Future<List<GameModal>> searchGames(String query, {int limit = 10}) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return const [];

    final cacheKey = '${trimmedQuery.toLowerCase()}|$limit';
    final cached = _searchCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    try {
      final response = await _dio.get(
        '/igdb/search',
        queryParameters: {
          'query': trimmedQuery,
          'limit': limit,
        },
      );

      final result = _mapGameList(response.data);
      _searchCache[cacheKey] = result;
      return result;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw IgdbRateLimitException('Slow Down bruh');
      }
      rethrow;
    }
  }

  Future<List<GameModal>> fetchSimilarGames(int gameId) async {
    try {
      final response = await _dio.get(
        '/igdb/similar',
        queryParameters: {
          'game_id': gameId,
        },
      );

      return _mapGameList(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw IgdbRateLimitException('Slow Down bruh');
      }
      rethrow;
    }
  }

  Future<List<GameModal>> fetchTrendingGames({int limit = 10}) async {
    try {
      final response = await _dio.get(
        '/igdb/trending',
        queryParameters: {
          'limit': limit,
        },
      );

      return _mapGameList(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw IgdbRateLimitException('Slow Down bruh');
      }
      rethrow;
    }
  }

  Future<List<GameModal>> fetchUpcomingGames({int limit = 10}) async {
    try {
      final response = await _dio.get(
        '/igdb/upcoming',
        queryParameters: {
          'limit': limit,
        },
      );

      return _mapGameList(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw IgdbRateLimitException('Slow Down bruh');
      }
      rethrow;
    }
  }

  Future<List<GameModal>> fetchByGenre(String genre, {int limit = 10}) async {
    final trimmedGenre = genre.trim();
    if (trimmedGenre.isEmpty) return const [];

    try {
      final response = await _dio.get(
        '/igdb/by-genre',
        queryParameters: {
          'genre': trimmedGenre,
          'limit': limit,
        },
      );

      return _mapGameList(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw IgdbRateLimitException('Slow Down bruh');
      }
      rethrow;
    }
  }

  Future<List<GameModal>> enrichGames(List<GameModal> seeds) async {
    if (seeds.isEmpty) {
      return seeds;
    }

    final enriched = <GameModal>[];
    const batchSize = 10;

    for (var index = 0; index < seeds.length; index += batchSize) {
      final batch = seeds.sublist(
        index,
        index + batchSize > seeds.length ? seeds.length : index + batchSize,
      );

      try {
        final response = await _dio.post(
          '/igdb/enrich',
          data: {
            'seeds': batch.map(_seedToMap).toList(),
          },
        );

        final mapped = _mapGameList(response.data);
        if (mapped.isNotEmpty) {
          enriched.addAll(mapped);
        } else {
          enriched.addAll(batch);
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          throw IgdbRateLimitException('Slow Down bruh');
        }
        enriched.addAll(batch);
      } catch (_) {
        enriched.addAll(batch);
      }
    }

    return enriched;
  }

  Future<int?> fetchTimeToBeat(int gameId) async {
    try {
      final response = await _dio.get('/igdb/time-to-beat/$gameId');

      final data = response.data;
      if (data is Map) {
        final raw = data['time_to_beat_hours'] ?? data['timeToBeatHours'];
        if (raw is num) {
          return raw.round();
        }
      }

      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw IgdbRateLimitException('Slow Down bruh');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  List<GameModal> _mapGameList(dynamic data) {
    final items = _extractMaps(data);
    if (items.isEmpty) {
      return const [];
    }
    return items.map(_payloadToGameModal).toList();
  }

  List<Map<String, dynamic>> _extractMaps(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);

      final possibleLists = [
        map['games'],
        map['results'],
        map['data'],
        map['items'],
      ];

      for (final value in possibleLists) {
        if (value is List) {
          return value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }

      return [map];
    }

    return const [];
  }

  GameModal _payloadToGameModal(Map<String, dynamic> data) {
    final id = _readId(data);
    final title = _readTitle(data);
    final coverUrl = _readCoverUrl(data);
    final genres = _readGenres(data);
    final summary = _readSummary(data);
    final rating = _readRating(data);
    final hoursPlayed = _readInt(data, 'hoursPlayed') ?? 0;
    final timeToBeatHours =
        _readInt(data, 'timeToBeatHours') ??
            _readInt(data, 'time_to_beat_hours');
    final status = data['status'] as String?;
    final year = _readYear(data);
    final inLibrary = data['inLibrary'] is bool
        ? data['inLibrary'] as bool
        : false;
    final lastUpdated = data['lastUpdated'] as String? ?? '';

    return GameModal(
      id: id,
      title: title,
      coverUrl: coverUrl,
      genres: genres,
      summary: summary,
      rating: rating,
      hoursPlayed: hoursPlayed,
      timeToBeatHours: timeToBeatHours,
      status: status,
      year: year,
      inLibrary: inLibrary,
      lastUpdated: lastUpdated,
    );
  }

  Map<String, dynamic> _seedToMap(GameModal game) {
    return {
      'id': game.id,
      'title': game.title,
      'coverUrl': game.coverUrl,
      'genres': game.genres,
      'summary': game.summary,
      'rating': game.rating,
      'hoursPlayed': game.hoursPlayed,
      'timeToBeatHours': game.timeToBeatHours,
      'status': game.status,
      'year': game.year,
      'inLibrary': game.inLibrary,
      'lastUpdated': game.lastUpdated,
    };
  }

  int _readId(Map<String, dynamic> data) {
    final id = data['id'];
    if (id is int) {
      return id;
    }
    if (id is num) {
      return id.toInt();
    }
    return data.hashCode;
  }

  String _readTitle(Map<String, dynamic> data) {
    final title = data['title'] ?? data['name'];
    if (title is String && title
        .trim()
        .isNotEmpty) {
      return title;
    }
    return 'Unknown Game';
  }

  String _readCoverUrl(Map<String, dynamic> data) {
    final coverUrl = data['coverUrl'];
    if (coverUrl is String && coverUrl.isNotEmpty) {
      return coverUrl;
    }

    final cover = data['cover'];
    if (cover is Map) {
      final imageId = cover['image_id'];
      if (imageId is String && imageId.isNotEmpty) {
        return 'https://images.igdb.com/igdb/image/upload/t_720p/$imageId.jpg';
      }
    }

    return '';
  }

  List<String> _readGenres(Map<String, dynamic> data) {
    final raw = data['genres'];
    if (raw is! List) {
      return const [];
    }

    return raw
        .map<String?>((item) {
      if (item is String) return item;
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final name = map['name'];
        if (name is String) return name;
      }
      return null;
    })
        .whereType<String>()
        .where((genre) =>
    genre
        .trim()
        .isNotEmpty)
        .toList();
  }

  String _readSummary(Map<String, dynamic> data) {
    final summary = data['summary'] ?? data['description'];
    if (summary is String && summary
        .trim()
        .isNotEmpty) {
      return summary;
    }
    return '';
  }

  double _readRating(Map<String, dynamic> data) {
    final rating = data['rating'];
    if (rating is num) {
      return rating.toDouble();
    }
    return 0;
  }

  int _readYear(Map<String, dynamic> data) {
    final yearValue = data['year'];
    if (yearValue is int) {
      return yearValue;
    }
    if (yearValue is num) {
      return yearValue.toInt();
    }

    final release = data['first_release_date'];
    if (release is int) {
      return DateTime
          .fromMillisecondsSinceEpoch(release * 1000)
          .year;
    }
    if (release is num) {
      return DateTime
          .fromMillisecondsSinceEpoch(release.toInt() * 1000)
          .year;
    }

    return DateTime
        .now()
        .year;
  }

  int? _readInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}
