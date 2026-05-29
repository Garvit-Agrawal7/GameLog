import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

class AppCachedImage extends StatelessWidget {
  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.alignment = Alignment.center,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: (_, imageProvider) => Image(
        image: imageProvider,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.high,
      ),
      placeholder: (_, __) => _Placeholder(
        width: width,
        height: height,
        shape: shape,
        borderRadius: borderRadius,
      ),
      errorWidget: (_, __, ___) => _ErrorWidget(
        width: width,
        height: height,
        shape: shape,
        borderRadius: borderRadius,
      ),
    );

    if (shape == BoxShape.circle) {
      return ClipOval(child: image);
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.width,
    required this.height,
    required this.shape,
    required this.borderRadius,
  });

  final double? width;
  final double? height;
  final BoxShape shape;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final child = Shimmer.fromColors(
      baseColor: AppColors.bg1,
      highlightColor: AppColors.bg2,
      child: Container(color: AppColors.bg1),
    );

    if (shape == BoxShape.circle) {
      return SizedBox(width: width, height: height, child: child);
    }

    return SizedBox(
      width: width,
      height: height,
      child: borderRadius != null
          ? ClipRRect(borderRadius: borderRadius!, child: child)
          : child,
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget({
    required this.width,
    required this.height,
    required this.shape,
    required this.borderRadius,
  });

  final double? width;
  final double? height;
  final BoxShape shape;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      color: AppColors.bg2,
      alignment: Alignment.center,
      child: const Icon(Icons.games_rounded, color: AppColors.textMuted),
    );

    if (shape == BoxShape.circle) {
      return SizedBox(width: width, height: height, child: child);
    }

    return SizedBox(
      width: width,
      height: height,
      child: borderRadius != null
          ? ClipRRect(borderRadius: borderRadius!, child: child)
          : child,
    );
  }
}

