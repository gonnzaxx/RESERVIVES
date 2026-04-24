import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/services/auth_service.dart';
import 'package:reservives/widgets/design_system.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoadingMicrosoft = false;
  bool _isLoadingBypass = false;

  Future<void> _loginMicrosoft() async {
    setState(() => _isLoadingMicrosoft = true);
    final error = await ref.read(authServiceProvider).loginWithMicrosoft();
    if (mounted) setState(() => _isLoadingMicrosoft = false);

    if (!mounted) return;
    if (error != null) {
      RvAlerts.error(context, error);
    }
  }

  Future<void> _loginBypass() async {
    setState(() => _isLoadingBypass = true);
    await ref.read(authProvider.notifier).loginDevBypass();
    if (mounted) setState(() => _isLoadingBypass = false);

    if (!mounted) return;
    final error = ref.read(authProvider).error;
    if (error != null) {
      RvAlerts.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const _AnimatedBackground(),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    // Logo sin círculo envolvente
                    Hero(
                      tag: 'ies-logo-hero',
                      child: Image.asset(
                        'assets/images/logo_luis_vives.png',
                        width: 140, // Ligeramente más grande al no tener círculo
                        fit: BoxFit.contain,
                      ),
                    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

                    const SizedBox(height: 40),

                    Text(
                      context.tr('login.welcomeEyebrow'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w800,
                        color: muted?.withOpacity(0.7),
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 8),

                    // Título con negrita máxima
                    Text(
                      context.tr('login.title'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900, // Máximo grosor
                        height: 1.1,
                        fontSize: 32,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),

                    const SizedBox(height: 40),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.4)
                                : Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              RvPrimaryButton(
                                onTap: _isLoadingMicrosoft ? null : _loginMicrosoft,
                                isLoading: _isLoadingMicrosoft,
                                label: context.tr('login.signIn'),
                                customIcon: Image.asset(
                                  'assets/icons/microsoft_icon.png',
                                  width: 30,
                                  height: 30,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _isLoadingBypass ? null : _loginBypass,
                                child: _isLoadingBypass
                                    ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                    : const Text('Entrar sin autenticar (temporal)'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1),
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

class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground();

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                Color.lerp(const Color(0xFF090B10), AppColors.accentPurple, 0.05)!,
                const Color(0xFF090B10),
                Color.lerp(const Color(0xFF090B10), AppColors.primaryBlue, 0.05)!,
              ]
                  : [
                const Color(0xFFF9FAFF),
                const Color(0xFFF2F4FF),
                const Color(0xFFE9F0FF),
              ],
              stops: [
                0.0,
                0.5 + 0.1 * (math.sin(_controller.value * 2 * math.pi)),
                1.0,
              ],
            ),
          ),
          child: Stack(
            children: [
              _Blob(
                color: AppColors.primaryBlue.withOpacity(isDark ? 0.15 : 0.4),
                size: isMobile ? size.width * 0.6 : 400,
                offset: Offset(
                  math.sin(_controller.value * 2 * math.pi) * (isMobile ? 20 : 50),
                  math.cos(_controller.value * 2 * math.pi) * (isMobile ? 15 : 30),
                ),
                alignment: Alignment.topRight,
              ),
              _Blob(
                color: AppColors.accentPurple.withOpacity(isDark ? 0.1 : 0.3),
                size: isMobile ? size.width * 0.4 : 300,
                offset: Offset(
                  math.cos(_controller.value * 2 * math.pi) * (isMobile ? 15 : 40),
                  math.sin(_controller.value * 2 * math.pi) * (isMobile ? 25 : 60),
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
                blurRadius: isMobile ? 60 : 100,
                spreadRadius: isMobile ? 10 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
