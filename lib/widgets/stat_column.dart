import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class StatColumn extends StatelessWidget {
  const StatColumn({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label1,
    required this.label2,
  });

  final IconData icon;
  final Color iconColor;
  final num value;
  final String label1;
  final String label2;

  String _formatValue(double animatedValue) {
    if (value is int) {
      return animatedValue.round().toString();
    }
    return animatedValue.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, animatedValue, child) {
            return Text(
              _formatValue(animatedValue),
              style: AppTextStyles.title.copyWith(fontSize: 26),
            );
          },
        ),
        Text(label1, style: AppTextStyles.caption),
        Text(
          label2,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

