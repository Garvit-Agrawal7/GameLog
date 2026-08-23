import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_library_provider.dart';
import '../game_modal.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/rating_picker.dart';
import '../widgets/status_widgets.dart';
import '../widgets/gradient_button.dart';

class ImportReviewScreen extends ConsumerStatefulWidget {
  const ImportReviewScreen({super.key, required this.payload});

  final Map<String, dynamic> payload;

  @override
  ConsumerState<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends ConsumerState<ImportReviewScreen> {
  static const int _droppedPlaytimeThresholdMinutes = 10;
  static const int _droppedInactiveThresholdDays = 180;
  static const int _playingRecentThresholdDays = 7;

  static const List<String> _statusOptions = [
    'playing',
    'completed',
    'wishlist',
    'paused',
    'backlog',
    'dropped',
  ];

  late List<Map<String, dynamic>> _games;
  late List<bool> _selected;
  late List<int?> _ratings;
  late List<String?> _statuses;

  @override
  void initState() {
    super.initState();
    _games = List<Map<String, dynamic>>.from(widget.payload['games'] as List);
    _selected = List<bool>.filled(_games.length, true);
    _ratings = List<int?>.filled(_games.length, null);
    _statuses = _games.map(_defaultStatusForGame).toList();
  }

  String _defaultStatusForGame(Map<String, dynamic> game) {
    final provider = widget.payload['provider'];
    final playtime = game['playtime_forever'] ?? 0;

    final lastPlayed = game['rtime_last_played'];
    final lastPlayedDate = DateTime.fromMillisecondsSinceEpoch(lastPlayed.toInt() * 1000, isUtc: true);
    final now = DateTime.now().toUtc();

    if (lastPlayed != 0) {
      final daysSinceLastPlayed = now.difference(lastPlayedDate).inDays;

      if (daysSinceLastPlayed <= _playingRecentThresholdDays) {
        return 'playing';
      }

      if (playtime != null && playtime > 0 && playtime < _droppedPlaytimeThresholdMinutes && daysSinceLastPlayed > _droppedInactiveThresholdDays) {
        return 'dropped';
      }
    }

    if (provider == 'xbox') {
      final totalAchievements = game['total_achievements'];
      if (totalAchievements != null) {
        final currentAchievements = game['current_achievements'];
        final progressPercentage = game['progress_percentage'];
        if (currentAchievements == 0 && progressPercentage == 0) {
          return 'backlog';
        }
      }
      return 'completed';
    }

    if (playtime == 0) return 'backlog';
    return 'completed';
  }

  int get _selectedCount => _selected.where((s) => s).length;

  void _toggleSelected(int index) =>
      setState(() => _selected[index] = !_selected[index]);


  Future<void> _addSelectedToLibrary() async {
    final library = ref.read(gameLibraryProvider.notifier);

    for (var i = 0; i < _games.length; i++) {
      if (!_selected[i]) continue;

      final game = _games[i];
      final releaseDate = game['release_date'];
      final releaseYear = releaseDate is num
          ? DateTime.fromMillisecondsSinceEpoch(
              releaseDate.toInt() * 1000,
              isUtc: true,
            ).year
          : DateTime.now().year;
      final playtime = game['playtime_forever'];
      final lastPlayed = game['rtime_last_played'];
      final gameId = game['igdb_id'] is int ? game['igdb_id'] as int : 0;

      final model = GameModal(
        id: gameId,
        title: (game['igdb_name'] ?? game['name'] ?? 'Unknown') as String,
        coverUrl: (game['cover_url'] ?? '') as String,
        genres: List<String>.from((game['genres'] ?? const <String>[]) as List),
        summary: (game['summary'] ?? '') as String,
        rating: (game['rating'] as num?)?.toDouble() ?? 0.0,
        hoursPlayed: playtime is num ? playtime.round() : 0,
        timeToBeatHours: null,
        status: _statuses[i],
        userRating: _ratings[i],
        year: releaseYear,
        inLibrary: true,
        lastUpdated: lastPlayed is num && lastPlayed.toInt() > 0
            ? DateTime.fromMillisecondsSinceEpoch(
                lastPlayed.toInt() * 1000,
                isUtc: true,
              ).toIso8601String()
            : DateTime.now().toIso8601String(),
      );

      await library.addToLibrary(
        model,
        status: _statuses[i] ?? 'playing',
        userRating: _ratings[i],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 26),
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review Imported Games',
                          style: AppTextStyles.title.copyWith(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: _games.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final game = _games[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.bg1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 80,
                            height: 110,
                            child: game['cover_url'] != null
                                ? AppCachedImage(
                                    imageUrl: game['cover_url'],
                                    fit: BoxFit.cover,
                                  )
                                : Container(color: AppColors.bg2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      game['igdb_name'] ??
                                          game['name'] ??
                                          'Unknown',
                                      style: AppTextStyles.title.copyWith(
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  PopupMenuButton<String>(
                                    color: AppColors.bg1,
                                    offset: const Offset(0, 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    onSelected: (value) {
                                      setState(() => _statuses[index] = value);
                                    },
                                    itemBuilder: (context) => _statusOptions
                                        .map(
                                          (status) => PopupMenuItem<String>(
                                            value: status,
                                            child: StatusPill(
                                              status: status,
                                              compact: true,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.bg2,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.04),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          StatusPill(
                                            status: _statuses[index]!,
                                            compact: true,
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 16,
                                            color: AppColors.textMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 132,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () => _toggleSelected(index),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _selected[index]
                                        ? AppColors.accentPurple
                                        : AppColors.bg2,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Center(
                                    child: _selected[index]
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 12,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              RatingPicker(
                                selectedRating: _ratings[index],
                                onRatingChanged: (rating) =>
                                    setState(() => _ratings[index] = rating),
                                showLabels: false,
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_selectedCount games selected',
                          style: AppTextStyles.title.copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: GradientButton(
                      label: 'Add to Library',
                      onTap: () async {
                        await _addSelectedToLibrary();
                        if (!mounted) return;
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
