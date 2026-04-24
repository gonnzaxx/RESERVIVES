import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:reservives/config/app_theme.dart';

import 'package:reservives/i10n/app_localizations.dart';

class RvHoverable extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, bool isHovered, Widget child)? builder;
  final VoidCallback? onTap;

  const RvHoverable({
    super.key,
    required this.child,
    this.builder,
    this.onTap,
  });

  @override
  State<RvHoverable> createState() => _RvHoverableState();
}

class _RvHoverableState extends State<RvHoverable> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.builder != null
            ? widget.builder!(context, _isHovered, widget.child)
            : AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class RvSurfaceCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;

  const RvSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.gradient,
    this.color,
  });

  @override
  State<RvSurfaceCard> createState() => _RvSurfaceCardState();
}

class _RvSurfaceCardState extends State<RvSurfaceCard> {
  double _scale = 1.0;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.gradient == null ? (widget.color ?? theme.cardColor) : null,
        gradient: widget.gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _isHovered
            ? [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : theme.primaryColor.withValues(alpha: 0.1),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ]
            : [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : theme.primaryColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: _isHovered
              ? theme.primaryColor.withValues(alpha: 0.2)
              : (isDark
              ? Colors.white.withValues(alpha: 0.05)
              : theme.primaryColor.withValues(alpha: 0.03)),
          width: _isHovered ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: widget.padding,
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return cardContent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.97),
        onTapUp: (_) => setState(() => _scale = 1.0),
        onTapCancel: () => setState(() => _scale = 1.0),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? (_scale * 1.02) : _scale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: cardContent,
        ),
      ),
    );
  }
}

class RvPageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const RvPageHeader({
    super.key,
    required this.title,
    this.eyebrow = '',
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow.isNotEmpty) ...[
                Text(
                  eyebrow.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(title,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  )),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: muted,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 16),
          trailing!,
        ],
      ],
    );
  }
}

class RvSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const RvSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class RvBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const RvBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tone,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RvSearchBar extends StatelessWidget {
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;

  const RvSearchBar({
    super.key,
    this.hintText,
    this.onChanged,
    this.onClear,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft(context),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText ?? 'Search...',
          prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary, size: 20),
          suffixIcon: onClear != null
              ? IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onClear,
          )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class RvDebouncedSearchBar extends StatefulWidget {
  final String? hintText;
  final Duration debounce;
  final ValueChanged<String> onDebouncedChanged;
  final String initialValue;

  const RvDebouncedSearchBar({
    super.key,
    required this.onDebouncedChanged,
    this.hintText,
    this.debounce = const Duration(milliseconds: 300),
    this.initialValue = '',
  });

  @override
  State<RvDebouncedSearchBar> createState() => _RvDebouncedSearchBarState();
}

class _RvDebouncedSearchBarState extends State<RvDebouncedSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RvDebouncedSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () {
      widget.onDebouncedChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RvSearchBar(
      hintText: widget.hintText,
      controller: _controller,
      onChanged: _onChanged,
      onClear: () {
        _controller.clear();
        widget.onDebouncedChanged('');
      },
    );
  }
}

class RvPrimaryButton extends StatefulWidget {
  final VoidCallback? onTap;
  final String label;
  final bool isLoading;
  final IconData? icon;
  final Widget? customIcon;
  final Color? backgroundColor;

  const RvPrimaryButton({
    super.key,
    required this.onTap,
    required this.label,
    this.isLoading = false,
    this.icon,
    this.customIcon,
    this.backgroundColor,
  });

  @override
  State<RvPrimaryButton> createState() => _RvPrimaryButtonState();
}

class _RvPrimaryButtonState extends State<RvPrimaryButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onTap != null && !widget.isLoading;
    final bc = widget.backgroundColor ?? theme.colorScheme.primary;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _scale = 0.96) : null,
        onTapUp: enabled ? (_) => setState(() => _scale = 1.0) : null,
        onTapCancel: enabled ? () => setState(() => _scale = 1.0) : null,
        onTap: enabled ? () {
          HapticFeedback.lightImpact();
          widget.onTap!();
        } : null,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: bc,
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? [
                BoxShadow(
                  color: bc.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: RvLogoLoader(size: 20),
                  )
                else if (widget.customIcon != null) ...[
                  widget.customIcon!,
                  const SizedBox(width: 10),
                ] else if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                ],
                if (!widget.isLoading)
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RvSwitchTileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const RvSwitchTileCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RvSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: value,
            activeTrackColor: Theme.of(context).colorScheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class RvGhostIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const RvGhostIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}

class RvEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryButtonPressed;

  const RvEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonPressed,
    this.secondaryButtonLabel,
    this.onSecondaryButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 3.seconds, curve: Curves.easeInOut),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF9FAFF),
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.soft(context),
                  ),
                  child: Icon(icon, size: 44, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                ),
              ],
            ).animate().fadeIn(duration: 600.ms).scale(delay: 100.ms),
            const SizedBox(height: 32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
                height: 1.5,
              ),
            ),
            if (buttonLabel != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: RvPrimaryButton(
                  onTap: onButtonPressed!,
                  label: buttonLabel!,
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
            ],
            if (secondaryButtonLabel != null && onSecondaryButtonPressed != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: onSecondaryButtonPressed,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(secondaryButtonLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RvApiErrorState extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final Object? error;

  const RvApiErrorState({
    super.key,
    this.title,
    this.subtitle,
    this.onRetry,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final resolvedTitle = () {
      if (title != null) return title!;
      return loc.translate('error.data_load_failed_title');
    }();

    final resolvedSubtitle = () {
      if (subtitle != null) return subtitle!;
      return loc.translate('error.retry_default_subtitle');
    }();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              resolvedTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                resolvedSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: 180,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    loc.translate('common.retry'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RvLogoLoader extends StatefulWidget {
  final double size;

  const RvLogoLoader({
    super.key,
    this.size = 72,
  });

  @override
  State<RvLogoLoader> createState() => _RvLogoLoaderState();
}

class _RvLogoLoaderState extends State<RvLogoLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * 2 * math.pi;
        final scale = 0.94 + (0.06 * (0.5 + 0.5 * math.sin(angle)));
        return Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            child: Opacity(opacity: 0.92, child: child),
          ),
        );
      },
      child: Image.asset(
        'assets/images/logo_luis_vives.png',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class RvSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const RvSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = AppRadii.s,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final highlightColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF2F2F7);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class RvAlerts {
  static void success(BuildContext context, String message) =>
      _showToast(context, message, Icons.check_circle_rounded, AppColors.success);
  static void error(BuildContext context, String message) =>
      _showToast(context, message, Icons.error_rounded, AppColors.error);
  static void info(BuildContext context, String message) =>
      _showToast(context, message, Icons.info_rounded, AppColors.primaryBlue);
  static void warning(BuildContext context, String message) =>
      _showToast(context, message, Icons.warning_rounded, AppColors.warning);

  static void _showToast(BuildContext context, String message, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }

  static Future<void> dialog(BuildContext context,
      {required String title, required String content, String? okLabel}) async {
    final theme = Theme.of(context);
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: RvSurfaceCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 36),
                ),
                const SizedBox(height: 24),
                Text(title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text(content, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                const SizedBox(height: 32),
                RvPrimaryButton(onTap: () => Navigator.pop(context), label: okLabel ?? 'Entendido'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<bool> confirm(BuildContext context,
      {required String title,
        required String content,
        String? confirmLabel,
        String? cancelLabel,
        bool isDestructive = false}) async {
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: RvSurfaceCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isDestructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
                    color: isDestructive ? AppColors.error : theme.colorScheme.primary, size: 40),
                const SizedBox(height: 20),
                Text(title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(content, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text(cancelLabel ?? 'No'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: RvPrimaryButton(
                            backgroundColor: isDestructive ? AppColors.error : null,
                            onTap: () => Navigator.pop(context, true),
                            label: confirmLabel ?? 'Sí')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result ?? false;
  }
}
