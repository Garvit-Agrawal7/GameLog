import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../database/database_providers.dart';
import '../game_library_provider.dart';
import '../igdb_service.dart';
import '../game_modal.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gradient_button.dart';
import 'game_detail_screen.dart';

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
  late Future<List<String>> _historyFuture;
  Future<List<GameModal>>? _searchFuture;
  Timer? _searchDebounce;
  Timer? _historyDebounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _service = IgdbService();
    _historyFuture = _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _historyDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<List<String>> _loadSearchHistory() {
    return ref.read(searchHistoryProvider.future);
  }

  Future<List<GameModal>> _loadSearchResults(String query) async {
    return _service.searchGames(query, limit: 50);
  }

  Future<void> _saveSearchQuery(String query) async {
    final database = await ref.read(databaseProvider.future);
    await database.searchHistoryDao.saveSearchQuery(query);
    ref.invalidate(searchHistoryProvider);
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
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _onSearchChanged(query);
  }

  Future<void> _openStatusSheet(GameModal game) {
    return showStatusSelectionSheet(context, game, ref);
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
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _controller,
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
  String selectedStatus = 'playing';
  int? userRatingNumber;

  Widget buildRatingPicker(void Function(void Function()) setState) {
    return _RatingPicker(
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
                      icon: Icons.do_not_disturb_alt_rounded,
                      label: 'Dropped',
                      value: 'dropped',
                    ),
                    if (selectedStatus == 'completed') ...[
                      const SizedBox(height: 16),
                      Text('Your rating:', style: AppTextStyles.label),
                      const SizedBox(height: 12),
                      buildRatingPicker(setState),
                    ],
                    const SizedBox(height: 20),
                    GradientButton(
                      label: 'Add to Library',
                      onTap: () async {
                        final int? passedRating =
                        selectedStatus == 'completed' ? userRatingNumber : null;
                        final gameToAdd = timeToBeatHours != null
                            ? game.copyWith(timeToBeatHours: timeToBeatHours)
                            : game;
                        await ref
                            .read(gameLibraryProvider.notifier)
                            .addToLibrary(gameToAdd, status: selectedStatus, userRating: passedRating);
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

class _RatingPicker extends StatefulWidget {
  const _RatingPicker({
    required this.selectedRating,
    required this.onRatingChanged,
  });

  final int? selectedRating;
  final ValueChanged<int?> onRatingChanged;

  @override
  State<_RatingPicker> createState() => _RatingPickerState();
}

class _RatingPickerState extends State<_RatingPicker> {
  static const List<int?> _ratings = [null, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1];
  static const double _itemWidth = 48;
  static const double _selectorSize = 48;
  static const double _height = 88;

  PageController? _pageController;
  double? _viewportFraction;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    final initialIndex = _ratings.indexOf(widget.selectedRating);
    _selectedIndex = initialIndex < 0 ? 0 : initialIndex;
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  PageController _controllerForWidth(double width) {
    final viewportFraction = (_itemWidth / width).clamp(0.01, 1.0);
    if (_pageController == null || _viewportFraction != viewportFraction) {
      final initialIndex = _ratings.indexOf(widget.selectedRating);
      _pageController?.dispose();
      _viewportFraction = viewportFraction;
      _pageController = PageController(
        initialPage: initialIndex < 0 ? 0 : initialIndex,
        viewportFraction: viewportFraction,
      );
    }
    return _pageController!;
  }

  String _ratingLabel(int? rating) {
    switch (rating) {
      case 10:
        return 'Masterpiece';
      case 9:
        return 'Great';
      case 8:
        return 'Very Good';
      case 7:
        return 'Good';
      case 6:
        return 'Fine';
      case 5:
        return 'Average';
      case 4:
        return 'Bad';
      case 3:
        return 'Very Bad';
      case 2:
        return 'Horrible';
      case 1:
        return 'Appalling';
      default:
        return 'Not Yet Scored';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pageController = _controllerForWidth(constraints.maxWidth);

          return Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ClipPath(
                  clipper: const _RatingLabelClipper(),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 3, 12, 13),
                    color: AppColors.accentPurple,
                    child: Text(
                      _ratingLabel(_ratings[_selectedIndex]),
                      style: AppTextStyles.label.copyWith(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: _selectorSize,
                  height: _selectorSize,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accentPurple, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 34),
                child: PageView.builder(
                  controller: pageController,
                  itemCount: _ratings.length,
                  onPageChanged: (index) {
                    setState(() => _selectedIndex = index);
                    widget.onRatingChanged(_ratings[index]);
                  },
                  itemBuilder: (context, index) {
                    final rating = _ratings[index];
                    final displayValue = rating == null ? '-' : rating.toString();

                    return Center(
                      child: SizedBox(
                        width: _itemWidth,
                        child: Center(
                          child: Text(
                            displayValue,
                            style: AppTextStyles.label.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentPurple,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RatingLabelClipper extends CustomClipper<Path> {
  const _RatingLabelClipper();

  @override
  Path getClip(Size size) {
    const arrowWidth = 16.0;
    const arrowHeight = 10.0;
    const radius = 4.0;
    final arrowLeft = (size.width - arrowWidth) / 2;
    final arrowRight = arrowLeft + arrowWidth;
    final bodyBottom = size.height - arrowHeight;

    return Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, bodyBottom - radius)
      ..quadraticBezierTo(size.width, bodyBottom, size.width - radius, bodyBottom)
      ..lineTo(arrowRight, bodyBottom)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(arrowLeft, bodyBottom)
      ..lineTo(radius, bodyBottom)
      ..quadraticBezierTo(0, bodyBottom, 0, bodyBottom - radius)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _RatingLabelClipper oldClipper) => false;
}
