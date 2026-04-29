import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/announcements_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';

class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  final String anuncioId;

  const AnnouncementDetailScreen({super.key, required this.anuncioId});

  @override
  ConsumerState<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends ConsumerState<AnnouncementDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(anunciosProvider.notifier).registrarVisualizacion(widget.anuncioId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final anunciosAsync = ref.watch(anunciosProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: RvGhostIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => context.pop(),
          ),
        ),
      ),
      body: anunciosAsync.when(
        data: (anuncios) {
          final matches = anuncios.where((a) => a.id == widget.anuncioId);
          final anuncio = matches.isEmpty ? null : matches.first;

          if (anuncio == null) {
            return RvEmptyState(
              icon: Icons.article_outlined,
              title: context.tr('announcement.notFoundTitle'),
              subtitle: context.tr('announcement.notFoundSubtitle'),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (anuncio.imagenUrl != null && anuncio.imagenUrl!.isNotEmpty) ...[
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: RvImage(
                            imageUrl: anuncio.imagenUrl!,
                            width: double.infinity,
                            height: 320,
                            fit: BoxFit.cover,
                            fallbackWidget: _AnnouncementImageError(
                              message: context.tr('common.imageLoadError'),
                              height: 320,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('d MMMM, yyyy', Localizations.localeOf(context).languageCode)
                              .format(anuncio.fechaPublicacion),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      anuncio.titulo,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      anuncio.contenido,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.8,
                        fontSize: 17,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (anuncio.nombreAutor != null) ...[
                      const SizedBox(height: 48),
                      _AuthorCard(nombreAutor: anuncio.nombreAutor!),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const _LoadingSkeleton(),
        error: (error, _) => const Center(child: RvApiErrorState()),
      ),
    );
  }
}

class _AuthorCard extends StatelessWidget {
  final String nombreAutor;

  const _AuthorCard({required this.nombreAutor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              nombreAutor[0].toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('announcement.authorLabel'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  nombreAutor,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RvSkeleton(width: double.infinity, height: 320, borderRadius: 28),
              const SizedBox(height: 32),
              const RvSkeleton(width: 140, height: 20, borderRadius: 8),
              const SizedBox(height: 16),
              const RvSkeleton(width: double.infinity, height: 45),
              const SizedBox(height: 12),
              const RvSkeleton(width: 250, height: 45),
              const SizedBox(height: 40),
              ...List.generate(6, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RvSkeleton(width: double.infinity, height: 16),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementImageError extends StatelessWidget {
  final String message;
  final double height;

  const _AnnouncementImageError({
    required this.message,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}