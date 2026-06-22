import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_library_provider.dart';
import '../igdb_service.dart';
import 'game_detail_screen.dart' as detail;
import '../game_modal.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_cached_image.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key, this.service});

  final IgdbService? service;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  late final Future<List<GameModal>> _trendingFuture;
  late final Future<List<GameModal>> _upcomingFuture;
  Future<List<GameModal>>? _similarGamesFuture;
  Future<List<GameModal>>? _topGenreFuture;
  int? _lastCompletedGameId;
  String? _lastCompletedGameTitle;

  IgdbService get _service => widget.service ?? ref.read(igdbServiceProvider);

  @override
  void initState() {
    super.initState();
    _trendingFuture = _service.fetchTrendingGames(limit: 50).catchError(
      (_) => <GameModal>[],
    );
    _upcomingFuture = _service.fetchUpcomingGames().catchError(
      (_) => <GameModal>[],
    );
  }

  void _syncSimilarGames(List<GameModal> recentlyCompleted) {
    if (recentlyCompleted.isEmpty) {
      _lastCompletedGameId = null;
      _lastCompletedGameTitle = null;
      _similarGamesFuture = null;
      return;
    }

    final latest = recentlyCompleted.first;
    if (_lastCompletedGameId != latest.id) {
      _lastCompletedGameId = latest.id;
      _lastCompletedGameTitle = latest.title;
      _similarGamesFuture = _service
          .fetchSimilarGames(latest.id)
          .catchError((_) => <GameModal>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentlyCompleted = ref.watch(recentlyCompletedProvider);
    final libraryGames = ref.watch(libraryGamesProvider);
    final libraryIds = libraryGames.map((g) => g.id).toSet();
    final topGenre = ref.watch(topGenreProvider);

    if (topGenre != null && _topGenreFuture == null) {
      _topGenreFuture = _service.fetchByGenre(topGenre, limit: 50).catchError((_) => <GameModal>[]);
    }

    ref.listen(libraryGamesProvider, (previous, next) {
      if (_topGenreFuture == null) {
        final genre = ref.read(topGenreProvider);
        if (genre != null) {
          setState(() {
            _topGenreFuture = _service.fetchByGenre(genre, limit: 50).catchError((_) => <GameModal>[]);
          });
        }
      }
    });

    _syncSimilarGames(recentlyCompleted);

    return FutureBuilder(
      future: Future.wait([
        _trendingFuture,
        _upcomingFuture,
        if (_similarGamesFuture != null) _similarGamesFuture!,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.bg0,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accentPurple),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.bg0,
          appBar: AppBar(title: const Text('Explore')),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recentlyCompleted.isNotEmpty)
                  FutureBuilder<List<GameModal>>(
                    future: _similarGamesFuture ?? Future.value(const []),
                    builder: (context, similarSnapshot) {
                      final sourceTitle =
                          _lastCompletedGameTitle ?? 'your last completed game';

                      final games = (similarSnapshot.data ?? [])
                          .where((g) => !libraryIds.contains(g.id))
                          .toList();

                      return _HorizontalGameSection(
                        title: 'Because you liked "$sourceTitle"',
                        games: games,
                        rightPadding: 40,
                      );
                    },
                  ),
                if (recentlyCompleted.isNotEmpty)
                  FutureBuilder<List<GameModal>>(
                    future: _topGenreFuture,
                    builder: (context, topGenreSnapshot) {
                      final genreGames = (topGenreSnapshot.data ?? [])
                          .where((g) => !libraryIds.contains(g.id))
                          .take(10)
                          .toList();

                      if (topGenre == null) return const SizedBox.shrink();
                      return _HorizontalGameSection(
                        title: 'Top in $topGenre',
                        games: genreGames,
                      );
                    },
                  ),
                FutureBuilder<List<GameModal>>(
                  future: _trendingFuture,
                  builder: (context, trendingSnapshot) {
                    final trendingGames = (trendingSnapshot.data ?? [])
                        .where((g) => !libraryIds.contains(g.id))
                        .take(10)
                        .toList();

                    return _HorizontalGameSection(
                      title: 'Trending This Year',
                      games: trendingGames,
                    );
                  },
                ),
                FutureBuilder<List<GameModal>>(
                  future: _upcomingFuture,
                  builder: (context, upcomingSnapshot) {
                    final upcomingGames = (upcomingSnapshot.data ?? [])
                        .toList();

                    return _HorizontalGameSection(
                      title: 'Upcoming Releases',
                      games: upcomingGames,
                      showRating: false,
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HorizontalGameSection extends StatelessWidget {
  const _HorizontalGameSection({
    required this.title,
    required this.games,
    this.rightPadding = 20,
    this.showRating = true,
  });

  final String title;
  final List<GameModal> games;
  final double rightPadding;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, rightPadding, 0),
            child: _DiscoverSectionHeader(title: title),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: games.length,
              padding: const EdgeInsets.only(left: 20),
              itemBuilder: (context, index) {
                return _DiscoverGameCard(
                  game: games[index],
                  showRating: showRating,
                ).paddingOnly(right: 12);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverSectionHeader extends StatelessWidget {
  const _DiscoverSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.title,
    );
  }
}

class _DiscoverGameCard extends StatelessWidget {
  const _DiscoverGameCard({required this.game, this.showRating = true});

  final GameModal game;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => detail.GameDetailScreen(game: game),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AppCachedImage(
                imageUrl: game.coverUrl,
                width: 130,
                height: 170,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              game.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            if (showRating)
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    (game.rating / 10).toStringAsFixed(2),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

extension on Widget {
  Widget paddingOnly({double right = 0}) {
    return Padding(
      padding: EdgeInsets.only(right: right),
      child: this,
    );
  }
}
