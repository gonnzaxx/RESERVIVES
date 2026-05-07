import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';


class RestrictedFeatureScreen extends ConsumerStatefulWidget {
  const RestrictedFeatureScreen({super.key});

  @override
  ConsumerState<RestrictedFeatureScreen> createState() =>
      _RestrictedFeatureScreenState();
}

class _RestrictedFeatureScreenState
    extends ConsumerState<RestrictedFeatureScreen>
    with TickerProviderStateMixin {

  late final AnimationController _enterCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _scalePulse;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _fadeIn = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    _scalePulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: Stack(
              children: [
                // Fondo
                Positioned.fill(
                  child: _BackgroundDecoration(isDark: isDark),
                ),

                // Contenido centrado
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: SlideTransition(
                          position: _slideUp,
                          child: _RestrictedCard(
                            isDark: isDark,
                            scalePulse: _scalePulse,
                            onLogin: () async {
                              await ref
                                  .read(authProvider.notifier)
                                  .logout();
                              if (context.mounted) {
                                context.goNamed('login');
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Botón volver
                Positioned(
                  top: 16,
                  left: 16,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: _BackButton(
                      isDark: isDark,
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.goNamed('home');
                        }
                      },
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

// Tarjeta principal
class _RestrictedCard extends StatelessWidget {
  final bool isDark;
  final Animation<double> scalePulse;
  final VoidCallback onLogin;

  const _RestrictedCard({
    required this.isDark,
    required this.scalePulse,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final borderColor =
    isDark ? AppColors.darkDivider : AppColors.lightCard;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.07),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // icono con anillo
            _PulsingIcon(scalePulse: scalePulse, isDark: isDark),

            const SizedBox(height: 32),

            // Etiqueta
            _StatusChip(isDark: isDark, label: context.tr('restricted.chip')),

            const SizedBox(height: 16),

            // Título
            Text(
              context.tr('restricted.title'),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -1.0,
                color: isDark ? Colors.white : AppColors.darkBackground,
              ),
            ),

            const SizedBox(height: 16),

            // Descripción
            Text(
              context.tr('restricted.description'),
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppColors.lightTextSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 32),

            // Divisor con texto
            _Divider(isDark: isDark, label: context.tr('restricted.divider')),

            const SizedBox(height: 32),

            // Botón de login
            _LoginButton(onTap: onLogin, label: context.tr('restricted.loginButton')),

            const SizedBox(height: 14),

            // Texto de ayuda
            Center(
              child: Text(
                context.tr('restricted.helpText'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.lightTextSecondary,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// icono pulsante
class _PulsingIcon extends StatelessWidget {
  final Animation<double> scalePulse;
  final bool isDark;

  const _PulsingIcon({required this.scalePulse, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scalePulse,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.accentPurple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.accentPurple.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.lock_rounded,
          size: 28,
          color: AppColors.accentPurple,
        ),
      ),
    );
  }
}

// Chip de estado
class _StatusChip extends StatelessWidget {
  final bool isDark;
  final String label;
  const _StatusChip({required this.isDark, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: AppColors.accentBlue.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.accentBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accentBlue,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// Divisor
class _Divider extends StatelessWidget {
  final bool isDark;
  final String label;
  const _Divider({required this.isDark, required this.label});

  @override
  Widget build(BuildContext context) {
    final lineColor =
    isDark ? AppColors.darkDivider : AppColors.lightCard;

    return Row(
      children: [
        Expanded(child: Container(height: 1, color: lineColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.lightTextSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: lineColor)),
      ],
    );
  }
}

// Botón de login
class _LoginButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  const _LoginButton({required this.onTap, required this.label});

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.accentPurple,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPurple.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.login_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Botón volver
class _BackButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _BackButton({required this.isDark, required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark
        ? Colors.white.withValues(alpha: _hovered ? 0.12 : 0.07)
        : Colors.black.withValues(alpha: _hovered ? 0.08 : 0.04);
    final border = widget.isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.85)
                : AppColors.darkBackground.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}

// Fondo decorativo
class _BackgroundDecoration extends StatelessWidget {
  final bool isDark;
  const _BackgroundDecoration({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BgPainter(isDark: isDark),
    );
  }
}

class _BgPainter extends CustomPainter {
  final bool isDark;
  const _BgPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Círculo top-right
    final paintAccent = Paint()
      ..color = AppColors.accentBlue.withValues(alpha: isDark ? 0.06 : 0.08)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.12),
      size.width * 0.38,
      paintAccent,
    );

    // Círculo bottom-left
    final paintWarm = Paint()
      ..color = AppColors.accentPurple.withValues(alpha: isDark ? 0.05 : 0.07)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.88),
      size.width * 0.30,
      paintWarm,
    );

    final dotPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: isDark ? 0.04 : 0.035)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    final cols = (size.width / spacing).ceil();
    final rows = (size.height / spacing).ceil();

    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= cols; c++) {
        canvas.drawCircle(
          Offset(c * spacing, r * spacing),
          1.2,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BgPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}