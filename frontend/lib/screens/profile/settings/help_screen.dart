import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;

    final items = [
      (
      Icons.calendar_month_rounded,
      AppColors.accentPurple,
      context.tr('help.items.booking.title'),
      context.tr('help.items.booking.subtitle'),
      ),
      (
      Icons.admin_panel_settings_rounded,
      AppColors.success,
      context.tr('help.items.approvals.title'),
      context.tr('help.items.approvals.subtitle'),
      ),
      (
      Icons.stars_rounded,
      AppColors.primaryBlue,
      context.tr('help.items.tokens.title'),
      context.tr('help.items.tokens.subtitle'),
      ),
      (
      Icons.local_cafe_rounded,
      AppColors.warning,
      context.tr('help.items.cafeteria.title'),
      context.tr('help.items.cafeteria.subtitle'),
      ),
      (
      Icons.report,
      AppColors.error,
      context.tr('help.items.reports.title'),
      context.tr('help.items.reports.subtitle'),
      ),
      (
      Icons.poll,
      AppColors.warning,
      context.tr('help.items.polls.title'),
      context.tr('help.items.polls.subtitle'),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, isWeb ? 24 : 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RvGhostIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => context.pop(),
                        ),
                        SizedBox(height: isWeb ? 18 : 8),
                        RvPageHeader(
                          eyebrow: context.tr('help.eyebrow'),
                          title: context.tr('help.title'),
                          subtitle: context.tr('help.subtitle'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, isWeb ? 8 : 0, 20, 40),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(AppRadii.m),
                        boxShadow: AppShadows.soft(context),
                        border: isWeb
                            ? Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05))
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.m),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 0.5,
                            thickness: 0.5,
                            indent: 72,
                            color: Theme.of(context).dividerColor.withOpacity(0.5),
                          ),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: item.$2.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(item.$1, color: item.$2, size: 22),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.$3,
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.$4,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
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