import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final faqs = List.generate(8, (i) => {
      'q': loc.translate('faq.q${i + 1}.question'),
      'a': loc.translate('faq.q${i + 1}.answer'),
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
                  child: Row(
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RvPageHeader(
                          title: loc.translate('faq.title'),
                          eyebrow: 'Ayuda',
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
                    itemCount: faqs.length,
                    itemBuilder: (context, index) {
                      final item = faqs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _FaqCard(
                          question: item['q']!,
                          answer: item['a']!,
                        ),
                      );
                    },
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

class _FaqCard extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqCard({required this.question, required this.answer});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RvSurfaceCard(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.question,
                  style: theme.textTheme.titleMedium?.copyWith(
                    // Cambiado de w900 a w700 para que sea menos agresivo
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: theme.textTheme.titleMedium?.color?.withOpacity(0.9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: _isExpanded ? 0.5 : 0,
                child: Icon(
                  Icons.expand_more_rounded,
                  color: theme.hintColor.withOpacity(0.5),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 0,
                maxHeight: _isExpanded ? double.infinity : 0,
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 40, top: 16),
                child: Text(
                  widget.answer,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}