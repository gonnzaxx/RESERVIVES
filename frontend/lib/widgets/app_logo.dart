import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/providers/branding_provider.dart';

class AppLogo extends ConsumerWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? heroTag;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final branding = ref.watch(brandingProvider);

    final customUrl = isDark ? branding.logoDarkUrl : branding.logoLightUrl;
    final fallbackCustomUrl = isDark ? branding.logoLightUrl : branding.logoDarkUrl;
    final effectiveUrl = customUrl ?? fallbackCustomUrl;

    Widget image;

    if (effectiveUrl != null) {
      final resolvedUrl = AppConstants.resolveApiUrl(effectiveUrl);
      image = Image.network(
        resolvedUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, _) => Image.asset(
          AppAssets.logoPathForTheme(Theme.of(context).brightness),
          width: width,
          height: height,
          fit: fit,
        ),
      );
    } else {
      image = Image.asset(
        AppAssets.logoPathForTheme(Theme.of(context).brightness),
        width: width,
        height: height,
        fit: fit,
      );
    }

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: image);
    }

    return image;
  }
}
