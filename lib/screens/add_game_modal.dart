import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game_library_provider.dart';
import '../services/igdb_service.dart';
import '../game_modal.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gradient_button.dart';
import '../widgets/search_games.dart';
import '../widgets/rating_picker.dart';


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
  late final IgdbService _service;

  @override
  void initState() {
    super.initState();
    _service = ref.read(igdbServiceProvider);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight - bottomInset,
          ),
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
                Text('Add a Game', style: AppTextStyles.title),
                const SizedBox(height: 16),
                SearchGamesWidget(
                  controller: _controller,
                  service: _service,
                  ref: ref,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showStatusSelectionSheet(
    BuildContext context,
    GameModal game,
    WidgetRef ref, {
    int? timeToBeatHours,
    }) {
  String selectedStatus = game.status ?? 'playing';
  int? userRatingNumber = game.userRating;

  Widget buildRatingPicker(void Function(void Function()) setState) {
    return RatingPicker(
      selectedRating: userRatingNumber,
      onRatingChanged: (rating) {
        setState(() => userRatingNumber = rating);
      },
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
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
                      icon: Icons.pause_circle_outline_rounded,
                      label: 'Paused',
                      value: 'paused',
                    ),
                    statusButton(
                      icon: Icons.view_list_outlined,
                      label: 'Backlog',
                      value: 'backlog',
                    ),
                    statusButton(
                      icon: Icons.do_not_disturb_alt_rounded,
                      label: 'Dropped',
                      value: 'dropped',
                    ),
                    const SizedBox(height: 16),
                    Text('Your rating:', style: AppTextStyles.label),
                    const SizedBox(height: 12),
                    buildRatingPicker(setState),
                    const SizedBox(height: 20),
                    GradientButton(
                      label: 'Add to Library',
                      onTap: () async {
                        final gameToAdd = timeToBeatHours != null
                            ? game.copyWith(timeToBeatHours: timeToBeatHours)
                            : game;
                        await ref
                            .read(gameLibraryProvider.notifier)
                            .addToLibrary(gameToAdd, status: selectedStatus, userRating: userRatingNumber);
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).pop();
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
