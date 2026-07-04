import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

Future<void> showImportGamesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const _ImportGamesDialog(),
  );
}

class _ImportGamesDialog extends StatelessWidget {
  const _ImportGamesDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Import Games',
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 18),
              Text(
                'How would you like to import games',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              _ImportSourceButton(
                assetPath: 'assets/images/steam_icon.png',
                tooltip: 'Log into Steam',
                onPressed: () => _launchSteamLogin(context),
              ),
              const SizedBox(height: 8),
              _ImportSourceButton(
                assetPath: 'assets/images/epicgames_icon.png',
                tooltip: 'Log into Epic Games',
                onPressed: () {},
              ),
              const SizedBox(height: 8),
              _ImportSourceButton(
                assetPath: 'assets/images/xbox_icon.png',
                tooltip: 'Log into Xbox',
                onPressed: () {},
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _launchSteamLogin(BuildContext context) async {
  final uri = Uri.parse('http://localhost:8000/auth/steam/login');

  final launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Steam login.')),
    );
  }
}

class _ImportSourceButton extends StatelessWidget {
  const _ImportSourceButton({
    required this.assetPath,
    required this.tooltip,
    required this.onPressed,
  });

  final String assetPath;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: 280,
          height: 60,
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
