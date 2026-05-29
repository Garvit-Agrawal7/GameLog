import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../game_library_provider.dart';
import '../igdb_service.dart';
import '../mock/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gradient_button.dart';

Future<void> showAddGameModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddGameModal(),
  );
}

class _AddGameModal extends ConsumerStatefulWidget {
  const _AddGameModal();

  @override
  ConsumerState<_AddGameModal> createState() => _AddGameModalState();
}

class _AddGameModalState extends ConsumerState<_AddGameModal> {
  final TextEditingController _controller = TextEditingController();
  late final Future<List<MockGame>> _gamesFuture;

  @override
  void initState() {
    super.initState();
    _gamesFuture = IgdbService().enrichGames(mockGames.take(5).toList());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openStatusSheet(MockGame game) {
    return showStatusSelectionSheet(context, game, ref);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Add a Game', style: AppTextStyles.title),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _controller,
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
            const SizedBox(height: 16),
            FutureBuilder<List<MockGame>>(
              future: _gamesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppColors.accentPurple),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading games',
                        style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }

                final games = snapshot.data ?? [];

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: games.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                          placeholder: (_, __) => Shimmer.fromColors(
                            baseColor: AppColors.bg1,
                            highlightColor: AppColors.bg2,
                            child: Container(color: AppColors.bg1),
                          ),
                          errorWidget: (_, __, ___) => Container(
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
                        '${game.year} • ${game.genres.isNotEmpty ? game.genres.first : 'N/A'}',
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
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showStatusSelectionSheet(
  BuildContext context,
  MockGame game,
  WidgetRef ref,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      String selectedStatus = 'playing';
      int rating = 4;

      return StatefulBuilder(
        builder: (context, setState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          Widget statusButton({
            required IconData icon,
            required String label,
            required String value,
          }) {
            final selected = selectedStatus == value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: () => setState(() => selectedStatus = value),
                icon: Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.accentPurple : AppColors.textPrimary,
                ),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(label),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(
                    color: selected ? AppColors.accentPurple : AppColors.bg2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            );
          }

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.bg1,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + bottomInset),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.bg2,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mark "${game.title}" as:',
                      style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    statusButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Playing',
                      value: 'playing',
                    ),
                    statusButton(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Completed',
                      value: 'completed',
                    ),
                    statusButton(
                      icon: Icons.bookmark_outline_rounded,
                      label: 'Wishlist',
                      value: 'wishlist',
                    ),
                    statusButton(
                      icon: Icons.do_not_disturb_alt_rounded,
                      label: 'Dropped',
                      value: 'dropped',
                    ),
                    if (selectedStatus == 'completed') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('Your rating:', style: AppTextStyles.label),
                          const Spacer(),
                          ...List.generate(5, (index) {
                            final selected = index < rating;
                            return GestureDetector(
                              onTap: () => setState(() => rating = index + 1),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Icon(
                                  selected ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 22,
                                  color: selected ? AppColors.accentPurple : AppColors.textMuted,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    GradientButton(
                      label: 'Add to Library',
                      onTap: () {
                        // Add game to library with selected status
                        ref
                            .read(gameLibraryProvider.notifier)
                            .addToLibrary(game, status: selectedStatus);
                        Navigator.of(sheetContext).pop(); // Close status sheet
                        Navigator.of(context).pop(); // Close add game modal
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
