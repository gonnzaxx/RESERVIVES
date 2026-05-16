import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = AppConstants.isWideScreen(context);

    final items = [
      _HelpItem(
        icon: Icons.calendar_month_rounded,
        color: AppColors.accentPurple,
        title: context.tr('help.items.booking.title'),
        subtitle: context.tr('help.items.booking.subtitle'),
      ),
      _HelpItem(
        icon: Icons.admin_panel_settings_rounded,
        color: AppColors.success,
        title: context.tr('help.items.approvals.title'),
        subtitle: context.tr('help.items.approvals.subtitle'),
      ),
      _HelpItem(
        icon: Icons.stars_rounded,
        color: AppColors.primaryBlue,
        title: context.tr('help.items.tokens.title'),
        subtitle: context.tr('help.items.tokens.subtitle'),
      ),
      _HelpItem(
        icon: Icons.local_cafe_rounded,
        color: AppColors.warning,
        title: context.tr('help.items.cafeteria.title'),
        subtitle: context.tr('help.items.cafeteria.subtitle'),
      ),
      _HelpItem(
        icon: Icons.report_rounded,
        color: AppColors.error,
        title: context.tr('help.items.reports.title'),
        subtitle: context.tr('help.items.reports.subtitle'),
      ),
      _HelpItem(
        icon: Icons.poll_rounded,
        color: AppColors.warning,
        title: context.tr('help.items.polls.title'),
        subtitle: context.tr('help.items.polls.subtitle'),
      ),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        8, 12, 20, isWeb ? 24 : 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            RvGhostIconButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => context.pop(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('help.eyebrow').toUpperCase(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      letterSpacing: 0.9,
                                      fontWeight: FontWeight.w700,
                                      color: theme.hintColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.tr('help.title'),
                                    style:
                                    theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 300.ms),

                        if (context.tr('help.subtitle').isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              context.tr('help.subtitle'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                                height: 1.5,
                              ),
                            ).animate().fadeIn(delay: 80.ms, duration: 300.ms),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, isWeb ? 4 : 0, 20, 48),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.l),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                          width: 1.5,
                        ),
                        boxShadow: AppShadows.soft(context),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.l),
                        child: Column(
                          children: [
                            for (int i = 0; i < items.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 0.5,
                                  thickness: 0.5,
                                  indent: 72,
                                  color: theme.dividerColor
                                      .withValues(alpha: 0.4),
                                ),
                              _HelpTile(
                                item: items[i],
                                isDark: isDark,
                                theme: theme,
                              )
                                  .animate()
                                  .fadeIn(
                                delay: Duration(
                                    milliseconds: 100 + 50 * i),
                                duration: 280.ms,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 120.ms, duration: 350.ms).slideY(
                      begin: 0.04,
                      delay: 120.ms,
                      duration: 350.ms,
                      curve: Curves.easeOutCubic,
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

class _HelpItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _HelpItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class _HelpTile extends StatefulWidget {
  final _HelpItem item;
  final bool isDark;
  final ThemeData theme;

  const _HelpTile({
    required this.item,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_HelpTile> createState() => _HelpTileState();
}

class _HelpTileState extends State<_HelpTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovered
            ? (widget.isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02))
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hovered
                    ? widget.item.color.withValues(alpha: 0.16)
                    : widget.item.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                widget.item.icon,
                color: widget.item.color,
                size: 21,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: widget.theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.item.subtitle,
                    style: widget.theme.textTheme.bodySmall?.copyWith(
                      height: 1.5,
                      color: widget.isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}