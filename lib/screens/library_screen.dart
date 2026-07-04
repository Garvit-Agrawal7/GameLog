import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_library_provider.dart';
import '../game_modal.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_cached_image.dart';
import 'import_dialog.dart';
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
        appBar: AppBar(
          title: const Text('My Games'),
          toolbarHeight: 52,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: IconButton(
                tooltip: 'Import games',
                icon: const Icon(Icons.file_upload_outlined, size: 20),
                color: AppColors.accentPurple,
                onPressed: () => showImportGamesDialog(context),
              ),
            ),
          ],
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accentPurple),
        ),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: AppColors.bg0,
        appBar: AppBar(
          title: const Text('My Games'),
          toolbarHeight: 52,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: IconButton(
                tooltip: 'Import games',
                icon: const Icon(Icons.file_upload_outlined, size: 20),
                color: AppColors.accentPurple,
                onPressed: () => showImportGamesDialog(context),
              ),
            ),
          ],
        ),
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
  _LibraryDisplayMode _displayMode = _LibraryDisplayMode.list;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        title: const Text('My Games'),
        toolbarHeight: 40,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              tooltip: 'Import games',
              icon: const Icon(Icons.file_upload_outlined, size: 20),
              color: AppColors.accentPurple,
              onPressed: () => showImportGamesDialog(context),
            ),
          ),
        ],
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
            _LibraryGrid(
            status: 'all',
            games: widget.games,
            selectedMode: _displayMode,
            onModeChanged: (mode) => setState(() => _displayMode = mode),
          ),
          _LibraryGrid(
            status: 'playing',
            games: widget.games,
            selectedMode: _displayMode,
            onModeChanged: (mode) => setState(() => _displayMode = mode),
          ),
          _LibraryGrid(
            status: 'completed',
            games: widget.games,
            selectedMode: _displayMode,
            onModeChanged: (mode) => setState(() => _displayMode = mode),
          ),
          _LibraryGrid(
            status: 'paused',
            games: widget.games,
            selectedMode: _displayMode,
            onModeChanged: (mode) => setState(() => _displayMode = mode),
          ),
          _LibraryGrid(
            status: 'backlog',
            games: widget.games,
            selectedMode: _displayMode,
            onModeChanged: (mode) => setState(() => _displayMode = mode),
          ),
          _LibraryGrid(
            status: 'wishlist',
            games: widget.games,
            selectedMode: _displayMode,
            onModeChanged: (mode) => setState(() => _displayMode = mode),
          ),
          _LibraryGrid(
            status: 'dropped',
            games: widget.games,
            selectedMode: _displayMode,
            onModeChanged: (mode) => setState(() => _displayMode = mode),
          ),
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

enum _LibraryDisplayMode { list, tab }

class _LibraryGrid extends StatefulWidget {
  const _LibraryGrid({
    required this.status,
    required this.games,
    required this.selectedMode,
    required this.onModeChanged,
  });

  final String status;
  final List<GameModal> games;
  final _LibraryDisplayMode selectedMode;
  final ValueChanged<_LibraryDisplayMode> onModeChanged;

  @override
  State<_LibraryGrid> createState() => _LibraryGridState();
}

class _LibraryGridState extends State<_LibraryGrid> with AutomaticKeepAliveClientMixin {
  _SortOption _sortOption = _SortOption.alphabetical;

  @override
  void initState() {
    super.initState();
    if (widget.status == 'all') {
      _sortOption = _SortOption.status;
    }
  }

  @override
  bool get wantKeepAlive => true;

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
      return const [
        _SortOption.status,
        _SortOption.alphabetical,
        _SortOption.score,
        _SortOption.recency,
      ];
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
    super.build(context);
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

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ViewModeToggle(
                  selectedMode: widget.selectedMode,
                  onChanged: widget.onModeChanged,
                ),
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gamepad_outlined, size: 17, color: AppColors.accentPurple),
                        const SizedBox(width: 4),
                        Text(
                          '${filteredGames.length} ${filteredGames.length == 1 ? 'entry' : 'entries'}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.accentPurple,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Builder(
                  builder: (buttonContext) {
                    return SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showSortMenu(buttonContext),
                        icon: const Icon(Icons.sort_rounded, size: 18, color: AppColors.accentPurple),
                        tooltip: 'Sort games',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        if (widget.selectedMode == _LibraryDisplayMode.list)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.separated(
              itemCount: sortedGames.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _LibraryGameCard(game: sortedGames[index]),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.54,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _LibraryGameCard(
                  game: sortedGames[index],
                  compact: true,
                ),
                childCount: sortedGames.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({
    required this.selectedMode,
    required this.onChanged,
  });

  final _LibraryDisplayMode selectedMode;
  final ValueChanged<_LibraryDisplayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewModeButton(
            icon: Icons.view_list_rounded,
            selected: selectedMode == _LibraryDisplayMode.list,
            onTap: () => onChanged(_LibraryDisplayMode.list),
            tooltip: 'List view',
          ),
          const SizedBox(width: 4),
          _ViewModeButton(
            icon: Icons.grid_view_rounded,
            selected: selectedMode == _LibraryDisplayMode.tab,
            onTap: () => onChanged(_LibraryDisplayMode.tab),
            tooltip: 'Tab view',
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentPurple.withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              icon,
              size: 18,
              color: selected ? AppColors.accentPurple : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryGameCard extends ConsumerWidget {
  const _LibraryGameCard({required this.game, this.compact = false});

  final GameModal game;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) {
      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GameDetailScreen(game: game),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AppCachedImage(
                        imageUrl: game.coverUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(child: _StatusBadgeIcon(status: game.status)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: Text(
                game.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.title.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }

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
                        child: _GenrePill(text: game.genres[0]),
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
                        const Icon(Icons.star_rounded, color: AppColors.warning, size: 20),
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

class _StatusBadgeIcon extends StatelessWidget {
  const _StatusBadgeIcon({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'playing' => Colors.greenAccent[400],
      'completed' => Colors.lightBlueAccent,
      'paused' => Color.lerp(Colors.orangeAccent, Colors.yellowAccent, 0.2),
      'backlog' => Colors.deepPurpleAccent,
      'wishlist' => Colors.pinkAccent,
      'dropped' => Colors.redAccent,
      _ => AppColors.accentPurple,
    };

    final icon = switch (status) {
      'wishlist' => Icons.favorite,
      'playing' => Icons.play_arrow_rounded,
      'completed' => Icons.sports_esports_rounded,
      'paused' => Icons.pause_circle_filled_rounded,
      'dropped' => Icons.do_not_disturb_alt_rounded,
      'backlog' => Icons.sports_esports_outlined,
      _ => Icons.view_list_rounded,
    };

    return Icon(
      icon,
      color: color,
      size: 18,
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

    final indicator = switch (status) {
      'wishlist' => Icon(Icons.favorite, size: 12, color: color),
      'playing' => Icon(Icons.play_arrow_rounded, size: 12, color: color),
      'completed' => Icon(Icons.sports_esports_rounded, size: 12, color: color),
      'paused' => Icon(Icons.pause_circle_filled_rounded, size: 12, color: color),
      'dropped' => Icon(Icons.do_not_disturb_alt_rounded, size: 12, color: color),
      'backlog' => Icon(Icons.sports_esports_outlined, size: 12, color: color),
      _ => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    };

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

class _GenrePill extends StatelessWidget {
  const _GenrePill({required this.text});

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
