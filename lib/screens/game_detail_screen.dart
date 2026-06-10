import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_library_provider.dart';
import '../igdb_service.dart';
import '../database/app_database.dart';
import '../mock/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/genre_chip.dart';
import '../widgets/gradient_button.dart';
import 'add_game_modal.dart';

String heroCoverImageUrl(String imageUrl) {
  if (imageUrl.contains('/t_cover_big/')) {
    return imageUrl.replaceFirst('/t_cover_big/', '/t_1080p/');
  }

  if (imageUrl.contains('/t_cover_big_2x/')) {
    return imageUrl.replaceFirst('/t_cover_big_2x/', '/t_1080p/');
  }

  return imageUrl;
}

class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({super.key, required this.game});

  final MockGame game;

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  late final Future<MockGame> _gameFuture;

  @override
  void initState() {
    super.initState();
    _gameFuture = _buildGameFuture();
  }

  Future<MockGame> _buildGameFuture() async {
    // Enrich the incoming game with IGDB data first
    final enriched = (await IgdbService().enrichGames([widget.game])).first;

    try {
      // Check the local database for a stored entry for this game id.
      final db = AppDatabase();
      await db.init();
      final gameModel = await db.gamesDao.getGameById(widget.game.id);

      // If a DB entry exists and it has a non-null status, prefer the DB's status
      // and other library-related fields (inLibrary, hoursPlayed, lastUpdated).
      if (gameModel != null && gameModel.status != null) {
        return enriched.copyWith(
          status: gameModel.status,
          inLibrary: gameModel.inLibrary,
          hoursPlayed: gameModel.hoursPlayed,
          timeToBeatHours: gameModel.timeToBeatHours,
          lastUpdated: gameModel.lastUpdated,
        );
      }
    } catch (e) {
      // If DB access fails for any reason, fall back to the enriched data.
      // We avoid failing the whole future because DB issues shouldn't block viewing details.
      // Debug prints are helpful while developing.
      // ignore: avoid_print
      print('DEBUG: error reading DB in GameDetailScreen: $e');
    }

    return enriched;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MockGame>(
      future: _gameFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: AppColors.bg0,
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.accentPurple),
            ),
          );
        }

        if (snapshot.hasError) {
          final displayMsg = snapshot.error is IgdbRateLimitException
              ? (snapshot.error as IgdbRateLimitException).message
              : 'Error loading game';
          return Scaffold(
            backgroundColor: AppColors.bg0,
            appBar: AppBar(
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: AppColors.bg1.withValues(alpha: 0.8),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            body: Center(
              child: Text(
                displayMsg,
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ),
          );
        }

        final game = snapshot.data!;

        return _buildDetailScreen(context, game);
      },
    );
  }

  Widget _buildDetailScreen(BuildContext context, MockGame game) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 545,
            pinned: true,
            backgroundColor: AppColors.bg0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: AppColors.bg1.withValues(alpha: 0.8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 45),
                    child: AppCachedImage(
                      imageUrl: heroCoverImageUrl(game.coverUrl),
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, AppColors.bg0],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.title, style: AppTextStyles.display),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: game.genres.map((genre) => GenreChip(label: genre)).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${(game.rating / 10).toStringAsFixed(2)} / 10',
                        style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time_rounded, color: AppColors.textMuted, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        game.timeToBeatHours == null ? 'Time to beat unavailable' : '${game.timeToBeatHours}h to beat',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    game.summary,
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.55),
                  ),
                   const SizedBox(height: 24),
                   if (game.status == null) ...[
                     GradientButton(
                       label: 'Add to Library',
                       onTap: () => showStatusSelectionSheet(context, game, ref),
                     ),
                   ] else ...[
                     GestureDetector(
                       onTap: () => showStatusSelectionSheet(context, game, ref),
                       child: Container(
                         decoration: BoxDecoration(
                           color: AppColors.bg1,
                           borderRadius: BorderRadius.circular(12),
                         ),
                         padding: const EdgeInsets.all(14),
                         child: Row(
                           children: [
                             Text('Status', style: AppTextStyles.label),
                             const Spacer(),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(
                                 color: AppColors.bg2,
                                 borderRadius: BorderRadius.circular(20),
                               ),
                               child: Text(
                                 game.status == null ? '' : game.status![0].toUpperCase() + game.status!.substring(1),
                                 style: AppTextStyles.label.copyWith(color: AppColors.accentPurple),
                               ),
                             ),
                           ],
                         ),
                       ),
                     ),
                     const SizedBox(height: 8),
                      TextButton(
                        onPressed: () async {
                          await ref.read(gameLibraryProvider.notifier).removeFromLibrary(game.id);
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${game.title} removed from library'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                       },
                       style: TextButton.styleFrom(
                         foregroundColor: AppColors.error,
                         padding: EdgeInsets.zero,
                         alignment: Alignment.centerLeft,
                       ),
                       child: const Text('Remove from Library'),
                     ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
