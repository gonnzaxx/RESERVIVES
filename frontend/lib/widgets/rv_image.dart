/// Sistema de Visualización de Imágenes y Avatares.
///
/// Este archivo contiene componentes de UI optimizados para la carga de imágenes
/// desde red, gestionando estados de carga (shimmer), errores y placeholders.

library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Un widget de imagen que maneja caché, placeholders y fallbacks.
class RvImage extends StatelessWidget {


  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackIconColor;
  final Widget? fallbackWidget;
  final Gradient? fallbackGradient;

  const RvImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_rounded,
    this.fallbackIconColor,
    this.fallbackWidget,
    this.fallbackGradient,
  });

  bool get _hasUrl => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content;

    if (!_hasUrl) {
      content = _buildFallback(context, isDark);
    } else {
      content = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 260),
        placeholder: (_, __) => _buildPlaceholder(context, isDark),
        errorWidget: (_, __, ___) => _buildFallback(context, isDark),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: SizedBox(width: width, height: height, child: content),
      );
    }

    return SizedBox(width: width, height: height, child: content);
  }

  /// Construye un efecto de carga (shimmer) adaptado al tema actual.
  Widget _buildPlaceholder(BuildContext context, bool isDark) {
    final baseColor =
    isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final highlightColor =
    isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF2F2F7);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        color: baseColor,
      ),
    );
  }

  /// Construye el estado visual por defecto cuando no hay imagen disponible.
  Widget _buildFallback(BuildContext context, bool isDark) {
    if (fallbackWidget != null) return fallbackWidget!;

    final gradient = fallbackGradient ??
        (isDark
            ? const LinearGradient(
          colors: [Color(0xFF1C1C2E), Color(0xFF2A2A3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : const LinearGradient(
          colors: [Color(0xFFF5F7FF), Color(0xFFEAF0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ));

    final iconColor = fallbackIconColor ??
        Theme.of(context).colorScheme.primary;

    final iconSize = _computeIconSize();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(gradient: gradient),
      child: Center(
        child: Icon(iconSize > 0 ? fallbackIcon : fallbackIcon,
            size: iconSize, color: iconColor),
      ),
    );
  }

  /// Calcula dinámicamente el tamaño del icono en base a las dimensiones del contenedor.
  double _computeIconSize() {
    if (width != null && height != null) {
      final smallest = width! < height! ? width! : height!;
      return (smallest * 0.4).clamp(16.0, 48.0);
    }
    return 32;
  }
}

/// Widget especializado para mostrar avatares circulares de usuario.
///
/// Si no hay imagen, muestra la inicial del nombre del usuario
class RvAvatar extends StatelessWidget {
  final String? imageUrl;

  /// Texto utilizado para extraer la inicial de fallback.
  final String fallbackText;
  final double radius;
  final Color? backgroundColor;

  const RvAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackText,
    this.radius = 24,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final bg = backgroundColor ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.14);

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: RvImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          fallbackWidget: Container(
            width: size,
            height: size,
            color: bg,
            alignment: Alignment.center,
            child: Text(
              fallbackText.isNotEmpty
                  ? fallbackText[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
