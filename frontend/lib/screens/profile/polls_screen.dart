import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/encuesta.dart';
import 'package:reservives/providers/polls_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/config/constants.dart';

class VotacionesScreen extends ConsumerWidget {
  const VotacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWeb = AppConstants.isWideScreen(context);
    final encuestasAsync = ref.watch(todasEncuestasProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                  EdgeInsets.fromLTRB(8, 12, 20, isWeb ? 20 : 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('profile.accountEyebrow').toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w700,
                                color: theme.hintColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('polls.user.title'),
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
                  child: encuestasAsync.when(
                    data: (encuestas) {
                      if (encuestas.isEmpty) {
                        return Center(
                          child: RvEmptyState(
                            icon: Icons.how_to_vote_rounded,
                            title: context.tr('polls.user.emptyTitle'),
                            subtitle: context.tr('polls.user.emptySubtitle'),
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () =>
                            ref.read(todasEncuestasProvider.notifier).refresh(),
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                              20, isWeb ? 8 : 4, 20, 100),
                          itemCount: encuestas.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _EncuestaCard(
                                encuesta: encuestas[index],
                                isDark: isDark,
                                theme: theme,
                                isWeb: isWeb,
                              )
                                  .animate()
                                  .fadeIn(
                                delay: Duration(
                                    milliseconds: 50 * index),
                                duration: 300.ms,
                              )
                                  .slideY(
                                begin: 0.04,
                                delay: Duration(
                                    milliseconds: 50 * index),
                                duration: 300.ms,
                                curve: Curves.easeOutCubic,
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => _VotacionesSkeleton(isWeb: isWeb),
                    error: (_, __) => Center(
                      child: RvApiErrorState(
                        onRetry: () =>
                            ref.invalidate(todasEncuestasProvider),
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

// ─────────────────────────────────────────────────────────────────────────────
// ENCUESTA CARD
// ─────────────────────────────────────────────────────────────────────────────

class _EncuestaCard extends ConsumerStatefulWidget {
  final Encuesta encuesta;
  final bool isDark;
  final ThemeData theme;
  final bool isWeb;

  const _EncuestaCard({
    required this.encuesta,
    required this.isDark,
    required this.theme,
    required this.isWeb,
  });

  @override
  ConsumerState<_EncuestaCard> createState() => _EncuestaCardState();
}

class _EncuestaCardState extends ConsumerState<_EncuestaCard> {
  String? _selectedOptionId;
  bool _isVoting = false;
  bool _hasVotedLocally = false;

  @override
  Widget build(BuildContext context) {
    final yaVoto = widget.encuesta.usuarioHaVotado || _hasVotedLocally;
    final activa = widget.encuesta.activa;
    final localTotalVotos = _hasVotedLocally
        ? widget.encuesta.totalVotos + 1
        : widget.encuesta.totalVotos;

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!activa)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _StatusPill(
                            label: 'Finalizada',
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                      Text(
                        widget.encuesta.titulo,
                        style: widget.theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (yaVoto) ...[
                  const SizedBox(width: 12),
                  RvBadge(
                    label: context.tr('polls.user.voted'),
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                  ),
                ],
              ],
            ),

            if (widget.encuesta.descripcion != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.encuesta.descripcion!,
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: widget.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Divisor de marca ─────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 24,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 6,
                  height: 2,
                  decoration: BoxDecoration(
                    color: widget.theme.colorScheme.primary
                        .withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Opciones ─────────────────────────────────────────────────────
            ...widget.encuesta.opciones.asMap().entries.map((entry) {
              final index = entry.key;
              final opc = entry.value;
              final child = Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OpcionItem(
                  opcion: opc,
                  totalVotos: localTotalVotos,
                  yaVoto: yaVoto,
                  isSelected: _selectedOptionId == opc.id,
                  activa: activa,
                  isDark: widget.isDark,
                  theme: widget.theme,
                  localVoto: _hasVotedLocally && _selectedOptionId == opc.id,
                  onSelect: (id) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedOptionId = id);
                  },
                ),
              );

              if (_hasVotedLocally) {
                return child
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 120 * index),
                      duration: 400.ms,
                    )
                    .slideY(
                      begin: 0.15,
                      delay: Duration(milliseconds: 120 * index),
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .scaleXY(
                      begin: 0.95,
                      delay: Duration(milliseconds: 120 * index),
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    );
              }

              return child;
            }),

            // ── Botón votar ──────────────────────────────────────────────────
            if (!yaVoto && activa) ...[
              const SizedBox(height: 8),
              Align(
                alignment: widget.isWeb
                    ? Alignment.centerRight
                    : Alignment.center,
                child: SizedBox(
                  width: widget.isWeb ? 200 : double.infinity,
                  child: RvPrimaryButton(
                    label: context.tr('polls.user.voteButton'),
                    isLoading: _isVoting,
                    onTap: _selectedOptionId == null ? null : _votar,
                    icon: Icons.how_to_vote_rounded,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _votar() async {
    if (_selectedOptionId == null) return;
    setState(() => _isVoting = true);

    final success = await ref
        .read(todasEncuestasProvider.notifier)
        .votar(widget.encuesta.id, _selectedOptionId!);

    if (mounted) {
      setState(() {
        _isVoting = false;
        if (success) _hasVotedLocally = true;
      });
      if (success) {
        HapticFeedback.mediumImpact();
        RvAlerts.success(context, context.tr('polls.user.success'));
      } else {
        RvAlerts.error(context, context.tr('polls.user.error'));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS PILL
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OPCION ITEM
// ─────────────────────────────────────────────────────────────────────────────

class _OpcionItem extends StatelessWidget {
  final EncuestaOpcion opcion;
  final int totalVotos;
  final bool yaVoto;
  final bool isSelected;
  final bool activa;
  final bool isDark;
  final ThemeData theme;
  final bool localVoto;
  final Function(String) onSelect;

  const _OpcionItem({
    required this.opcion,
    required this.totalVotos,
    required this.yaVoto,
    required this.isSelected,
    required this.activa,
    required this.isDark,
    required this.theme,
    required this.onSelect,
    this.localVoto = false,
  });

  @override
  Widget build(BuildContext context) {
    final votos = opcion.votos + (localVoto ? 1 : 0);
    final porcentaje = totalVotos > 0 ? (votos / totalVotos) : 0.0;
    final primary = theme.colorScheme.primary;

    if (yaVoto || !activa) {
      return _ResultBar(
        opcion: opcion,
        votos: votos,
        porcentaje: porcentaje,
        yaVoto: yaVoto,
        isDark: isDark,
        theme: theme,
        primary: primary,
      );
    }

    return _SelectableOption(
      opcion: opcion,
      isSelected: isSelected,
      isDark: isDark,
      theme: theme,
      primary: primary,
      onSelect: onSelect,
    );
  }
}

class _ResultBar extends StatelessWidget {
  final EncuestaOpcion opcion;
  final int votos;
  final double porcentaje;
  final bool yaVoto;
  final bool isDark;
  final ThemeData theme;
  final Color primary;

  const _ResultBar({
    required this.opcion,
    required this.votos,
    required this.porcentaje,
    required this.yaVoto,
    required this.isDark,
    required this.theme,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = yaVoto ? primary : AppColors.lightTextSecondary;
    final isLeading = porcentaje > 0.5;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
          border: Border.all(
            color: isLeading && yaVoto
                ? primary.withValues(alpha: 0.25)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.06)),
            width: isLeading && yaVoto ? 1.5 : 1,
          ),
          boxShadow: isLeading && yaVoto
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: porcentaje),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return FractionallySizedBox(
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: yaVoto
                              ? [
                                  primary.withValues(alpha: 0.20),
                                  primary.withValues(alpha: 0.06),
                                ]
                              : [
                                  barColor.withValues(alpha: 0.10),
                                  barColor.withValues(alpha: 0.04),
                                ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        opcion.texto,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: porcentaje * 100),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return Text(
                              '${value.toStringAsFixed(1)}%',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: yaVoto ? primary : null,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: votos),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (yaVoto ? primary : theme.hintColor)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$value',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: yaVoto ? primary : theme.hintColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableOption extends StatefulWidget {
  final EncuestaOpcion opcion;
  final bool isSelected;
  final bool isDark;
  final ThemeData theme;
  final Color primary;
  final Function(String) onSelect;

  const _SelectableOption({
    required this.opcion,
    required this.isSelected,
    required this.isDark,
    required this.theme,
    required this.primary,
    required this.onSelect,
  });

  @override
  State<_SelectableOption> createState() => _SelectableOptionState();
}

class _SelectableOptionState extends State<_SelectableOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onSelect(widget.opcion.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? widget.primary.withValues(alpha: 0.08)
                : (_hovered
                ? (widget.isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02))
                : (widget.isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02))),
            border: Border.all(
              color: selected
                  ? widget.primary.withValues(alpha: 0.50)
                  : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.07)),
              width: selected ? 2.0 : 1.5,
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: widget.primary.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.opcion.texto,
                  style: widget.theme.textTheme.bodyLarge?.copyWith(
                    fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? widget.primary : null,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? widget.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.20)
                        : Colors.black.withValues(alpha: 0.15)),
                    width: 2,
                  ),
                  boxShadow: selected
                      ? [
                    BoxShadow(
                      color: widget.primary.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                      : null,
                ),
                child: selected
                    ? const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: Colors.white,
                )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON
// ─────────────────────────────────────────────────────────────────────────────

class _VotacionesSkeleton extends StatelessWidget {
  final bool isWeb;
  const _VotacionesSkeleton({required this.isWeb});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding:
      EdgeInsets.fromLTRB(20, isWeb ? 8 : 4, 20, 48),
      itemCount: 3,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RvSkeleton(width: 180, height: 22, borderRadius: 6),
              const SizedBox(height: 10),
              const RvSkeleton(
                  width: double.infinity, height: 14, borderRadius: 4),
              const SizedBox(height: 6),
              const RvSkeleton(width: 220, height: 14, borderRadius: 4),
              const SizedBox(height: 20),
              const RvSkeleton(width: 36, height: 2, borderRadius: 2),
              const SizedBox(height: 16),
              ...List.generate(
                3,
                    (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: RvSkeleton(
                      width: double.infinity,
                      height: 52,
                      borderRadius: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}