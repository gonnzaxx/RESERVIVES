library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/notificacion.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/widgets/design_system.dart';

int _parseTokenCount(String mensaje) {
  final match = RegExp(r'\d+').firstMatch(mensaje);
  return int.tryParse(match?.group(0) ?? '') ?? 0;
}

class TokensRechargeScreen extends ConsumerWidget {
  const TokensRechargeScreen({
    super.key,
    required this.notificacion,
  });

  final Notificacion notificacion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final tokenCount = _parseTokenCount(notificacion.mensaje);
    final currentBalance = user?.tokens ?? tokenCount;
    final dateFormat = DateFormat(
      'dd/MM/yyyy · HH:mm',
      Localizations.localeOf(context).languageCode,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
                  child: Row(
                    children: [
                      RvGhostIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => context.canPop() ? context.pop() : context.goNamed('home'),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 250.ms),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),

                        _TokenHero(
                          tokenCount: tokenCount,
                          isDark: isDark,
                          theme: theme,
                        ),

                        const SizedBox(height: 48),

                        _StatRow(
                          tokenCount: tokenCount,
                          currentBalance: currentBalance,
                          date: notificacion.createdAt,
                          dateFormat: dateFormat,
                          isDark: isDark,
                          theme: theme,
                        ),

                        const SizedBox(height: 32),

                        _MessageCard(
                          mensaje: notificacion.mensaje,
                          isDark: isDark,
                          theme: theme,
                        ),

                        const SizedBox(height: 40),

                        RvPrimaryButton(
                          onTap: () => context.goNamed('home'),
                          label: context.tr('common.understood'),
                          icon: Icons.check_rounded,
                        )
                            .animate()
                            .fadeIn(delay: 900.ms, duration: 400.ms)
                            .slideY(begin: 0.2, end: 0, delay: 900.ms, duration: 400.ms, curve: Curves.easeOutCubic),
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
}

class _TokenHero extends StatelessWidget {
  const _TokenHero({
    required this.tokenCount,
    required this.isDark,
    required this.theme,
  });

  final int tokenCount;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AnimatedTokenIcon(isDark: isDark)
            .animate()
            .fadeIn(delay: 100.ms, duration: 500.ms)
            .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), delay: 100.ms, duration: 500.ms, curve: Curves.elasticOut),

        const SizedBox(height: 28),

        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: tokenCount),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutExpo,
          builder: (context, value, _) {
            return Text(
              '+$value',
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
                foreground: Paint()
                  ..shader = AppColors.brandGradient.createShader(
                    const Rect.fromLTWH(0, 0, 200, 80),
                  ),
              ),
            );
          },
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms),

        const SizedBox(height: 8),

        Text(
          context.tr('tokens.recharge.tokensAdded'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            letterSpacing: 0.2,
          ),
        )
            .animate()
            .fadeIn(delay: 350.ms, duration: 400.ms)
            .slideY(begin: 0.3, end: 0, delay: 350.ms, duration: 400.ms, curve: Curves.easeOutCubic),
      ],
    );
  }
}

class _AnimatedTokenIcon extends StatefulWidget {
  const _AnimatedTokenIcon({required this.isDark});

  final bool isDark;

  @override
  State<_AnimatedTokenIcon> createState() => _AnimatedTokenIconState();
}

class _AnimatedTokenIconState extends State<_AnimatedTokenIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: widget.isDark ? 0.45 : 0.30),
              blurRadius: 32,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.toll_rounded,
          color: Colors.white,
          size: 44,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.tokenCount,
    required this.currentBalance,
    required this.date,
    required this.dateFormat,
    required this.isDark,
    required this.theme,
  });

  final int tokenCount;
  final int currentBalance;
  final DateTime date;
  final DateFormat dateFormat;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.add_circle_outline_rounded,
            iconColor: AppColors.success,
            label: context.tr('tokens.recharge.recharged'),
            value: '+$tokenCount',
            valueColor: AppColors.success,
            isDark: isDark,
            theme: theme,
            delay: 500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.primaryBlue,
            label: context.tr('tokens.recharge.currentBalance'),
            value: '$currentBalance',
            isDark: isDark,
            theme: theme,
            delay: 620,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
    required this.isDark,
    required this.theme,
    required this.delay,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isDark;
  final ThemeData theme;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .slideY(begin: 0.15, end: 0, delay: Duration(milliseconds: delay), duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.mensaje,
    required this.isDark,
    required this.theme,
  });

  final String mensaje;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              mensaje,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 750.ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0, delay: 750.ms, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}
