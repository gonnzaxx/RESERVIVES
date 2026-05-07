import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/announcements_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';
import 'package:reservives/config/constants.dart';

class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  final String anuncioId;

  const AnnouncementDetailScreen({super.key, required this.anuncioId});

  @override
  ConsumerState<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState
    extends ConsumerState<AnnouncementDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(anunciosProvider.notifier)
          .registrarVisualizacion(widget.anuncioId);
      _enterCtrl.forward();
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anunciosAsync = ref.watch(anunciosProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
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

          return FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: AppConstants.webMaxWidth),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 48),
                    child: isWeb
                        ? _WebLayout(
                      anuncio: anuncio,
                      isDark: isDark,
                      theme: theme,
                    )
                        : _MobileLayout(
                      anuncio: anuncio,
                      isDark: isDark,
                      theme: theme,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const _LoadingSkeleton(),
        error: (_, __) => const Center(child: RvApiErrorState()),
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final dynamic anuncio;
  final bool isDark;
  final ThemeData theme;

  const _MobileLayout({
    required this.anuncio,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (anuncio.imagenUrl != null && anuncio.imagenUrl!.isNotEmpty) ...[
          _HeroImage(
            imageUrl: anuncio.imagenUrl!,
            height: 260,
            isDark: isDark,
            errorMessage: context.tr('common.imageLoadError'),
          ),
          const SizedBox(height: 28),
        ],
        _DateChip(fecha: anuncio.fechaPublicacion, theme: theme),
        const SizedBox(height: 14),
        _Title(titulo: anuncio.titulo, theme: theme),
        const SizedBox(height: 18),
        if (anuncio.nombreAutor != null) ...[
          _AuthorRow(nombreAutor: anuncio.nombreAutor!, theme: theme, isDark: isDark),
          const SizedBox(height: 18),
        ],
        _BrandDivider(theme: theme),
        const SizedBox(height: 24),
        _Body(contenido: anuncio.contenido, isDark: isDark, theme: theme),

      ],
    );
  }
}

class _WebLayout extends StatelessWidget {
  final dynamic anuncio;
  final bool isDark;
  final ThemeData theme;

  const _WebLayout({
    required this.anuncio,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        anuncio.imagenUrl != null && anuncio.imagenUrl!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateChip(fecha: anuncio.fechaPublicacion, theme: theme),
              const SizedBox(height: 14),
              _Title(titulo: anuncio.titulo, theme: theme),
              const SizedBox(height: 18),
              if (anuncio.nombreAutor != null) ...[
                _AuthorRow(
                    nombreAutor: anuncio.nombreAutor!,
                    theme: theme,
                    isDark: isDark),
                const SizedBox(height: 18),
              ],
              _BrandDivider(theme: theme),
              const SizedBox(height: 24),
              _Body(contenido: anuncio.contenido, isDark: isDark, theme: theme),

            ],
          ),
        ),
        if (hasImage) ...[
          const SizedBox(width: 40),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _HeroImage(
                  imageUrl: anuncio.imagenUrl!,
                  height: 220,
                  isDark: isDark,
                  errorMessage: context.tr('common.imageLoadError'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final bool isDark;
  final String errorMessage;

  const _HeroImage({
    required this.imageUrl,
    required this.height,
    required this.isDark,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.deep(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: RvImage(
          imageUrl: imageUrl,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          fallbackWidget: _ImageError(
            message: errorMessage,
            height: height,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime fecha;
  final ThemeData theme;

  const _DateChip({required this.fecha, required this.theme});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final formatted = DateFormat('d MMMM, yyyy', locale).format(fecha);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 13,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            formatted,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String titulo;
  final ThemeData theme;

  const _Title({required this.titulo, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo,
      style: theme.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w900,
        height: 1.12,
        letterSpacing: -0.8,
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final String nombreAutor;
  final ThemeData theme;
  final bool isDark;

  const _AuthorRow({
    required this.nombreAutor,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor:
          theme.colorScheme.primary.withValues(alpha: 0.15),
          child: Text(
            nombreAutor[0].toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          nombreAutor,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}

class _BrandDivider extends StatelessWidget {
  final ThemeData theme;
  const _BrandDivider({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 8,
          height: 3,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final String contenido;
  final bool isDark;
  final ThemeData theme;

  const _Body({
    required this.contenido,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      contenido,
      style: theme.textTheme.bodyLarge?.copyWith(
        height: 1.85,
        fontSize: 17,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
      ),
    );
  }
}

class _ImageError extends StatelessWidget {
  final String message;
  final double height;
  final bool isDark;

  const _ImageError({
    required this.message,
    required this.height,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      color: isDark ? AppColors.darkCard : AppColors.lightBackground,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 40,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Center(
      child: ConstrainedBox(
        constraints:
        const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 48),
          child: isWeb
              ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _textSkeletonColumn(),
              ),
              const SizedBox(width: 40),
              const Expanded(
                flex: 2,
                child: RvSkeleton(
                    width: double.infinity,
                    height: 220,
                    borderRadius: 20),
              ),
            ],
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RvSkeleton(
                  width: double.infinity,
                  height: 260,
                  borderRadius: 20),
              const SizedBox(height: 28),
              ..._textSkeletonItems(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textSkeletonColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _textSkeletonItems(),
    );
  }

  List<Widget> _textSkeletonItems() {
    return [
      const RvSkeleton(width: 140, height: 28, borderRadius: 100),
      const SizedBox(height: 14),
      const RvSkeleton(width: double.infinity, height: 42, borderRadius: 8),
      const SizedBox(height: 8),
      const RvSkeleton(width: 220, height: 42, borderRadius: 8),
      const SizedBox(height: 18),
      const RvSkeleton(width: 160, height: 20, borderRadius: 100),
      const SizedBox(height: 18),
      const RvSkeleton(width: 50, height: 3, borderRadius: 2),
      const SizedBox(height: 24),
      ...List.generate(
        6,
            (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RvSkeleton(
            width: i == 5 ? 180 : double.infinity,
            height: 16,
            borderRadius: 6,
          ),
        ),
      ),
      const SizedBox(height: 40),
      const RvSkeleton(
          width: double.infinity, height: 88, borderRadius: 20),
    ];
  }
}