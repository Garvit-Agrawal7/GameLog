import 'package:flutter/material.dart';

import '../igdb_service.dart';
import 'package:my_game_list/screens/game_detail_screen.dart' as detail;
import '../mock/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/section_header.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, this.service});

  final IgdbService? service;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late final Future<List<MockGame>> _gamesFuture;

  @override
  void initState() {
    super.initState();
    _gamesFuture = (widget.service ?? IgdbService()).enrichGames(mockGames);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(title: const Text('Explore')),
      body: FutureBuilder<List<MockGame>>(
        future: _gamesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentPurple),
            );
          }

          if (snapshot.hasError) {
            final displayMsg = snapshot.error is IgdbRateLimitException
                ? (snapshot.error as IgdbRateLimitException).message
                : 'Error loading games';
            return Center(
              child: Text(
                displayMsg,
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            );
          }

          final games = snapshot.data ?? [];

          final recommendations = games.where((game) => game.rating >= 90).take(5).toList();
          final trending = _gamesForTitles(games, const [
            'Cyberpunk 2077',
            'Baldur\'s Gate 3',
            'Hollow Knight',
            'Black Myth: Wukong',
            'Hades',
          ]);
          final hiddenGems = _gamesForTitles(games, const [
            'Disco Elysium',
            'Alan Wake 2',
            'Hollow Knight',
            'Hades',
            'Horizon Zero Dawn',
          ]);
          final topRpg = games
              .where((game) => game.genres.any((genre) => genre.toLowerCase().contains('rpg')))
              .take(5)
              .toList();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HorizontalGameSection(
                  title: 'Because you liked Elden Ring...',
                  games: recommendations,
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
      for (final title in titles)
        ...games.where((game) => game.title == title),
    ];
  }
}

class _HorizontalGameSection extends StatelessWidget {
  const _HorizontalGameSection({
    required this.title,
    required this.games,
    this.showBadge = false,
  });

  final String title;
  final List<MockGame> games;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader(title: title, actionLabel: 'See all', onTap: () {}),
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
            Stack(
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
              ],
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
