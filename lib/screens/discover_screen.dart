import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_library_provider.dart';
import '../services/igdb_service.dart';
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
  String _selectedGenre = 'Adventure';
  static const List<String> _allGenres = [
    'Adventure',
    'Arcade',
    'Fighting',
    'Hack and slash/Beat \'em up',
    'Indie',
    'MOBA',
    'Platform',
    'Puzzle',
    'Racing',
    'Role-playing (RPG)',
    'Shooter',
    'Simulator',
    'Sport',
    'Strategy',
    'Tactical',
  ];

  IgdbService get _service => widget.service ?? ref.read(igdbServiceProvider);

  @override
  void initState() {
    super.initState();
    _trendingFuture = _service
        .fetchTrendingGames(limit: 50)
        .catchError((_) => <GameModal>[]);
    _upcomingFuture = _service.fetchUpcomingGames().catchError(
          (_) => <GameModal>[],
    );
    _topGenreFuture = _service
        .fetchByGenre('Adventure', limit: 50)
        .catchError((_) => <GameModal>[]
    );
  }

  void _onGenreSelected(String genre) {
    if (_selectedGenre == genre) return;
    setState(() {
      _selectedGenre = genre;
      _topGenreFuture = _service.fetchByGenre(genre, limit: 50).catchError((_) => <GameModal>[]);
    });
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
                FutureBuilder<List<GameModal>>(
                  future: _topGenreFuture,
                  builder: (context, topGenreSnapshot) {
                    final isLoading =
                        topGenreSnapshot.connectionState != ConnectionState.done;
                    final genreGames = (topGenreSnapshot.data ?? [])
                        .where((g) => !libraryIds.contains(g.id))
                        .take(10)
                        .toList();

                    return _HorizontalGameSection(
                      title: 'Top in ',
                      games: genreGames,
                      isLoading: isLoading,
                      headerOverride: _GenrePickerHeader(
                        currentGenre: _selectedGenre,
                        allGenres: _allGenres,
                        onGenreSelected: _onGenreSelected,
                      ),
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
    required this.games,
    this.title,
    this.rightPadding = 20,
    this.showRating = true,
    this.headerOverride,
    this.isLoading = false,
  });

  final String? title;
  final List<GameModal> games;
  final double rightPadding;
  final bool showRating;
  final Widget? headerOverride;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && games.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, rightPadding, 0),
            child:
            headerOverride ??
              _DiscoverSectionHeader(title: title!,),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: isLoading
                ? _ShimmerEffect(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                padding: const EdgeInsets.only(left: 20),
                itemBuilder: (context, index) {
                  return const _ShimmerGameCard().paddingOnly(right: 12);
                },
              ),
            )
                : ListView.builder(
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

class _ShimmerEffect extends StatefulWidget {
  const _ShimmerEffect({required this.child});

  final Widget child;

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                AppColors.bg1.withValues(alpha: 0.55),
                AppColors.bg2.withValues(alpha: 0.18),
                AppColors.bg1.withValues(alpha: 0.55),
              ],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-3 + t * 6, 0),
              end: Alignment(-1 + t * 6, 0),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _ShimmerGameCard extends StatelessWidget {
  const _ShimmerGameCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 130,
            height: 170,
            decoration: BoxDecoration(
              color: AppColors.bg1,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 90,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.bg1,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 50,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.bg1,
              borderRadius: BorderRadius.circular(4),
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

class _GenrePickerHeader extends StatelessWidget {
  const _GenrePickerHeader({
    required this.currentGenre,
    required this.allGenres,
    required this.onGenreSelected,
  });

  final String currentGenre;
  final List<String> allGenres;
  final ValueChanged<String> onGenreSelected;

  void _showGenreMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
    Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset offset = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    late OverlayEntry entry;
    final scrollController = ScrollController();
    final focusNode = FocusNode(debugLabel: 'genreMenu');

    final thumbFractionNotifier = ValueNotifier<double>(0.0);
    final thumbExtentNotifier = ValueNotifier<double>(1.0);

    bool isOpen = true;

    ScrollPosition? ancestorScrollPosition;
    try {
      ancestorScrollPosition = Scrollable.of(context).position;
    } catch (_) {
      ancestorScrollPosition = null;
    }

    void close() {
      if (!isOpen) return;
      isOpen = false;
      ancestorScrollPosition?.removeListener(close);
      scrollController.dispose();
      focusNode.dispose();
      entry.remove();
    }

    ancestorScrollPosition?.addListener(close);

    void updateThumb() {
      if (!scrollController.hasClients) return;
      final pos = scrollController.position;
      final viewport = pos.viewportDimension;
      final maxScroll = pos.maxScrollExtent;
      final contentSize = viewport + maxScroll;

      thumbExtentNotifier.value = contentSize <= 0
          ? 1.0
          : (viewport / contentSize).clamp(0.08, 1.0);
      thumbFractionNotifier.value =
      maxScroll <= 0 ? 0.0 : (pos.pixels / maxScroll).clamp(0.0, 1.0);
    }

    scrollController.addListener(updateThumb);

    entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: close,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            left: offset.dx,
            top: offset.dy + button.size.height + 4,
            width: 260,
            child: Focus(
              focusNode: focusNode,
              onFocusChange: (hasFocus) {
                if (!hasFocus) close();
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      AppColors.accentPurple.withValues(alpha: 0.06),
                      AppColors.bg1.withValues(alpha: 0.95),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accentPurple.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          updateThumb();
                        });

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                controller: scrollController,
                                itemCount: allGenres.length,
                                itemBuilder: (context, index) {
                                  final genre = allGenres[index];

                                  return ListTile(
                                    title: Text(genre),
                                    trailing: genre == currentGenre
                                        ? const Icon(
                                      Icons.check,
                                      color: AppColors.accentPurple,
                                    )
                                        : null,
                                    onTap: () {
                                      onGenreSelected(genre);
                                      close();
                                    },
                                  );
                                },
                              ),
                            ),
                            Container(
                              width: 16,
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.arrow_drop_up,
                                    size: 16,
                                    color: AppColors.accentPurple
                                        .withValues(alpha: 0.6),
                                  ),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final trackHeight =
                                            constraints.maxHeight;

                                        return Stack(
                                          children: [
                                            Center(
                                              child: Container(
                                                width: 1,
                                                height: trackHeight,
                                                decoration: BoxDecoration(
                                                  color: AppColors.accentPurple
                                                      .withValues(alpha: 0.10),
                                                  borderRadius:
                                                  BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                            AnimatedBuilder(
                                              animation: Listenable.merge([
                                                thumbFractionNotifier,
                                                thumbExtentNotifier,
                                              ]),
                                              builder: (context, _) {
                                                final extentFraction =
                                                    thumbExtentNotifier.value;
                                                final scrollFraction =
                                                    thumbFractionNotifier.value;
                                                final thumbHeight = trackHeight *
                                                    extentFraction;
                                                final maxThumbTravel =
                                                    trackHeight - thumbHeight;
                                                final thumbTop = maxThumbTravel *
                                                    scrollFraction;

                                                return Positioned(
                                                  top: thumbTop,
                                                  left: 0,
                                                  right: 0,
                                                  child: Center(
                                                    child: Container(
                                                      width: 5,
                                                      height: thumbHeight,
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .accentPurple
                                                            .withValues(
                                                            alpha: 0.55),
                                                        borderRadius:
                                                        BorderRadius
                                                            .circular(2),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    size: 16,
                                    color: AppColors.accentPurple
                                        .withValues(alpha: 0.6),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(entry);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showGenreMenu(buttonContext),
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: AppTextStyles.title,
              children: [
                const TextSpan(text: 'Top in '),
                TextSpan(
                  text: currentGenre,
                  style: const TextStyle(color: AppColors.accentPurple),
                ),
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.accentPurple,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
