library;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/utils/role_access.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/usuario.dart';
import 'package:reservives/providers/locale_provider.dart';
import 'package:reservives/providers/theme_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tutorial interactivo de bienvenida que se muestra la primera vez
/// que un usuario accede a la aplicación.
class AppTutorialDialog extends StatefulWidget {
  final Usuario user;

  static const _prefKey = 'has_seen_app_tutorial';

  const AppTutorialDialog({super.key, required this.user});

  static String _prefKeyForUser(Usuario user) => '${_prefKey}_${user.id}';

  static Future<bool> shouldShow(Usuario? user) async {
    if (user == null || !user.usesTokens) return false;
    final prefs = await SharedPreferences.getInstance();
    final seenForUser = prefs.getBool(_prefKeyForUser(user)) ?? false;
    final seenLegacy = prefs.getBool(_prefKey) ?? false;
    return !(seenForUser || seenLegacy);
  }

  static Future<void> markAsSeen(Usuario user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyForUser(user), true);
  }

  static Future<void> show(BuildContext context, Usuario user) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, a1, a2) => AppTutorialDialog(user: user),
      transitionBuilder: (ctx2, anim, anim2, child) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  State<AppTutorialDialog> createState() => _AppTutorialDialogState();
}

class _AppTutorialDialogState extends State<AppTutorialDialog>
    with TickerProviderStateMixin {
  static const int _totalSteps = 6;

  int _currentStep = 0;
  int _bookingFlowStep = -1;

  late final AnimationController _tokenAnimController;
  late final Animation<double> _tokenAnimation;
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _tokenAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _tokenAnimation = CurvedAnimation(
      parent: _tokenAnimController,
      curve: Curves.easeOutCubic,
    );
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _tokenAnimController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
        _bookingFlowStep = -1;
      });
      _onStepEntered(_currentStep);
    } else {
      _finish();
    }
  }

  void _onStepEntered(int step) {
    switch (step) {
      case 1:
        _tokenAnimController.forward(from: 0);
      case 2:
        _animateBookingFlow();
      case 4:
        break;
      case 5:
        _confettiController.play();
      default:
        break;
    }
  }

  Future<void> _animateBookingFlow() async {
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 680));
      if (mounted) setState(() => _bookingFlowStep = i);
    }
  }

  Future<void> _finish() async {
    await AppTutorialDialog.markAsSeen(widget.user);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _finish();
      },
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Centramos el diálogo y limitamos su ancho para Web
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Dialog(
                insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height - 96,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(context),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: child,
                            ),
                            child: KeyedSubtree(
                              key: ValueKey(_currentStep),
                              child: _buildCurrentStep(context),
                            ),
                          ),
                        ),
                      ),
                      _buildFooter(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 22,
            emissionFrequency: 0.08,
            gravity: 0.28,
            colors: const [
              AppColors.primaryBlue,
              AppColors.accentPurple,
              AppColors.success,
              AppColors.warning,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
      child: Row(
        children: [
          ...List.generate(_totalSteps, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 6),
              height: 8,
              width: i == _currentStep ? 24 : 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: i <= _currentStep
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.22),
              ),
            );
          }),
          const Spacer(),
          TextButton(
            onPressed: _finish,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              context.tr('tutorial.skip'),
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isLast = _currentStep == _totalSteps - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: RvPrimaryButton(
          label: isLast
              ? context.tr('tutorial.start')
              : context.tr('tutorial.next'),
          onTap: _nextStep,
          icon: isLast
              ? Icons.rocket_launch_rounded
              : Icons.arrow_forward_rounded,
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    return switch (_currentStep) {
      0 => _buildStep1(context),
      1 => _buildStep2(context),
      2 => _buildStep3(context),
      3 => _buildStep4(context),
      4 => _buildStep5(context),
      5 => _buildStep6(context),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildStep1(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              size: 60,
              color: Colors.white,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 28),
          Text(
            context
                .tr('tutorial.step1.title')
                .replaceAll('{name}', widget.user.nombre),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          )
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.15, end: 0, duration: 400.ms),
          const SizedBox(height: 16),
          Text(
            context.tr('tutorial.step1.subtitle'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 360.ms),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStep2(BuildContext context) {
    final theme = Theme.of(context);
    final tokenRatio = (widget.user.tokens / maxUserTokens).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.toll_rounded,
              size: 56,
              color: AppColors.warning,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.07, 1.07),
            duration: 1100.ms,
            curve: Curves.easeInOut,
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('tutorial.step2.title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),
          Text(
            context.tr('tutorial.step2.subtitle'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadii.m),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                Text(
                  context.tr('tutorial.step2.balance'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _tokenAnimation,
                  builder: (ctx, child) {
                    final displayed =
                    (_tokenAnimation.value * widget.user.tokens).round();
                    return Text(
                      '$displayed',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                        letterSpacing: -1,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _tokenAnimation,
                  builder: (ctx, child) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _tokenAnimation.value * tokenRatio,
                      backgroundColor:
                      AppColors.warning.withValues(alpha: 0.18),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.warning),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context
                      .tr('tutorial.step2.max')
                      .replaceAll('{max}', '$maxUserTokens'),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 340.ms).slideY(begin: 0.08, end: 0),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: theme.colorScheme.primary.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('tutorial.step2.hint'),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 560.ms),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStep3(BuildContext context) {
    final theme = Theme.of(context);
    final steps = [
      (
      Icons.search_rounded,
      context.tr('tutorial.step3.step1'),
      AppColors.blue,
      ),
      (
      Icons.calendar_today_rounded,
      context.tr('tutorial.step3.step2'),
      AppColors.accentPurple,
      ),
      (
      Icons.check_circle_rounded,
      context.tr('tutorial.step3.step3'),
      AppColors.success,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_rounded,
              size: 52,
              color: theme.colorScheme.primary,
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          Text(
            context.tr('tutorial.step3.title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),
          Text(
            context.tr('tutorial.step3.subtitle'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 24),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final (icon, label, color) = entry.value;
            final isActive = _bookingFlowStep >= i;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withValues(alpha: 0.09)
                      : theme.cardColor,
                  borderRadius: BorderRadius.circular(AppRadii.m),
                  border: Border.all(
                    color: isActive
                        ? color.withValues(alpha: 0.48)
                        : theme.dividerColor,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isActive
                            ? color.withValues(alpha: 0.14)
                            : theme.scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isActive
                            ? Icon(icon, size: 20, color: color)
                            : Text(
                          '${i + 1}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive ? color : null,
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: isActive ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (i * 110 + 280).ms),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStep4(BuildContext context) {
    final theme = Theme.of(context);
    final rules = [
      context.tr('tutorial.step4.rule1'),
      context.tr('tutorial.step4.rule2'),
      context.tr('tutorial.step4.rule3'),
      context.tr('tutorial.step4.rule4'),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rule_rounded,
              size: 52,
              color: AppColors.blue,
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          Text(
            context.tr('tutorial.step4.title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),
          Text(
            context.tr('tutorial.step4.subtitle'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 24),
          ...rules.asMap().entries.map((entry) {
            final delayMs = 290 + entry.key * 115;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        entry.value,
                        style:
                        theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(delay: delayMs.ms)
                  .slideX(begin: -0.04, end: 0, delay: delayMs.ms),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStep5(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer(
      builder: (context, ref, child) {
        final locale = ref.watch(localeProvider);
        final themeMode = ref.watch(themeProvider);

        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 52,
                  color: AppColors.primaryBlue,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              Text(
                'Configuración rápida',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Antes de empezar, ajusta el idioma y el tema de la app.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _buildConfigCard(
                context: context,
                title: context.tr('settings.language.title'),
                icon: Icons.language_rounded,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(
                      label: context.tr('settings.language.spanish'),
                      selected: locale.languageCode == 'es',
                      onSelected: () => ref
                          .read(localeProvider.notifier)
                          .setLocale(const Locale('es')),
                    ),
                    _buildChoiceChip(
                      label: context.tr('settings.language.english'),
                      selected: locale.languageCode == 'en',
                      onSelected: () => ref
                          .read(localeProvider.notifier)
                          .setLocale(const Locale('en')),
                    ),
                    _buildChoiceChip(
                      label: 'Français',
                      selected: locale.languageCode == 'fr',
                      onSelected: () => ref
                          .read(localeProvider.notifier)
                          .setLocale(const Locale('fr')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildConfigCard(
                context: context,
                title: 'Tema',
                icon: Icons.palette_rounded,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(
                      label: 'Claro',
                      selected: themeMode == ThemeMode.light,
                      onSelected: () => ref
                          .read(themeProvider.notifier)
                          .setThemeMode(ThemeMode.light),
                    ),
                    _buildChoiceChip(
                      label: 'Oscuro',
                      selected: themeMode == ThemeMode.dark,
                      onSelected: () => ref
                          .read(themeProvider.notifier)
                          .setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep6(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              size: 60,
              color: Colors.white,
            ),
          )
              .animate()
              .scale(duration: 600.ms, curve: Curves.easeOutBack)
              .shimmer(delay: 850.ms, duration: 1200.ms),
          const SizedBox(height: 28),
          Text(
            context.tr('tutorial.step5.title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.12, end: 0),
          const SizedBox(height: 16),
          Text(
            context.tr('tutorial.step5.subtitle'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 420.ms),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildConfigCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadii.m),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primaryBlue.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: selected ? AppColors.primaryBlue : null,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected
            ? AppColors.primaryBlue.withValues(alpha: 0.4)
            : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
