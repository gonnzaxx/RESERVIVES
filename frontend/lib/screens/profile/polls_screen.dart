import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/encuesta.dart';
import 'package:reservives/providers/polls_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/app_theme.dart';

class VotacionesScreen extends ConsumerWidget {
  const VotacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;
    final encuestasAsync = ref.watch(todasEncuestasProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('polls.user.title'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                        onRefresh: () => ref.read(todasEncuestasProvider.notifier).refresh(),
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(20, isWeb ? 16 : 4, 20, 100),
                          itemCount: encuestas.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _EncuestaCard(encuesta: encuestas[index]),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const _VotacionesSkeleton(),
                    error: (e, _) => Center(
                      child: RvApiErrorState(
                        onRetry: () => ref.invalidate(todasEncuestasProvider),
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

class _EncuestaCard extends ConsumerStatefulWidget {
  final Encuesta encuesta;
  const _EncuestaCard({required this.encuesta});

  @override
  ConsumerState<_EncuestaCard> createState() => _EncuestaCardState();
}

class _EncuestaCardState extends ConsumerState<_EncuestaCard> {
  String? _selectedOptionId;
  bool _isVoting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yaVoto = widget.encuesta.usuarioHaVotado;
    final isWeb = MediaQuery.of(context).size.width > 700;

    return RvSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.encuesta.titulo,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (yaVoto)
                RvBadge(
                  label: context.tr('polls.user.voted'),
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
            ],
          ),
          if (widget.encuesta.descripcion != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.encuesta.descripcion!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ...widget.encuesta.opciones.map((opc) {
            final isSelected = _selectedOptionId == opc.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OpcionItem(
                opcion: opc,
                totalVotos: widget.encuesta.totalVotos,
                yaVoto: yaVoto,
                isSelected: isSelected,
                activa: widget.encuesta.activa,
                onSelect: (id) => setState(() => _selectedOptionId = id),
              ),
            );
          }),
          if (!yaVoto && widget.encuesta.activa) ...[
            const SizedBox(height: 12),
            Align(
              alignment: isWeb ? Alignment.centerRight : Alignment.center,
              child: SizedBox(
                width: isWeb ? 200 : double.infinity,
                child: RvPrimaryButton(
                  label: context.tr('polls.user.voteButton'),
                  isLoading: _isVoting,
                  onTap: _selectedOptionId == null ? null : _votar,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              if (!widget.encuesta.activa)
                RvBadge(
                  label: "FINALIZADA",
                  color: theme.disabledColor,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _votar() async {
    if (_selectedOptionId == null) return;
    setState(() => _isVoting = true);

    final success = await ref.read(todasEncuestasProvider.notifier).votar(
      widget.encuesta.id,
      _selectedOptionId!,
    );

    if (mounted) {
      setState(() => _isVoting = false);
      if (success) {
        // Mostramos el alert de éxito
        RvAlerts.success(
          context,
          context.tr('polls.user.success'),
        );
      } else {
        // Mostramos el alert de error
        RvAlerts.error(
          context,
          context.tr('polls.user.error'),
        );
      }
    }
  }
}

class _OpcionItem extends StatelessWidget {
  final EncuestaOpcion opcion;
  final int totalVotos;
  final bool yaVoto;
  final bool isSelected;
  final bool activa;
  final Function(String) onSelect;

  const _OpcionItem({
    required this.opcion,
    required this.totalVotos,
    required this.yaVoto,
    required this.isSelected,
    required this.activa,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final porcentaje = totalVotos > 0 ? (opcion.votos / totalVotos) : 0.0;

    if (yaVoto || !activa) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.dividerColor.withValues(alpha: 0.05),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: porcentaje),
                duration: const Duration(seconds: 1),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (yaVoto ? AppColors.primaryBlue : Colors.grey).withValues(alpha: 0.25),
                            (yaVoto ? AppColors.primaryBlue : Colors.grey).withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
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
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: porcentaje * 100),
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Text(
                          '${value.toStringAsFixed(1)}%',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: yaVoto ? AppColors.primaryBlue : null,
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => onSelect(opcion.id),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : theme.dividerColor.withValues(alpha: 0.2),
            width: isSelected ? 2.5 : 1.5,
          ),
          color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.08) : theme.cardColor,
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.15),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ] : [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                opcion.texto,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? AppColors.primaryBlue : null,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primaryBlue : theme.dividerColor.withValues(alpha: 0.4),
                  width: isSelected ? 0 : 2,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ] : [],
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _VotacionesSkeleton extends StatelessWidget {
  const _VotacionesSkeleton();

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 700;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20, isWeb ? 16 : 4, 20, 20),
      itemCount: 3,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: RvSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RvSkeleton(width: 200, height: 24),
              const SizedBox(height: 12),
              const RvSkeleton(width: double.infinity, height: 16),
              const SizedBox(height: 24),
              ...List.generate(3, (index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: RvSkeleton(width: double.infinity, height: 52, borderRadius: 12),
              )),
            ],
          ),
        ),
      ),
    );
  }
}