import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

class IesServicesScholarshipsScreen extends StatelessWidget {
  const IesServicesScholarshipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List sections = AppLocalizations.of(context).translateRaw('iesinfo.services.sections') ?? [];
    final width = MediaQuery.of(context).size.width;
    final bool isWeb = width > 800;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth), // Un poco más ancho para las 2 columnas
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: isWeb
                        ? _buildWebGrid(sections)
                        : _buildMobileList(sections),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          RvGhostIconButton(icon: Icons.arrow_back_rounded, onTap: () => context.pop()),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('iesinfo.sections.services.title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }

  // Layout para móvil: una tarjeta tras otra
  Widget _buildMobileList(List sections) {
    return Column(
      children: sections.map((section) => _ServiceCategoryCard(
        title: section['title'],
        iconName: section['icon'],
        items: List<String>.from(section['items']),
      )).toList(),
    );
  }

  // Layout para Web: dos columnas alineadas arriba
  Widget _buildWebGrid(List sections) {
    // Dividimos las secciones en dos listas para que fluyan de forma natural en columnas
    final leftColumn = <Widget>[];
    final rightColumn = <Widget>[];

    for (var i = 0; i < sections.length; i++) {
      final card = _ServiceCategoryCard(
        title: sections[i]['title'],
        iconName: sections[i]['icon'],
        items: List<String>.from(sections[i]['items']),
      );
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
}

class _ServiceCategoryCard extends StatelessWidget {
  final String title;
  final String iconName;
  final List<String> items;

  const _ServiceCategoryCard({
    required this.title,
    required this.iconName,
    required this.items,
  });

  IconData _getIcon(String name) {
    switch (name) {
      case 'school': return Icons.school_outlined;
      case 'public': return Icons.public_outlined;
      case 'business_center': return Icons.business_center_outlined;
      case 'lightbulb': return Icons.lightbulb_outline;
      case 'volunteer_activism': return Icons.volunteer_activism_outlined;
      case 'campaign': return Icons.campaign_outlined;
      default: return Icons.star_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: RvSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getIcon(iconName), color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SelectableText(
                      item,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}