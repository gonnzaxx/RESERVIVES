import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

class IesWhoWeAreScreen extends StatelessWidget {
  const IesWhoWeAreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final bool isWeb = width > 800;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth), // Ajustado para web
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
                      const SizedBox(height: 20),
                      RvPageHeader(
                        title: context.tr('iesinfo.sections.who.title'),
                      ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      children: [
                        _buildQuoteHero(context, theme),
                        const SizedBox(height: 24),

                        // Misión y Visión (ya tenían lógica Row/Column interna)
                        _buildMissionVision(context, !isWeb),

                        const SizedBox(height: 20),

                        // Layout dinámico para las listas inferiores
                        if (isWeb)
                          _buildWebLists(context)
                        else
                          _buildMobileLists(context),
                      ],
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

  Widget _buildQuoteHero(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 6),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 16,
            top: 8,
            child: Icon(
              Icons.format_quote_rounded,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              context.tr('iesinfo.sections.who.description'),
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1.8,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildMobileLists(BuildContext context) {
    return Column(
      children: [
        _ListSection(
          title: context.tr('iesinfo.who.objectives.title'),
          items: context.trList('iesinfo.who.objectives.items'),
          icon: Icons.track_changes_rounded,
        ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 20),
        _ListSection(
          title: context.tr('iesinfo.who.commitments.title'),
          items: context.trList('iesinfo.who.commitments.items'),
          icon: Icons.verified_user_rounded,
          isHighlight: true,
        ).animate().fadeIn(delay: 500.ms),
      ],
    );
  }

  Widget _buildWebLists(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ListSection(
              title: context.tr('iesinfo.who.objectives.title'),
              items: context.trList('iesinfo.who.objectives.items'),
              icon: Icons.track_changes_rounded,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _ListSection(
              title: context.tr('iesinfo.who.commitments.title'),
              items: context.trList('iesinfo.who.commitments.items'),
              icon: Icons.verified_user_rounded,
              isHighlight: true,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildMissionVision(BuildContext context, bool isMobile) {
    final missionCard = _InfoSectionCard(
      title: context.tr('iesinfo.who.mission.title'),
      content: context.tr('iesinfo.who.mission.content'),
      icon: Icons.rocket_launch_rounded,
      values: context.trList('iesinfo.who.mission.values'),
    );

    final visionCard = _InfoSectionCard(
      title: context.tr('iesinfo.who.vision.title'),
      content: context.tr('iesinfo.who.vision.content'),
      icon: Icons.visibility_rounded,
    );

    if (isMobile) {
      return Column(
        children: [
          missionCard,
          const SizedBox(height: 16),
          visionCard,
        ],
      ).animate().fadeIn(delay: 300.ms);
    } else {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: missionCard),
            const SizedBox(width: 16),
            Expanded(child: visionCard),
          ],
        ),
      ).animate().fadeIn(delay: 300.ms);
    }
  }
}

class _InfoSectionCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final List<String>? values;

  const _InfoSectionCard({
    required this.title,
    required this.content,
    required this.icon,
    this.values,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RvSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 28),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          if (values != null && values!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values!.map((v) => RvBadge(label: v)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final bool isHighlight;

  const _ListSection({
    required this.title,
    required this.items,
    required this.icon,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RvSurfaceCard(
      color: isHighlight ? theme.colorScheme.primary.withValues(alpha: 0.03) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RvSectionHeader(
            title: title,
            trailing: Icon(icon, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}