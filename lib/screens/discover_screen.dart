import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_library_provider.dart';
import '../igdb_service.dart';
import 'package:my_game_list/screens/game_detail_screen.dart' as detail;
import '../mock/mock_data.dart';
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
  late final Future<List<MockGame>> _catalogFuture;
  Future<List<MockGame>>? _similarGamesFuture;
  int? _lastCompletedGameId;
  String? _lastCompletedGameTitle;

  IgdbService get _service => widget.service ?? IgdbService();

  @override
  void initState() {
    super.initState();
    _catalogFuture = _service.enrichGames(mockGames);
  }

  void _syncSimilarGames(List<MockGame> recentlyCompleted) {
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
      _similarGamesFuture = _service.fetchSimilarGames(latest.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentlyCompleted = ref.watch(recentlyCompletedProvider);
    final libraryGames = ref.watch(libraryGamesProvider);
    _syncSimilarGames(recentlyCompleted);

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(title: const Text('Explore')),
      body: FutureBuilder<List<MockGame>>(
        future: _catalogFuture,
        builder: (context, catalogSnapshot) {
          if (catalogSnapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentPurple),
            );
          }

          if (catalogSnapshot.hasError) {
            final displayMsg = catalogSnapshot.error is IgdbRateLimitException
                ? (catalogSnapshot.error as IgdbRateLimitException).message
                : 'Error loading games';
            return Center(
              child: Text(
                displayMsg,
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            );
          }

          final catalogGames = catalogSnapshot.data ?? const <MockGame>[];
          final trending = catalogGames.where((game) => game.rating >= 90).take(5).toList();
          final hiddenGems = _gamesForTitles(catalogGames, const [
            'Disco Elysium',
            'Alan Wake 2',
            'Hollow Knight',
            'Hades',
            'Horizon Zero Dawn',
          ]);
          final topRpg = catalogGames
              .where((game) => game.genres.any((genre) => genre.toLowerCase().contains('rpg')))
              .take(5)
              .toList();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recentlyCompleted.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No completed games yet',
                      style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                    ),
                  )
                else
                  FutureBuilder<List<MockGame>>(
                    future: _similarGamesFuture ?? Future.value(const []),
                    builder: (context, similarSnapshot) {
                      if (similarSnapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.accentPurple),
                          ),
                        );
                      }

                      final similarGames = similarSnapshot.data ?? const <MockGame>[];
                      final libraryIds = libraryGames.map((game) => game.id).toSet();
                      final filteredSimilarGames = similarGames
                          .where((game) => !libraryIds.contains(game.id))
                          .toList();
                      final sourceTitle = _lastCompletedGameTitle ?? 'your last completed game';

                      return _HorizontalGameSection(
                        title: 'Because you liked "$sourceTitle"',
                        games: filteredSimilarGames.take(10).toList(),
                        rightPadding: 40,
                      );
                    },
                  ),
                _HorizontalGameSection(
                  title: 'Trending Now',
                  games: trending,
                ),
                _HorizontalGameSection(
                  title: 'Hidden Gems 💎',
                  games: hiddenGems,
                  showBadge: true,
                ),
                _HorizontalGameSection(
                  title: 'Top in RPG',
                  games: topRpg,
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  List<MockGame> _gamesForTitles(List<MockGame> games, List<String> titles) {
    return [
      for (final title in titles) ...games.where((game) => game.title == title),
    ];
  }
}

class _HorizontalGameSection extends StatelessWidget {
  const _HorizontalGameSection({
    required this.title,
    required this.games,
    this.showBadge = false,
    this.rightPadding = 20,
  });

  final String title;
  final List<MockGame> games;
  final bool showBadge;
  final double rightPadding;

  @override
  Widget build(BuildContext context) {
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
                return _DiscoverGameCard(game: games[index], showBadge: showBadge)
                    .paddingOnly(right: 12);
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
  const _DiscoverGameCard({required this.game, this.showBadge = false});

  final MockGame game;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => detail.GameDetailScreen(game: game)),
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
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
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
