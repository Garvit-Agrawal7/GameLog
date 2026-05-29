import 'package:flutter/material.dart';

import '../igdb_service.dart';
import '../mock/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/game_cover_card.dart';
import '../widgets/genre_chip.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_column.dart';
import 'game_detail_screen.dart';
import 'add_game_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.service});

  final IgdbService? service;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<MockGame>> _gamesFuture;

  @override
  void initState() {
    super.initState();
    _gamesFuture = (widget.service ?? IgdbService()).enrichGames(mockGames);
  }

  void _showStub(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label tapped')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
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
           final completedGames = games.where((game) => game.rating >= 85).take(4).toList();
           final recommendedGame = _findByTitle(games, 'Horizon Zero Dawn') ?? games.firstOrNull;

          if (recommendedGame == null) {
            return const Center(
              child: Text('No games available'),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, PlayerOne!',
                          style: AppTextStyles.caption.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.86,
                          child: RichText(
                            text: TextSpan(
                              style: AppTextStyles.display.copyWith(height: 1.18),
                              children: const [
                                TextSpan(text: 'What game will you\nplay '),
                                TextSpan(
                                  text: 'next',
                                  style: TextStyle(color: AppColors.accentPurple),
                                ),
                                TextSpan(text: '?'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () => showAddGameModal(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bg2.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppColors.textMuted, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Search games...',
                            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SectionHeader(
                  title: 'Recommended for you',
                  actionLabel: 'See all',
                  onTap: () => _showStub('See all recommendations'),
                  leading: const Icon(Icons.auto_awesome_rounded, color: AppColors.accentPurple),
                ),
                const SizedBox(height: 16),
                _RecommendationCard(game: recommendedGame),
                const SizedBox(height: 28),
                SectionHeader(
                  title: 'Recently Completed',
                  actionLabel: 'View all',
                  onTap: () => _showStub('View all completed'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: completedGames.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      return GameCoverCard(game: completedGames[index]);
                    },
                  ),
                ),
                const SizedBox(height: 28),
                SectionHeader(
                  title: 'Your Stats',
                  actionLabel: 'This year',
                  onTap: () => _showStub('Year filter'),
                  leading: const Icon(Icons.bar_chart_rounded, color: AppColors.accentPurple),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.bg1,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      StatColumn(
                        icon: Icons.sports_esports_rounded,
                        iconColor: AppColors.accentPurple,
                        value: 24,
                        label1: 'Games',
                        label2: 'Completed',
                      ),
                      StatColumn(
                        icon: Icons.access_time_rounded,
                        iconColor: AppColors.accentBlue,
                        value: 230,
                        label1: 'Hours',
                        label2: 'Played',
                      ),
                      StatColumn(
                        icon: Icons.emoji_events_rounded,
                        iconColor: AppColors.accentGreen,
                        value: 12,
                        label1: 'Achievements',
                        label2: 'Earned',
                      ),
                      StatColumn(
                        icon: Icons.star_outline_rounded,
                        iconColor: AppColors.accentPurple,
                        value: 4.7,
                        label1: 'Avg.',
                        label2: 'Rating',
                      ),
                    ],
                  ),
                ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  MockGame? _findByTitle(List<MockGame> games, String title) {
    for (final game in games) {
      if (game.title == title) {
        return game;
      }
    }
    return null;
  }
}


class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.game});

  final MockGame game;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GameDetailScreen(game: game)),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bg1,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AppCachedImage(
                imageUrl: game.coverUrl,
                width: 90,
                height: 120,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.title, style: AppTextStyles.title.copyWith(fontSize: 18)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: game.genres.take(3).map((genre) => GenreChip(label: genre)).toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      game.summary,
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
