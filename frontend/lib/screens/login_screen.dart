import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/branding_provider.dart';
import 'package:reservives/services/auth_service.dart';
import 'package:reservives/widgets/app_logo.dart';
import 'package:reservives/widgets/design_system.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoadingMicrosoft = false;
  bool _isLoadingBypass = false;

  // Inicia sesión con cuenta Microsoft corporativa
  Future<void> _loginMicrosoft() async {
    setState(() => _isLoadingMicrosoft = true);
    final error =
    await ref.read(authServiceProvider).loginWithMicrosoft();
    if (mounted) setState(() => _isLoadingMicrosoft = false);
    if (!mounted) return;
    if (error != null) RvAlerts.error(context, error);
  }

  // Accede como invitado sin autenticación
  Future<void> _loginBypass() async {
    setState(() => _isLoadingBypass = true);
    await ref.read(authProvider.notifier).loginAsGuest();
    if (mounted) setState(() => _isLoadingBypass = false);
    if (!mounted) return;
    final error = ref.read(authProvider).error;
    if (error != null) RvAlerts.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branding = ref.watch(brandingProvider);

    return Scaffold(
      body: Stack(
        children: [
          const _AnimatedBackground(),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    Hero(
                      tag: 'ies-logo-hero',
                      child: SizedBox(
                        width: 130,
                        height: 130,
                        child: const AppLogo(),
                      ),
                    )
                        .animate()
                        .scale(
                        duration: 600.ms,
                        curve: Curves.easeOutBack),

                    const SizedBox(height: 32),

                    Text(
                      context.tr('login.welcomeEyebrow').toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 10),

                    Text(
                      branding.appName ?? context.tr('login.title'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -0.8,
                        color: isDark ? Colors.white : AppColors.info,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 280.ms)
                        .slideY(begin: 0.12, curve: Curves.easeOutCubic),

                    const SizedBox(height: 40),

                    _LoginCard(
                      isDark: isDark,
                      theme: theme,
                      isLoadingMicrosoft: _isLoadingMicrosoft,
                      isLoadingBypass: _isLoadingBypass,
                      onMicrosoft: _loginMicrosoft,
                      onBypass: _loginBypass,
                    )
                        .animate(delay: 380.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(
                      begin: 0.08,
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final bool isLoadingMicrosoft;
  final bool isLoadingBypass;
  final VoidCallback onMicrosoft;
  final VoidCallback onBypass;

  const _LoginCard({
    required this.isDark,
    required this.theme,
    required this.isLoadingMicrosoft,
    required this.isLoadingBypass,
    required this.onMicrosoft,
    required this.onBypass,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.40)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.60),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RvPrimaryButton(
                onTap: isLoadingMicrosoft ? null : onMicrosoft,
                isLoading: isLoadingMicrosoft,
                label: context.tr('login.signIn'),
                customIcon: Image.asset(
                  'assets/icons/microsoft_icon.png',
                  width: 22,
                  height: 22,
                ),
              ),

              const SizedBox(height: 16),

              _Divider(isDark: isDark, theme: theme),

              const SizedBox(height: 16),

              _GuestButton(
                isLoading: isLoadingBypass,
                isDark: isDark,
                theme: theme,
                onTap: onBypass,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _Divider({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: 0.08),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            context.tr('login.or'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _GuestButton extends StatefulWidget {
  final bool isLoading;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _GuestButton({
    required this.isLoading,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_GuestButton> createState() => _GuestButtonState();
}

class _GuestButtonState extends State<_GuestButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: widget.isLoading
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.isLoading
            ? null
            : (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 52,
            decoration: BoxDecoration(
              color: _hovered
                  ? (widget.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isDark
                    ? Colors.white.withValues(
                    alpha: _hovered ? 0.20 : 0.10)
                    : Colors.black.withValues(
                    alpha: _hovered ? 0.14 : 0.08),
                width: 1.5,
              ),
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.isDark
                      ? Colors.white70
                      : Colors.black54,
                ),
              )
                  : Text(
                context.tr('login.without.account'),
                style: widget.theme.textTheme.labelLarge
                    ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground();

  @override
  State<_AnimatedBackground> createState() =>
      _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Arranca la animación de fondo en bucle infinito de 15 segundos
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Construye el fondo con gradiente animado y blobs de color
  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                Color.lerp(const Color(0xFF090B10),
                    AppColors.accentPurple, 0.15)!,
                const Color(0xFF090B10),
                Color.lerp(const Color(0xFF090B10),
                    AppColors.primaryBlue, 0.15)!,
              ]
                  : [
                const Color(0xFFF9FAFF),
                const Color(0xFFF2F4FF),
                const Color(0xFFE9F0FF),
              ],
              stops: [
                0.0,
                0.5 + 0.08 * math.sin(t),
                1.0,
              ],
            ),
          ),
          child: Stack(
            children: [
              _Blob(
                color: AppColors.primaryBlue
                    .withValues(alpha: isDark ? 0.14 : 0.35),
                size: isMobile ? size.width * 0.60 : 400,
                offset: Offset(
                  math.sin(t) * (isMobile ? 20 : 50),
                  math.cos(t) * (isMobile ? 15 : 30),
                ),
                alignment: Alignment.topRight,
              ),
              _Blob(
                color: AppColors.accentPurple
                    .withValues(alpha: isDark ? 0.10 : 0.30),
                size: isMobile ? size.width * 0.40 : 320,
                offset: Offset(
                  math.cos(t) * (isMobile ? 15 : 40),
                  math.sin(t) * (isMobile ? 25 : 60),
                ),
                alignment: Alignment.bottomLeft,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  final Offset offset;
  final Alignment alignment;

  const _Blob({
    required this.color,
    required this.size,
    required this.offset,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color,
                blurRadius: isMobile ? 70 : 110,
                spreadRadius: isMobile ? 12 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

