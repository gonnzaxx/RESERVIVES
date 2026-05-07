import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

class IesFacilitiesScreen extends StatelessWidget {
  const IesFacilitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final bool isWeb = width > 800;

    // Aquí asumimos que en tu JSON de idiomas tienes objetos con { "label": "...", "image": "..." }
    // Si solo tienes una lista de textos, podrías mapearlos a URLs reales.
    final List galleryItems = AppLocalizations.of(context).translateRaw('iesinfo.facilities.gallery.items') as List? ?? [];
    final buildings = AppLocalizations.of(context).translateRaw('iesinfo.facilities.buildings.list') as List? ?? [];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ).animate().fadeIn().slideX(begin: -0.2),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('iesinfo.sections.facilities.title'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ).animate().fadeIn(delay: 100.ms),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildIntroCard(context, theme),

                        const SizedBox(height: 32),

                        RvSectionHeader(title: context.tr('iesinfo.facilities.buildings.title')),
                        const SizedBox(height: 16),

                        if (isWeb)
                          _buildWebBuildingsGrid(buildings)
                        else
                          _buildMobileBuildingsList(buildings),

                        const SizedBox(height: 32),

                        RvSectionHeader(title: context.tr('iesinfo.facilities.gallery.title')),
                        const SizedBox(height: 16),

                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: galleryItems.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isWeb ? 4 : 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.9, // Ajustado para que quepa bien la foto + texto
                          ),
                          itemBuilder: (context, index) {
                            final item = galleryItems[index];
                            // Si tu JSON es una lista de Strings, usa: label: item, imageUrl: 'ruta/de/ejemplo.jpg'
                            // Si es una lista de objetos, usa: label: item['label'], imageUrl: item['image']
                            return _GalleryCard(
                              label: item is String ? item : item['label'],
                              imageUrl: item is String ? null : item['image'],
                            );
                          },
                        ).animate().fadeIn(delay: 400.ms),
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

  Widget _buildIntroCard(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.04),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.explore_rounded, color: theme.colorScheme.primary, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      context.tr('iesinfo.facilities.intro'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.7,
                        letterSpacing: 0.3,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildMobileBuildingsList(List buildings) {
    return Column(
      children: buildings.map((b) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _BuildingTile(
          title: b['title'],
          desc: b['desc'],
          iconName: b['icon'],
        ),
      )).toList(),
    );
  }

  Widget _buildWebBuildingsGrid(List buildings) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: buildings.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisExtent: 110,
      ),
      itemBuilder: (context, index) {
        final b = buildings[index];
        return _BuildingTile(
          title: b['title'],
          desc: b['desc'],
          iconName: b['icon'],
        );
      },
    );
  }
}

class _BuildingTile extends StatelessWidget {
  final String title;
  final String desc;
  final String iconName;

  const _BuildingTile({required this.title, required this.desc, required this.iconName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = iconName == 'apartment' ? Icons.apartment_rounded : Icons.corporate_fare_rounded;

    return RvSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(desc,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final String label;
  final String? imageUrl;

  const _GalleryCard({required this.label, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RvSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: imageUrl != null
                  ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: theme.colorScheme.errorContainer,
                  child: Icon(Icons.broken_image_rounded, color: theme.colorScheme.error),
                ),
              )
                  : Container(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                child: Icon(Icons.collections_outlined,
                    color: theme.colorScheme.primary.withValues(alpha: 0.3), size: 32),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}