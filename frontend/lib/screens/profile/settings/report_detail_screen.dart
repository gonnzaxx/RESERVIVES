library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/incidencia.dart';
import 'package:reservives/providers/reports_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';

class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({
    super.key,
    required this.incidenciaId,
    this.incidenciaInicial,
    this.fromSubmission = false,
  });

  final String incidenciaId;
  final Incidencia? incidenciaInicial;
  final bool fromSubmission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (incidenciaInicial != null) {
      return _ReportDetailBody(
        incidencia: incidenciaInicial!,
        fromSubmission: fromSubmission,
      );
    }

    final incidenciaAsync = ref.watch(incidenciaByIdProvider(incidenciaId));

    return incidenciaAsync.when(
      data: (incidencia) => _ReportDetailBody(
        incidencia: incidencia,
        fromSubmission: fromSubmission,
      ),
      loading: () => const Scaffold(
        body: Center(child: RvLogoLoader()),
      ),
      error: (_, __) => Scaffold(
        body: Center(
          child: RvApiErrorState(
            onRetry: () => ref.invalidate(incidenciaByIdProvider(incidenciaId)),
          ),
        ),
      ),
    );
  }
}

class _ReportDetailBody extends StatelessWidget {
  const _ReportDetailBody({
    required this.incidencia,
    required this.fromSubmission,
  });

  final Incidencia incidencia;
  final bool fromSubmission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = AppConstants.isWideScreen(context);
    final dateFormat = DateFormat('dd/MM/yyyy · HH:mm', Localizations.localeOf(context).languageCode);
    final isResolved = incidencia.estado == EstadoIncidencia.resuelta;
    final isDiscarded = incidencia.estado == EstadoIncidencia.descartada;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(8, 12, 20, isWeb ? 20 : 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => context.canPop() ? context.pop() : context.goNamed('home'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('incidents.eyebrow').toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w700,
                                color: theme.hintColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('incidents.detail.title'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, isWeb ? 8 : 4, 20, 60),
                    child: isWeb
                        ? _WebLayout(
                            incidencia: incidencia,
                            isDark: isDark,
                            theme: theme,
                            dateFormat: dateFormat,
                            isResolved: isResolved,
                            isDiscarded: isDiscarded,
                          )
                        : _MobileLayout(
                            incidencia: incidencia,
                            isDark: isDark,
                            theme: theme,
                            dateFormat: dateFormat,
                            isResolved: isResolved,
                            isDiscarded: isDiscarded,
                          ),
                  ),
                ),

                if (fromSubmission)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: RvPrimaryButton(
                      onTap: () => context.goNamed('home'),
                      label: context.tr('incidents.detail.goHome'),
                      icon: Icons.home_rounded,
                    ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.incidencia,
    required this.isDark,
    required this.theme,
    required this.dateFormat,
    required this.isResolved,
    required this.isDiscarded,
  });

  final Incidencia incidencia;
  final bool isDark;
  final ThemeData theme;
  final DateFormat dateFormat;
  final bool isResolved;
  final bool isDiscarded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusBadge(
          incidencia: incidencia,
          isDark: isDark,
          theme: theme,
          dateFormat: dateFormat,
          isResolved: isResolved,
          isDiscarded: isDiscarded,
        ).animate().fadeIn(delay: 60.ms, duration: 300.ms),

        const SizedBox(height: 20),

        _DescriptionCard(
          incidencia: incidencia,
          isDark: isDark,
          theme: theme,
        ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

        if (incidencia.imagenUrl != null) ...[
          const SizedBox(height: 20),
          _ImageCard(
            imagenUrl: incidencia.imagenUrl!,
            isDark: isDark,
          ).animate().fadeIn(delay: 140.ms, duration: 300.ms),
        ],

        if (isResolved && incidencia.comentarioAdmin != null) ...[
          const SizedBox(height: 20),
          _AdminResponseCard(
            comentario: incidencia.comentarioAdmin!,
            isDark: isDark,
            theme: theme,
          ).animate().fadeIn(delay: 180.ms, duration: 300.ms),
        ],
      ],
    );
  }
}

class _WebLayout extends StatelessWidget {
  const _WebLayout({
    required this.incidencia,
    required this.isDark,
    required this.theme,
    required this.dateFormat,
    required this.isResolved,
    required this.isDiscarded,
  });

  final Incidencia incidencia;
  final bool isDark;
  final ThemeData theme;
  final DateFormat dateFormat;
  final bool isResolved;
  final bool isDiscarded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusBadge(
          incidencia: incidencia,
          isDark: isDark,
          theme: theme,
          dateFormat: dateFormat,
          isResolved: isResolved,
          isDiscarded: isDiscarded,
        ).animate().fadeIn(delay: 60.ms, duration: 300.ms),

        const SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DescriptionCard(
                    incidencia: incidencia,
                    isDark: isDark,
                    theme: theme,
                  ),
                  if (isResolved && incidencia.comentarioAdmin != null) ...[
                    const SizedBox(height: 20),
                    _AdminResponseCard(
                      comentario: incidencia.comentarioAdmin!,
                      isDark: isDark,
                      theme: theme,
                    ),
                  ],
                ],
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            ),

            if (incidencia.imagenUrl != null) ...[
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: _ImageCard(
                  imagenUrl: incidencia.imagenUrl!,
                  isDark: isDark,
                ).animate().fadeIn(delay: 140.ms, duration: 300.ms),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.incidencia,
    required this.isDark,
    required this.theme,
    required this.dateFormat,
    required this.isResolved,
    required this.isDiscarded,
  });

  final Incidencia incidencia;
  final bool isDark;
  final ThemeData theme;
  final DateFormat dateFormat;
  final bool isResolved;
  final bool isDiscarded;

  Color get _statusColor {
    if (isResolved) return AppColors.success;
    if (isDiscarded) return AppColors.error;
    return AppColors.warning;
  }

  IconData get _statusIcon {
    if (isResolved) return Icons.task_alt_rounded;
    if (isDiscarded) return Icons.cancel_rounded;
    return Icons.pending_actions_rounded;
  }

  String _statusLabel(BuildContext context) {
    if (isResolved) return context.tr('incidents.status.resolved');
    if (isDiscarded) return context.tr('incidents.status.discarded');
    return context.tr('incidents.status.pending');
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadii.m),
        border: Border.all(
          color: color.withValues(alpha: 0.20),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_statusIcon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(context),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateFormat.format(incidencia.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({
    required this.incidencia,
    required this.isDark,
    required this.theme,
  });

  final Incidencia incidencia;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('incidents.description.label'),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.m),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1.5,
            ),
            boxShadow: AppShadows.soft(context),
          ),
          child: Text(
            incidencia.descripcion,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ),
      ],
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.imagenUrl,
    required this.isDark,
  });

  final String imagenUrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('incidents.image.label'),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.m),
          child: RvImage(
            imageUrl: imagenUrl,
            width: double.infinity,
            height: 220,
            fallbackIcon: Icons.image_not_supported_rounded,
          ),
        ),
      ],
    );
  }
}

class _AdminResponseCard extends StatelessWidget {
  const _AdminResponseCard({
    required this.comentario,
    required this.isDark,
    required this.theme,
  });

  final String comentario;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('incidents.detail.adminResponse'),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadii.m),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.22),
              width: 1.5,
            ),
            boxShadow: AppShadows.soft(context),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  comentario,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
