import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = MediaQuery.of(context).size.width > 850;

    final faqs = List.generate(
      8,
          (i) => _FaqData(
        question: loc.translate('faq.q${i + 1}.question'),
        answer: loc.translate('faq.q${i + 1}.answer'),
      ),
    );

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
                  EdgeInsets.fromLTRB(8, 12, 20, isWeb ? 24 : 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.translate('faq.eyebrow').toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w700,
                                color: theme.hintColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.translate('faq.title'),
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
                    padding: EdgeInsets.fromLTRB(
                        20, isWeb ? 4 : 0, 20, 60),
                    child: isWeb
                        ? _WebGrid(
                        faqs: faqs, isDark: isDark, theme: theme)
                        : _MobileList(
                        faqs: faqs, isDark: isDark, theme: theme),
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

class _FaqData {
  final String question;
  final String answer;
  const _FaqData({required this.question, required this.answer});
}

class _MobileList extends StatelessWidget {
  final List<_FaqData> faqs;
  final bool isDark;
  final ThemeData theme;

  const _MobileList({
    required this.faqs,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < faqs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FaqCard(
              faq: faqs[i],
              isDark: isDark,
              theme: theme,
            )
                .animate()
                .fadeIn(
              delay: Duration(milliseconds: 60 + 40 * i),
              duration: 280.ms,
            )
                .slideY(
              begin: 0.04,
              delay: Duration(milliseconds: 60 + 40 * i),
              duration: 280.ms,
              curve: Curves.easeOutCubic,
            ),
          ),
      ],
    );
  }
}

class _WebGrid extends StatelessWidget {
  final List<_FaqData> faqs;
  final bool isDark;
  final ThemeData theme;

  const _WebGrid({
    required this.faqs,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final left = <_FaqData>[];
    final right = <_FaqData>[];
    for (int i = 0; i < faqs.length; i++) {
      i.isEven ? left.add(faqs[i]) : right.add(faqs[i]);
    }

    Widget col(List<_FaqData> items, int offset) => Column(
      children: [
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FaqCard(
              faq: items[i],
              isDark: isDark,
              theme: theme,
            )
                .animate()
                .fadeIn(
              delay: Duration(
                  milliseconds: 60 + 40 * (i * 2 + offset)),
              duration: 280.ms,
            )
                .slideY(
              begin: 0.04,
              delay: Duration(
                  milliseconds: 60 + 40 * (i * 2 + offset)),
              duration: 280.ms,
              curve: Curves.easeOutCubic,
            ),
          ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: col(left, 0)),
        const SizedBox(width: 16),
        Expanded(child: col(right, 1)),
      ],
    );
  }
}

class _FaqCard extends StatefulWidget {
  final _FaqData faq;
  final bool isDark;
  final ThemeData theme;

  const _FaqCard({
    required this.faq,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.l),
            border: Border.all(
              color: _expanded
                  ? primary.withValues(alpha: 0.30)
                  : (_hovered
                  ? primary.withValues(alpha: 0.18)
                  : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05))),
              width: 1.5,
            ),
            boxShadow: _expanded || _hovered
                ? AppShadows.deep(context)
                : AppShadows.soft(context),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _expanded
                            ? primary.withValues(alpha: 0.14)
                            : primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.help_outline_rounded,
                        size: 17,
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          widget.faq.question,
                          style: widget.theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: _expanded ? primary : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 220),
                        turns: _expanded ? 0.5 : 0,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: _expanded
                              ? primary
                              : widget.theme.hintColor
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: _expanded
                      ? Padding(
                    padding: const EdgeInsets.only(
                        left: 50, top: 14, bottom: 2),
                    child: Text(
                      widget.faq.answer,
                      style: widget.theme.textTheme.bodyMedium?.copyWith(
                        height: 1.65,
                        color: widget.isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}