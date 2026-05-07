import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/chat_provider.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(aiChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final isGuest = auth.isGuest;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = MediaQuery.of(context).size.width > 700;

    final userName = (user?.nombre.trim().isNotEmpty ?? false)
        ? user!.nombre.trim()
        : context.tr('common.user');

    final chatState = ref.watch(aiChatProvider);
    final messages = chatState.messages;
    final isLoading = chatState.isLoading;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: Column(
              children: [
                _Header(
                  isGuest: isGuest,
                  isWeb: isWeb,
                  isDark: isDark,
                  theme: theme,
                  onNewChat: () {
                    ref.read(aiChatProvider.notifier).resetChat();
                    _scrollToBottom();
                  },
                ),

                Expanded(
                  child: messages.isEmpty
                      ? RvEmptyState(
                    icon: Icons.wechat_sharp,
                    title: context
                        .tr('ai.empty.title')
                        .replaceAll('{name}', userName),
                    subtitle: context.tr('ai.empty.subtitle'),
                  )
                      : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        20, 10, 20, 20),
                    itemCount:
                    messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (isLoading &&
                          index == messages.length) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
                            child: _TypingIndicator(
                                isDark: isDark, theme: theme),
                          ),
                        );
                      }

                      final message = messages[index];
                      final isUser =
                          message.role == AiChatRole.user;

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6),
                          child: _ChatBubble(
                            isUser: isUser,
                            message: message.text,
                            isDark: isDark,
                            theme: theme,
                            maxWidth: isWeb
                                ? 600
                                : screenWidth * 0.78,
                          )
                              .animate()
                              .fadeIn(duration: 350.ms)
                              .slideX(
                            begin: isUser ? 0.08 : -0.08,
                            duration: 350.ms,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                _InputBar(
                  controller: _controller,
                  isLoading: isLoading,
                  isDark: isDark,
                  theme: theme,
                  onSend: _sendMessage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isGuest;
  final bool isWeb;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onNewChat;

  const _Header({
    required this.isGuest,
    required this.isWeb,
    required this.isDark,
    required this.theme,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 12, 12, isWeb ? 20 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isGuest) ...[
            RvGhostIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => context.canPop()
                  ? context.pop()
                  : context.goNamed('home'),
            ),
            const SizedBox(width: 4),
          ] else
            const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('ai.header.eyebrow').toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w700,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('ai.header.title'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
          ),
          _NewChatButton(
              isDark: isDark, theme: theme, onTap: onNewChat),
        ],
      ),
    );
  }
}

class _NewChatButton extends StatefulWidget {
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _NewChatButton({
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_NewChatButton> createState() => _NewChatButtonState();
}

class _NewChatButtonState extends State<_NewChatButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.theme.colorScheme.primary
                .withValues(alpha: 0.10)
                : widget.theme.colorScheme.primary
                .withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? widget.theme.colorScheme.primary
                  .withValues(alpha: 0.30)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_comment_rounded,
                size: 16,
                color: widget.theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                context.tr('ai.actions.newChat'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final bool isDark;
  final ThemeData theme;

  const _TypingIndicator(
      {required this.isDark, required this.theme});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppColors.darkCard
            : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
        ),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final phase = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
              final bounce = (phase < 0.5
                  ? phase * 2
                  : (1 - phase) * 2) *
                  6;
              return Padding(
                padding:
                EdgeInsets.only(right: i < 2 ? 5 : 0),
                child: Transform.translate(
                  offset: Offset(0, -bounce),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: widget.theme.colorScheme.primary
                          .withValues(alpha: 0.50),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final String message;
  final bool isDark;
  final ThemeData theme;
  final double maxWidth;

  const _ChatBubble({
    required this.isUser,
    required this.message,
    required this.isDark,
    required this.theme,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;

    if (isUser) {
      return Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            height: 1.55,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.white.withValues(alpha: 0.80),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : primary.withValues(alpha: 0.10),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.90)
                  : AppColors.lightText,
              height: 1.6,
              fontSize: 15,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.isDark,
    required this.theme,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.07),
                  width: 1.5,
                ),
                boxShadow: AppShadows.soft(context),
              ),
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 5,
                style: theme.textTheme.bodyMedium,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: context.tr('ai.input.placeholder'),
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _SendButton(
            onTap: onSend,
            isLoading: isLoading,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;
  final ThemeData theme;

  const _SendButton({
    required this.onTap,
    required this.isLoading,
    required this.theme,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;

    return GestureDetector(
      onTapDown: widget.isLoading
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.isLoading
          ? null
          : (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: widget.isLoading
                ? primary.withValues(alpha: 0.50)
                : primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.isLoading
                ? null
                : [
              BoxShadow(
                color: primary.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}