import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_providers.dart';
import '../game_library_provider.dart';
import '../igdb_service.dart';
import '../game_modal.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/game_cover_card.dart';
import '../widgets/genre_chip.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_column.dart';
import 'game_detail_screen.dart';
import 'add_game_modal.dart';

const List<GameModal> _homeSeedGames = [
  GameModal(
    id: 11,
    title: 'Horizon Zero Dawn',
    coverUrl: 'https://picsum.photos/seed/horizon-zero-dawn/800/1200',
    genres: ['Action', 'RPG', 'Open World'],
    summary:
        'A sprawling open-world adventure where machine hunting and ancient mysteries shape every horizon.',
    rating: 88,
    hoursPlayed: 53,
    year: 2017,
    lastUpdated: '',
  )
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.service, this.onViewCompletedGames});

  final IgdbService? service;
  final VoidCallback? onViewCompletedGames;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final Future<List<GameModal>> _gamesFuture;

  @override
  void initState() {
    super.initState();
    _gamesFuture = (widget.service ?? IgdbService()).enrichGames(_homeSeedGames);
  }

  void _showStub(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label tapped')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch recently completed games and stats from database providers
    final recentlyCompleted = ref.watch(recentlyCompletedProvider);
    final statsAsync = ref.watch(libraryStatsProvider);
    final stats = statsAsync.when(
      data: (value) => value,
      loading: () => LibraryStats.empty(),
      error: (_, __) => LibraryStats.empty(),
    );

    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: FutureBuilder<List<GameModal>>(
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
          final recommendedGame = _findByTitle(games, 'Horizon Zero Dawn') ?? (games.isNotEmpty ? games.first : null);

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
                      onTap: widget.onViewCompletedGames,
                    ),
                    const SizedBox(height: 16),
                    if (recentlyCompleted.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'No completed games yet',
                            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recentlyCompleted.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            return GameCoverCard(game: recentlyCompleted[index]);
                          },
                        ),
                      ),
                    const SizedBox(height: 28),
                    SectionHeader(
                      title: 'Your Stats',
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
                        children: [
                          StatColumn(
                            icon: Icons.play_circle_outline_rounded,
                            iconColor: AppColors.accentGreen,
                            value: stats.playingCount,
                            label1: 'Currently',
                            label2: 'Playing',
                          ),
                          StatColumn(
                            icon: Icons.sports_esports_rounded,
                            iconColor: AppColors.accentPurple,
                            value: stats.completedCount,
                            label1: 'Games',
                            label2: 'Completed',
                          ),
                          StatColumn(
                            icon: Icons.access_time_rounded,
                            iconColor: AppColors.accentBlue,
                            value: stats.totalHours,
                            label1: 'Hours',
                            label2: 'Played',
                          ),
                          StatColumn(
                            icon: Icons.star_outline_rounded,
                            iconColor: AppColors.accentPurple,
                            value: stats.averageRating,
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

  GameModal? _findByTitle(List<GameModal> games, String title) {
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

  final GameModal game;

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
