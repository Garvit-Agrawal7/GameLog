import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../igdb_service.dart';
import '../theme/app_colors.dart';
import '../widgets/search_games.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
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
    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SearchGamesWidget(
            controller: _controller,
            service: _service,
            ref: ref,
            showBackButton: true,
            onBackPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
