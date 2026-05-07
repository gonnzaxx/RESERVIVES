import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

class IesStudiesScreen extends StatelessWidget {
  const IesStudiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List allStudies = AppLocalizations.of(context).translateRaw('iesinfo.studies.list') ?? [];
    final width = MediaQuery.of(context).size.width;
    final bool isWeb = width > 800;

    final basic = allStudies.where((s) => s['level'] == 'basic').toList();
    final medium = allStudies.where((s) => s['level'] == 'medium').toList();
    final higher = allStudies.where((s) => s['level'] == 'higher').toList();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth), // Más ancho para web
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      children: [
                        _buildLevelGroup(context, 'iesinfo.studies.basic.title', basic, isWeb),
                        _buildLevelGroup(context, 'iesinfo.studies.medium.title', medium, isWeb),
                        _buildLevelGroup(context, 'iesinfo.studies.higher.title', higher, isWeb),
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

  Widget _buildLevelGroup(BuildContext context, String titleKey, List items, bool isWeb) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: RvSectionHeader(title: context.tr(titleKey)),
        ),
        if (isWeb)
          _buildWebGrid(items)
        else
          Column(
            children: items.map((study) => _StudyDetailCard(study: study)).toList(),
          ),
      ],
    );
  }

  Widget _buildWebGrid(List items) {
    final leftColumn = <Widget>[];
    final rightColumn = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final card = _StudyDetailCard(study: items[i]);
      if (i.isEven) {
        leftColumn.add(card);
      } else {
        rightColumn.add(card);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: leftColumn)),
        const SizedBox(width: 16),
        Expanded(child: Column(children: rightColumn)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RvGhostIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => context.pop(),
          ),
          const SizedBox(height: 20),
          RvPageHeader(
            title: context.tr('iesinfo.sections.studies.title'),
            subtitle: context.tr('iesinfo.sections.studies.subtitle'),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.1);
  }
}

class _StudyDetailCard extends StatelessWidget {
  final Map study;
  const _StudyDetailCard({required this.study});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RvSurfaceCard(
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            expandedAlignment: Alignment.topLeft,
            title: Text(
              study['name'],
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              study['family'],
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
            children: [
              const Divider(height: 24),
              SelectableText(
                study['description'],
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _buildInfoItem(Icons.history_toggle_off, "Duración", study['duration'], theme),
                  _buildInfoItem(Icons.access_time_rounded, "Turno", (study['shifts'] as List).join(' / '), theme),
                ],
              ),
              if (study['notes'] != null) ...[
                const SizedBox(height: 16),
                _buildInfoItem(Icons.info_outline, "Obs.", study['notes'], theme),
              ],
              const SizedBox(height: 24),
              _buildTagGroup("Competencias", study['skills'], theme),
              const SizedBox(height: 16),
              _buildTagGroup("Salidas Profesionales", study['opportunities'], theme),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagGroup(String label, List? tags, ThemeData theme) {
    if (tags == null || tags.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((t) => RvBadge(label: t.toString())).toList(),
        ),
      ],
    );
  }
}