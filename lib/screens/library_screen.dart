import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_library_provider.dart';
import '../game_modal.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_cached_image.dart';
import 'game_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({
    super.key,
    this.initialTabIndex = 0,
    this.animateToInitialTab = false,
  });

  final int initialTabIndex;
  final bool animateToInitialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the async game library provider
    final gamesAsync = ref.watch(gameLibraryProvider);

    return gamesAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.bg0,
        appBar: AppBar(title: const Text('My Games')),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accentPurple),
        ),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: AppColors.bg0,
        appBar: AppBar(title: const Text('My Games')),
        body: Center(
          child: Text(
            'Error loading library: $error',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
        ),
      ),
      data: (games) => DefaultTabController(
        length: 7,
        initialIndex: animateToInitialTab ? 0 : initialTabIndex,
        child: _LibraryTabScaffold(
          games: games,
          targetTabIndex: initialTabIndex,
          animateToTarget: animateToInitialTab,
        ),
      ),
    );
  }
}

class _LibraryTabScaffold extends StatefulWidget {
  const _LibraryTabScaffold({
    required this.games,
    required this.targetTabIndex,
    required this.animateToTarget,
  });

  final List<GameModal> games;
  final int targetTabIndex;
  final bool animateToTarget;

  @override
  State<_LibraryTabScaffold> createState() => _LibraryTabScaffoldState();
}

class _LibraryTabScaffoldState extends State<_LibraryTabScaffold> {
  bool _animationScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_animationScheduled || !widget.animateToTarget || widget.targetTabIndex == 0) {
      return;
    }

    _animationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      DefaultTabController.of(context).animateTo(
        widget.targetTabIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        title: const Text('My Games'),
        bottom: TabBar(
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          labelStyle: AppTextStyles.label.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accentPurple,
          tabs: const [
            SizedBox(width: 110, child: Tab(text: 'All Games')),
            SizedBox(width: 96, child: Tab(text: 'Playing')),
            SizedBox(width: 112, child: Tab(text: 'Completed')),
            SizedBox(width: 88, child: Tab(text: 'Paused')),
            SizedBox(width: 100, child: Tab(text: 'Backlog')),
            SizedBox(width: 100, child: Tab(text: 'Wishlist')),
            SizedBox(width: 92, child: Tab(text: 'Dropped')),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _LibraryGrid(status: 'all', games: widget.games),
          _LibraryGrid(status: 'playing', games: widget.games),
          _LibraryGrid(status: 'completed', games: widget.games),
          _LibraryGrid(status: 'wishlist', games: widget.games),
          _LibraryGrid(status: 'paused', games: widget.games),
          _LibraryGrid(status: 'backlog', games: widget.games),
          _LibraryGrid(status: 'dropped', games: widget.games),
        ],
      ),
    );
  }
}

enum _SortOption { alphabetical, score, status, recency }

extension on _SortOption {
  String get label => switch (this) {
    _SortOption.alphabetical => 'Alphabetical',
    _SortOption.score => 'Score',
    _SortOption.status => 'Status',
    _SortOption.recency => 'Last Updated',
  };
}

class _LibraryGrid extends StatefulWidget {
  const _LibraryGrid({required this.status, required this.games});

  final String status;
  final List<GameModal> games;

  @override
  State<_LibraryGrid> createState() => _LibraryGridState();
}

class _LibraryGridState extends State<_LibraryGrid> {
  _SortOption _sortOption = _SortOption.alphabetical;

  List<GameModal> _filteredGames() {
    return widget.status == 'all'
        ? widget.games.where((g) => g.inLibrary).toList()
        : widget.games.where((g) => g.status == widget.status && g.inLibrary).toList();
  }

  List<GameModal> _sortedGames(List<GameModal> games) {
    final sorted = List<GameModal>.from(games);
    switch (_sortOption) {
      case _SortOption.recency:
        sorted.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        break;
      case _SortOption.alphabetical:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _SortOption.score:
        sorted.sort((a, b) {
          final hasRatingA = a.userRating != null;
          final hasRatingB = b.userRating != null;

          if (hasRatingA != hasRatingB) {
            return hasRatingA ? -1 : 1;
          }

          if (hasRatingA) {
            return b.userRating!.compareTo(a.userRating!);
          }

          if (widget.status == 'all') {
            const order = ['playing', 'completed', 'paused', 'backlog', 'wishlist', 'dropped'];
            final indexA = order.indexOf(a.status ?? '');
            final indexB = order.indexOf(b.status ?? '');
            if (indexA != indexB) {
              return indexA.compareTo(indexB);
            }
            return b.rating.compareTo(a.rating);
          }

          return b.rating.compareTo(a.rating);
        });
        break;
      case _SortOption.status:
        const order = ['playing', 'completed', 'paused', 'backlog', 'wishlist', 'dropped'];
        sorted.sort((a, b) {
          final indexA = order.indexOf(a.status ?? '');
          final indexB = order.indexOf(b.status ?? '');
          return indexA.compareTo(indexB);
        });
        break;
    }
    return sorted;
  }

  List<_SortOption> get _availableOptions {
    if (widget.status == 'all') {
      return _SortOption.values;
    }
    return _SortOption.values.where((o) => o != _SortOption.status).toList();
  }

  void _showSortMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<_SortOption>(
      context: context,
      position: position,
      color: AppColors.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      popUpAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 180),
        reverseDuration: const Duration(milliseconds: 140),
        curve: Curves.easeOutSine,
        reverseCurve: Curves.easeInSine,
      ),
      items: [
        for (final option in _availableOptions)
          PopupMenuItem<_SortOption>(
            value: option,
            child: Row(
              children: [
                Icon(
                  option == _sortOption
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: option == _sortOption
                      ? AppColors.accentPurple
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  option.label,
                  style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
      ],
    );

    if (selected != null) {
      setState(() => _sortOption = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredGames = _filteredGames();

    if (filteredGames.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_esports_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No games here yet.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final sortedGames = _sortedGames(filteredGames);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gamepad_outlined, size: 18, color: AppColors.accentPurple),
                  const SizedBox(width: 6),
                  Text(
                    '${filteredGames.length} ${filteredGames.length == 1 ? 'entry' : 'entries'}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accentPurple,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (buttonContext) {
                  return SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showSortMenu(buttonContext),
                      icon: const Icon(Icons.sort_rounded, size: 20, color: AppColors.accentPurple),
                      tooltip: 'Sort games',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sortedGames.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _LibraryGameCard(game: sortedGames[index]),
          ),
        ),
      ],
    );
  }
}

class _LibraryGameCard extends ConsumerWidget {
  const _LibraryGameCard({required this.game});

  final GameModal game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameDetailScreen(game: game),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.bg1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 90,
                child: AppCachedImage(
                  imageUrl: game.coverUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                      child: Text(
                        game.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(fontSize: 16),
                      ),
                    ),
                    if (game.status != null) Row(children: [_StatusPill(status: game.status!)]),
                    if (game.genres.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0, left: 4.0),
                        child: _DetailPill(text: game.genres[0]),
                      ),
                  ],
                ),
              ),
            ),
            if (game.userRating != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                child: SizedBox(
                  height: 90,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.textPrimary, size: 20),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 20,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${game.userRating}',
                              textAlign: TextAlign.left,
                              style: AppTextStyles.label.copyWith(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'playing' => 'Playing',
      'completed' => 'Completed',
      'wishlist' => 'Wishlist',
      'paused' => 'Paused',
      'backlog' => 'Backlog',
      'dropped' => 'Dropped',
      _ => status,
    };

    final color = switch (status) {
      'playing' => Colors.greenAccent[400],
      'completed' => Colors.lightBlueAccent,
      'paused' => Color.lerp(Colors.orangeAccent, Colors.yellowAccent, 0.2),
      'backlog' => Colors.deepPurpleAccent,
      'wishlist' => Colors.pinkAccent,
      'dropped' => Colors.redAccent,
      _ => AppColors.accentPurple,
    };

    final indicator = status == 'wishlist'
        ? Icon(Icons.favorite, size: 12, color: color)
        : Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );

    final labelColor = status == 'wishlist' ? AppColors.textPrimary : color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        indicator,
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(color: AppColors.accentPurple),
      ),
    );
  }
}
