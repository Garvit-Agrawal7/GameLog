import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_library_provider.dart';
import '../igdb_service.dart';
import 'package:my_game_list/screens/game_detail_screen.dart' as detail;
import '../game_modal.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_cached_image.dart';

const List<GameModal> _discoverSeedGames = [
  GameModal(
    id: 1,
    title: 'Elden Ring',
    coverUrl: 'https://picsum.photos/seed/elden-ring/800/1200',
    genres: ['RPG', 'Action', 'Open World'],
    summary:
        'Forge your own path through a vast shattered kingdom filled with secrets, massive bosses, and wonder.',
    rating: 97,
    hoursPlayed: 126,
    year: 2022,
    lastUpdated: '',
  ),
  GameModal(
    id: 2,
    title: 'The Witcher 3: Wild Hunt',
    coverUrl: 'https://picsum.photos/seed/witcher-3/800/1200',
    genres: ['RPG', 'Adventure', 'Fantasy'],
    summary:
        'As Geralt of Rivia, hunt monsters and shape a war-torn world with every choice you make.',
    rating: 96,
    hoursPlayed: 94,
    year: 2015,
    lastUpdated: '',
  ),
  GameModal(
    id: 3,
    title: 'God of War Ragnarok',
    coverUrl: 'https://picsum.photos/seed/god-of-war-ragnarok/800/1200',
    genres: ['Action', 'Adventure', 'Narrative'],
    summary:
        'Kratos and Atreus journey across the Nine Realms as prophecy, family, and fate collide.',
    rating: 94,
    hoursPlayed: 42,
    year: 2022,
    lastUpdated: '',
  ),
  GameModal(
    id: 4,
    title: 'Red Dead Redemption 2',
    coverUrl: 'https://picsum.photos/seed/red-dead-redemption-2/800/1200',
    genres: ['Action', 'Open World', 'Western'],
    summary:
        'Live the outlaw life in a cinematic frontier world packed with quiet moments and explosive drama.',
    rating: 95,
    hoursPlayed: 88,
    year: 2018,
    lastUpdated: '',
  ),
  GameModal(
    id: 5,
    title: 'Cyberpunk 2077',
    coverUrl: 'https://picsum.photos/seed/cyberpunk-2077/800/1200',
    genres: ['RPG', 'Action', 'Sci-Fi'],
    summary:
        'Explore Night City as a mercenary chasing power, cyberware, and the promise of a better future.',
    rating: 89,
    hoursPlayed: 63,
    year: 2020,
    lastUpdated: '',
  ),
  GameModal(
    id: 6,
    title: 'Baldur\'s Gate 3',
    coverUrl: 'https://picsum.photos/seed/baldurs-gate-3/800/1200',
    genres: ['RPG', 'Strategy', 'Fantasy'],
    summary:
        'Lead a party of companions through a reactive fantasy world full of choices, dice rolls, and chaos.',
    rating: 99,
    hoursPlayed: 51,
    year: 2023,
    lastUpdated: '',
  ),
  GameModal(
    id: 7,
    title: 'Hollow Knight',
    coverUrl: 'https://picsum.photos/seed/hollow-knight/800/1200',
    genres: ['Metroidvania', 'Adventure', 'Indie'],
    summary:
        'Descend into Hallownest and uncover a haunting insect kingdom with precision combat and secrets.',
    rating: 92,
    hoursPlayed: 28,
    year: 2017,
    lastUpdated: '',
  ),
  GameModal(
    id: 8,
    title: 'Black Myth: Wukong',
    coverUrl: 'https://picsum.photos/seed/black-myth-wukong/800/1200',
    genres: ['Action', 'RPG', 'Mythology'],
    summary:
        'A mythic action journey inspired by Journey to the West, built around cinematic boss encounters.',
    rating: 91,
    hoursPlayed: 17,
    year: 2024,
    lastUpdated: '',
  ),
  GameModal(
    id: 9,
    title: 'Hades',
    coverUrl: 'https://picsum.photos/seed/hades/800/1200',
    genres: ['Roguelike', 'Action', 'Indie'],
    summary:
        'Break out of the Underworld again and again in a fast, stylish roguelike steeped in Greek myth.',
    rating: 93,
    hoursPlayed: 36,
    year: 2020,
    lastUpdated: '',
  ),
  GameModal(
    id: 10,
    title: 'Disco Elysium',
    coverUrl: 'https://picsum.photos/seed/disco-elysium/800/1200',
    genres: ['RPG', 'Narrative', 'Detective'],
    summary:
        'Investigate a bizarre murder case through dialogue, skill checks, and an unforgettable interior monologue.',
    rating: 91,
    hoursPlayed: 9,
    year: 2019,
    lastUpdated: '',
  ),
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
  ),
  GameModal(
    id: 12,
    title: 'Alan Wake 2',
    coverUrl: 'https://picsum.photos/seed/alan-wake-2/800/1200',
    genres: ['Horror', 'Adventure', 'Narrative'],
    summary:
        'A tense psychological thriller that blends survival horror, live-action staging, and surreal storytelling.',
    rating: 90,
    hoursPlayed: 24,
    year: 2023,
    lastUpdated: '',
  ),
];

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key, this.service});

  final IgdbService? service;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  late final Future<List<GameModal>> _catalogFuture;
  Future<List<GameModal>>? _similarGamesFuture;
  int? _lastCompletedGameId;
  String? _lastCompletedGameTitle;

  IgdbService get _service => widget.service ?? IgdbService();

  @override
  void initState() {
    super.initState();
    _catalogFuture = _service.enrichGames(_discoverSeedGames);
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
      _similarGamesFuture = _service.fetchSimilarGames(latest.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentlyCompleted = ref.watch(recentlyCompletedProvider);
    final libraryGames = ref.watch(libraryGamesProvider);
    _syncSimilarGames(recentlyCompleted);

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(title: const Text('Explore')),
      body: FutureBuilder<List<GameModal>>(
        future: _catalogFuture,
        builder: (context, catalogSnapshot) {
          if (catalogSnapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentPurple),
            );
          }

          if (catalogSnapshot.hasError) {
            final displayMsg = catalogSnapshot.error is IgdbRateLimitException
                ? (catalogSnapshot.error as IgdbRateLimitException).message
                : 'Error loading games';
            return Center(
              child: Text(
                displayMsg,
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            );
          }

          final catalogGames = catalogSnapshot.data ?? const <GameModal>[];
          final trending = catalogGames.where((game) => game.rating >= 90).take(5).toList();
          final hiddenGems = _gamesForTitles(catalogGames, const [
            'Disco Elysium',
            'Alan Wake 2',
            'Hollow Knight',
            'Hades',
            'Horizon Zero Dawn',
          ]);
          final topRpg = catalogGames
              .where((game) => game.genres.any((genre) => genre.toLowerCase().contains('rpg')))
              .take(5)
              .toList();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recentlyCompleted.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No completed games yet',
                      style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                    ),
                  )
                else
                  FutureBuilder<List<GameModal>>(
                    future: _similarGamesFuture ?? Future.value(const []),
                    builder: (context, similarSnapshot) {
                      if (similarSnapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.accentPurple),
                          ),
                        );
                      }

                      final similarGames = similarSnapshot.data ?? const <GameModal>[];
                      final libraryIds = libraryGames.map((game) => game.id).toSet();
                      final filteredSimilarGames = similarGames
                          .where((game) => !libraryIds.contains(game.id))
                          .toList();
                      final sourceTitle = _lastCompletedGameTitle ?? 'your last completed game';

                      return _HorizontalGameSection(
                        title: 'Because you liked "$sourceTitle"',
                        games: filteredSimilarGames.take(10).toList(),
                        rightPadding: 40,
                      );
                    },
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

  List<GameModal> _gamesForTitles(List<GameModal> games, List<String> titles) {
    return [
      for (final title in titles) ...games.where((game) => game.title == title),
    ];
  }
}

class _HorizontalGameSection extends StatelessWidget {
  const _HorizontalGameSection({
    required this.title,
    required this.games,
    this.showBadge = false,
    this.rightPadding = 20,
  });

  final String title;
  final List<GameModal> games;
  final bool showBadge;
  final double rightPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, rightPadding, 0),
            child: _DiscoverSectionHeader(title: title),
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
  const _DiscoverGameCard({required this.game, this.showBadge = false});

  final GameModal game;
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

