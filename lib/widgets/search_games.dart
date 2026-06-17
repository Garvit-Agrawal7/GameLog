import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../database/database_providers.dart';
import '../igdb_service.dart';
import '../game_modal.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:my_game_list/screens/game_detail_screen.dart';
import 'package:my_game_list/screens/add_game_modal.dart';

class SearchGamesWidget extends ConsumerStatefulWidget {
  const SearchGamesWidget({
    required this.controller,
    required this.service,
    required this.ref,
    this.showBackButton = false,
    this.onBackPressed,
  });

  final TextEditingController controller;
  final IgdbService service;
  final WidgetRef ref;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  @override
  ConsumerState<SearchGamesWidget> createState() => _SearchGamesWidgetState();
}

class _SearchGamesWidgetState extends ConsumerState<SearchGamesWidget> {
  late Future<List<String>> _historyFuture;
  Future<List<GameModal>>? _searchFuture;
  Timer? _searchDebounce;
  Timer? _historyDebounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _historyDebounce?.cancel();
    super.dispose();
  }

  Future<List<String>> _loadSearchHistory() {
    return widget.ref.read(searchHistoryProvider.future);
  }

  Future<List<GameModal>> _loadSearchResults(String query) async {
    return widget.service.searchGames(query, limit: 50);
  }

  Future<void> _saveSearchQuery(String query) async {
    final database = await widget.ref.read(databaseProvider.future);
    await database.searchHistoryDao.saveSearchQuery(query);
    widget.ref.invalidate(searchHistoryProvider);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _historyDebounce?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _query = '';
        _searchFuture = null;
        _historyFuture = _loadSearchHistory();
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || query == _query) {
        return;
      }

      setState(() {
        _query = query;
        _searchFuture = _loadSearchResults(query);
      });
    });

    _historyDebounce = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      _saveSearchQuery(query);
    });
  }

  void _searchHistoryItem(String query) {
    widget.controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _onSearchChanged(query);
  }

  Future<void> _openStatusSheet(GameModal game) {
    return showStatusSelectionSheet(context, game, widget.ref);
  }

  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(color: AppColors.accentPurple),
      ),
    );
  }

  Widget _buildHistoryList(List<String> history) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No recent searches',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final query = history[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
          leading: const Icon(Icons.history_rounded, color: AppColors.textMuted),
          title: Text(
            query,
            style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
          ),
          trailing: const Icon(
            Icons.north_east_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
          onTap: () => _searchHistoryItem(query),
        );
      },
    );
  }

  Widget _buildSearchResults(List<GameModal> games) {
    if (games.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No games found',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: games.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final game = games[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: game.coverUrl,
              width: 56,
              height: 72,
              fit: BoxFit.cover,
              placeholder: (_, _) => Shimmer.fromColors(
                baseColor: AppColors.bg1,
                highlightColor: AppColors.bg2,
                child: Container(color: AppColors.bg1),
              ),
              errorWidget: (_, _, _) => Container(
                width: 56,
                height: 72,
                color: AppColors.bg2,
                alignment: Alignment.center,
                child: const Icon(Icons.games_rounded, color: AppColors.textMuted),
              ),
            ),
          ),
          title: Text(
            game.title,
            style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
          ),
          subtitle: Text(
            '${game.year} - ${game.genres.isNotEmpty ? game.genres.first : 'N/A'}',
            style: AppTextStyles.caption,
          ),
          trailing: GestureDetector(
            onTap: () => _openStatusSheet(game),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.add, color: AppColors.accentPurple, size: 18),
            ),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GameDetailScreen(game: game),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.showBackButton) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackPressed,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 18),
            ],
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: widget.controller,
                  onChanged: _onSearchChanged,
                  textAlignVertical: TextAlignVertical.center,
                  style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  cursorColor: AppColors.accentPurple,
                  decoration: InputDecoration(
                    hintText: 'Search games...',
                    hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_query.isEmpty)
          FutureBuilder<List<String>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _buildLoading();
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading search history',
                      style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                );
              }
              return _buildHistoryList(snapshot.data ?? const []);
            },
          )
        else
          FutureBuilder<List<GameModal>>(
            future: _searchFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _buildLoading();
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      snapshot.error is IgdbRateLimitException
                          ? (snapshot.error as IgdbRateLimitException).message
                          : 'Error loading games',
                      style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                );
              }
              return _buildSearchResults(snapshot.data ?? const []);
            },
          ),
      ],
    );
  }
}
