import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../database/database_providers.dart';
import '../game_library_provider.dart';
import '../services/igdb_service.dart';
import '../services/auth_service.dart';
import '../game_modal.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/game_cover_card.dart';
import '../widgets/genre_chip.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_column.dart';
import 'auth_screen.dart';
import 'game_detail_screen.dart';
import 'search_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.service, this.onViewCompletedGames});

  final IgdbService? service;
  final VoidCallback? onViewCompletedGames;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecommendation();
    });
  }

  Future<GameModal?>? _recommendedFuture;
  String? _lastTopGenre;

  IgdbService get _service => widget.service ?? ref.read(igdbServiceProvider);

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'logout':
        await ref.read(authProvider.notifier).clearSession();
        ref.invalidate(gameLibraryProvider);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
        break;
      case 'download':
        await _downloadGameData();
        break;
    }
  }

  Future<void> _downloadGameData() async {
    final libraryGames = ref.read(libraryGamesProvider);
    final export = {
      'exported_at': DateTime.now().toIso8601String(),
      'games': libraryGames
          .map(
            (game) => {
              'id': game.id,
              'title': game.title,
              'cover_url': game.coverUrl,
              'genres': game.genres,
              'summary': game.summary,
              'rating': game.rating,
              'hours_played': game.hoursPlayed,
              'time_to_beat_hours': game.timeToBeatHours,
              'status': game.status,
              'user_rating': game.userRating,
              'year': game.year,
              'in_library': game.inLibrary,
              'last_updated': game.lastUpdated,
            },
          )
          .toList(),
    };
    final file = File(
      '/storage/emulated/0/Download/gamelog_library_export.json',
    );
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(export));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Game data saved to ${file.path}'),
      ),
    );
  }

  Future<GameModal?> _fetchRecommendation(
    String genre,
    Set<int> libraryIds,
  ) async {
    final candidates = await _service.fetchByGenre(genre, limit: 50);
    final filtered = candidates.where((g) => !libraryIds.contains(g.id)).toList();
    if (filtered.isEmpty) return null;

    final picked = filtered[Random().nextInt(filtered.length)];
    final ttb = await _service.fetchTimeToBeat(picked.id);
    return picked.copyWith(timeToBeatHours: ttb);
  }

  void _loadRecommendation() {
    final libraryGames = ref.read(libraryGamesProvider);
    final libraryIds = libraryGames.map((g) => g.id).toSet();

    final genre = ref.read(topGenreProvider) ?? _lastTopGenre;

    if (genre == null) return;

    _lastTopGenre = genre;

    setState(() {
      _recommendedFuture = _fetchRecommendation(
        genre,
        libraryIds,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final recentlyCompleted = ref.watch(recentlyCompletedProvider);
    final libraryGames = ref.watch(libraryGamesProvider);
    libraryGames.map((g) => g.id).toSet();
    final topGenre = ref.watch(topGenreProvider);

    final statsAsync = ref.watch(libraryStatsProvider);
    final stats = statsAsync.when(
      data: (value) => value,
      loading: () => LibraryStats.empty(),
      error: (_, __) => LibraryStats.empty(),
    );

    if (topGenre != null && topGenre != _lastTopGenre) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRecommendation();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
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
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.menu_rounded,
                        color: AppColors.textPrimary,
                      ),
                      color: AppColors.bg1,
                      onSelected: _handleMenuAction,
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'logout',
                          child: Text('Log out'),
                        ),
                        PopupMenuItem<String>(
                          value: 'download',
                          child: Text('Download Game Data'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bg2.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: AppColors.textMuted,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Search games...',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                if (libraryGames.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Recommended for you',
                    actionLabel: 'New Game',
                    onTap: () => _loadRecommendation(),
                  ),
                  const SizedBox(height: 16),

                  FutureBuilder<GameModal?>(
                    future: _recommendedFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const _RecommendationCard(isLoading: true);
                      }

                      if (snapshot.hasError) {
                        return const Text('Failed to load recommendation');
                      }

                      if (!snapshot.hasData) {
                        return const Text('No recommendations available');
                      }

                      return _RecommendationCard(game: snapshot.data!, onReturn: _loadRecommendation,);
                    },
                  ),
                  const SizedBox(height: 28),
                ],
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
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textMuted,
                        ),
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
                  leading: const Icon(
                    Icons.bar_chart_rounded,
                    color: AppColors.accentPurple,
                  ),
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
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({this.game, this.isLoading = false, this.onReturn,});

  final GameModal? game;
  final bool isLoading;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Shimmer.fromColors(
        baseColor: AppColors.bg1,
        highlightColor: AppColors.bg2,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.bg1,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 90,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 20,
                      width: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: List.generate(
                        3,
                        (_) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            width: 60,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      height: 12,
                      width: double.infinity,
                      color: Colors.white,
                    ),

                    const SizedBox(height: 8),

                    Container(height: 12, width: 200, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final game = this.game!;

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameDetailScreen(game: game),
          ),
        );
        onReturn?.call();
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
                    Text(
                      game.title,
                      style: AppTextStyles.title.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: game.genres
                          .take(2)
                          .map((genre) => GenreChip(label: genre))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      game.summary,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
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
