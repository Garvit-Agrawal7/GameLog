import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:my_game_list/screens/game_detail_screen.dart';
import '../mock/mock_data.dart';
import '../theme/app_text_styles.dart';
import 'app_cached_image.dart';

class GameCoverCard extends StatefulWidget {
  const GameCoverCard({super.key, required this.game, this.width = 140, this.height = 185});

  final MockGame game;
  final double width;
  final double height;

  @override
  State<GameCoverCard> createState() => _GameCoverCardState();
}

class _GameCoverCardState extends State<GameCoverCard> {
  bool _pressed = false;

  void _openDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameDetailScreen(game: widget.game),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: _openDetail,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AppCachedImage(
                    imageUrl: game.coverUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 28,
                child: Text(
                  game.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, duration: 300.ms),
    );
  }
}

