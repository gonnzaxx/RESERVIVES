import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/models/usuario.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/branding_provider.dart';

bool _aiChatFabAnimPlayed = false;

class AiChatFab extends ConsumerStatefulWidget {
  final bool isGuest;

  const AiChatFab({
    super.key,
    required this.isGuest,
  });

  @override
  ConsumerState<AiChatFab> createState() => _AiChatFabState();
}

class _AiChatFabState extends ConsumerState<AiChatFab>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePlayLoginAnim());
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  Future<void> _maybePlayLoginAnim() async {
    if (!mounted) return;
    if (widget.isGuest) return;
    if (_aiChatFabAnimPlayed) return;
    _aiChatFabAnimPlayed = true;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isHovered = true);
    _spinCtrl.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    setState(() => _isHovered = false);
  }

  void _onHoverEnter(_) {
    setState(() => _isHovered = true);
    _spinCtrl.forward(from: 0);
  }

  void _onHoverExit(_) {
    setState(() => _isHovered = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGuest) return const SizedBox.shrink();

    final branding = ref.watch(brandingProvider);
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.rol == RolUsuario.administrador;

    if (!branding.iaHabilitada && !isAdmin) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: _onHoverEnter,
      onExit: _onHoverExit,
      child: GestureDetector(
        onTap: () => context.pushNamed('ai_chat'),
        child: AnimatedContainer(
          duration: 350.ms,
          curve: Curves.easeOutQuart,
          height: 56,
          constraints: BoxConstraints(minWidth: _isHovered ? 0 : 56),
          padding: EdgeInsets.symmetric(horizontal: _isHovered ? 16 : 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.18 : 0.10),
                blurRadius: _isHovered ? 20 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotationTransition(
                turns: _spinCtrl,
                child: ClipOval(
                  child: Image.asset(
                    'assets/icons/vivi_icon.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              AnimatedSize(
                duration: 300.ms,
                curve: Curves.easeOutCubic,
                child: Container(
                  width: _isHovered ? null : 0,
                  padding: EdgeInsets.only(left: _isHovered ? 10 : 0),
                  child: AnimatedOpacity(
                    opacity: _isHovered ? 1 : 0,
                    duration: 200.ms,
                    child: Text(
                      context.tr('home.chat.ai.question'),
                      style: const TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0);
  }
}
