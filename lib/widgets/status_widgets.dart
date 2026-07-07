import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class StatusBadgeIcon extends StatelessWidget {
  const StatusBadgeIcon({super.key, required this.status});

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

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.compact = false});

  final String status;
  final bool compact;

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
      'wishlist' => Icon(Icons.favorite, size: compact ? 10 : 12, color: color),
      'playing' => Icon(Icons.play_arrow_rounded, size: compact ? 10 : 12, color: color),
      'completed' => Icon(Icons.sports_esports_rounded, size: compact ? 10 : 12, color: color),
      'paused' => Icon(Icons.pause_circle_filled_rounded, size: compact ? 10 : 12, color: color),
      'dropped' => Icon(Icons.do_not_disturb_alt_rounded, size: compact ? 10 : 12, color: color),
      'backlog' => Icon(Icons.sports_esports_outlined, size: compact ? 10 : 12, color: color),
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
        SizedBox(width: compact ? 4 : 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
            fontSize: compact ? 11 : null,
          ),
        ),
      ],
    );
  }
}

