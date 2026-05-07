import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:url_launcher/url_launcher.dart';

class IesInfoScreen extends StatelessWidget {
  const IesInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = MediaQuery.of(context).size.width > 800;

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
                  EdgeInsets.fromLTRB(8, 12, 20, isWeb ? 20 : 8),
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
                              context.tr('profile.accountEyebrow').toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w700,
                                color: theme.hintColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('iesinfo.title'),
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
                        20, isWeb ? 8 : 4, 20, 48),
                    child: isWeb
                        ? _WebLayout(isDark: isDark, theme: theme)
                        : _MobileLayout(isDark: isDark, theme: theme),
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

class _MobileLayout extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _MobileLayout({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroCard(isDark: isDark, theme: theme)
            .animate()
            .fadeIn(delay: 80.ms, duration: 350.ms)
            .slideY(begin: 0.04, delay: 80.ms, duration: 350.ms, curve: Curves.easeOutCubic),

        const SizedBox(height: 20),

        _ContactCard(isDark: isDark, theme: theme)
            .animate()
            .fadeIn(delay: 140.ms, duration: 350.ms)
            .slideY(begin: 0.04, delay: 140.ms, duration: 350.ms, curve: Curves.easeOutCubic),

        const SizedBox(height: 28),

        _SectionLabel(label: context.tr('iesinfo.sections.title'), theme: theme, isDark: isDark)
            .animate()
            .fadeIn(delay: 180.ms, duration: 300.ms),

        const SizedBox(height: 12),

        _SectionsGroup(isDark: isDark, theme: theme)
            .animate()
            .fadeIn(delay: 200.ms, duration: 350.ms)
            .slideY(begin: 0.04, delay: 200.ms, duration: 350.ms, curve: Curves.easeOutCubic),

        const SizedBox(height: 32),

        _Footer(theme: theme)
            .animate()
            .fadeIn(delay: 240.ms, duration: 300.ms),
      ],
    );
  }
}

class _WebLayout extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _WebLayout({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _HeroCard(isDark: isDark, theme: theme)
                  .animate()
                  .fadeIn(delay: 80.ms, duration: 350.ms)
                  .slideY(begin: 0.04, delay: 80.ms, duration: 350.ms, curve: Curves.easeOutCubic),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContactCard(isDark: isDark, theme: theme)
                      .animate()
                      .fadeIn(delay: 120.ms, duration: 350.ms)
                      .slideY(begin: 0.04, delay: 120.ms, duration: 350.ms, curve: Curves.easeOutCubic),

                  const SizedBox(height: 20),

                  _SectionLabel(
                    label: context.tr('iesinfo.sections.title'),
                    theme: theme,
                    isDark: isDark,
                  ).animate().fadeIn(delay: 160.ms, duration: 300.ms),

                  const SizedBox(height: 12),

                  _SectionsGroup(isDark: isDark, theme: theme)
                      .animate()
                      .fadeIn(delay: 180.ms, duration: 350.ms)
                      .slideY(begin: 0.04, delay: 180.ms, duration: 350.ms, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        _Footer(theme: theme)
            .animate()
            .fadeIn(delay: 220.ms, duration: 300.ms),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _HeroCard({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.darkHeroGradient
            : AppColors.lightHeroGradient,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,

            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  AppAssets.logoPathForTheme(theme.brightness),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            context.tr('iesinfo.header.name'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),

          const SizedBox(height: 10),

          RvBadge(
            label: context.tr('iesinfo.badge.label'),
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFD4A017),
          ),

          const SizedBox(height: 12),

          Text(
            context.tr('iesinfo.address'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          Divider(
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: 0.08),
            height: 1,
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _SocialButton(
                imagePath: 'assets/icons/youtube_icon.png',
                url:
                'https://www.youtube.com/channel/UCj7gHk5ClkuXJnzwnE1IJiQ',
              ),
              SizedBox(width: 20),
              _SocialButton(
                imagePath: 'assets/icons/x_icon.png',
                url: 'https://twitter.com/ies_luisvives',
              ),
              SizedBox(width: 20),
              _SocialButton(
                imagePath: 'assets/icons/linkedin_icon.png',
                url:
                'https://www.linkedin.com/company/ies-luis-vives/',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _ContactCard({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    final contacts = [
      _ContactData(
        icon: Icons.badge_rounded,
        label: context.tr('iesinfo.contact.code.label'),
        value: context.tr('iesinfo.contact.code.value'),
        color: AppColors.primaryBlue,
      ),
      _ContactData(
        icon: Icons.phone_rounded,
        label: context.tr('iesinfo.contact.phone.label'),
        value: context.tr('iesinfo.contact.phone.value'),
        color: AppColors.success,
        url: 'tel:916807712',
      ),
      _ContactData(
        icon: Icons.email_rounded,
        label: context.tr('iesinfo.contact.email.label'),
        value: context.tr('iesinfo.contact.email.value'),
        color: AppColors.accentPurple,
        url: 'mailto:secretaria@iesluisvives.org',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.l),
        child: Column(
          children: [
            for (int i = 0; i < contacts.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  indent: 68,
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              _ContactTile(
                  data: contacts[i], isDark: isDark, theme: theme),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? url;

  const _ContactData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.url,
  });
}

class _ContactTile extends StatefulWidget {
  final _ContactData data;
  final bool isDark;
  final ThemeData theme;

  const _ContactTile({
    required this.data,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_ContactTile> createState() => _ContactTileState();
}

class _ContactTileState extends State<_ContactTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tappable = widget.data.url != null;

    return MouseRegion(
      cursor: tappable
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: tappable
            ? () => launchUrl(Uri.parse(widget.data.url!))
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: _hovered && tappable
              ? (widget.isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02))
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.data.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.data.icon,
                    color: widget.data.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.label,
                      style: widget.theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: widget.isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.data.value,
                      style: widget.theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (tappable)
                Icon(
                  Icons.open_in_new_rounded,
                  size: 15,
                  color: widget.data.color.withValues(
                      alpha: _hovered ? 0.80 : 0.40),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final ThemeData theme;
  final bool isDark;

  const _SectionLabel({
    required this.label,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 3,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 8,
          height: 3,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _SectionsGroup extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _SectionsGroup({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    final sections = [
      _SectionData(
        icon: Icons.groups_rounded,
        color: AppColors.primaryBlue,
        title: context.tr('iesinfo.sections.who.title'),
        subtitle: context.tr('iesinfo.sections.who.subtitle'),
        onTap: () => context.pushNamed('ies_info_who'),
      ),
      _SectionData(
        icon: Icons.apartment_rounded,
        color: AppColors.accentPurple,
        title: context.tr('iesinfo.sections.facilities.title'),
        subtitle: context.tr('iesinfo.sections.facilities.subtitle'),
        onTap: () => context.pushNamed('ies_info_facilities'),
      ),
      _SectionData(
        icon: Icons.workspace_premium_rounded,
        color: AppColors.success,
        title: context.tr('iesinfo.sections.services.title'),
        subtitle: context.tr('iesinfo.sections.services.subtitle'),
        onTap: () => context.pushNamed('ies_info_services'),
      ),
      _SectionData(
        icon: Icons.menu_book_rounded,
        color: AppColors.warning,
        title: context.tr('iesinfo.sections.studies.title'),
        subtitle: context.tr('iesinfo.sections.studies.subtitle'),
        onTap: () => context.pushNamed('ies_info_studies'),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.l),
        child: Column(
          children: [
            for (int i = 0; i < sections.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  indent: 68,
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              _SectionTile(
                  data: sections[i], isDark: isDark, theme: theme),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SectionData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _SectionTile extends StatefulWidget {
  final _SectionData data;
  final bool isDark;
  final ThemeData theme;

  const _SectionTile({
    required this.data,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_SectionTile> createState() => _SectionTileState();
}

class _SectionTileState extends State<_SectionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.data.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: _hovered
              ? (widget.isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02))
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.data.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.data.icon,
                    color: widget.data.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.title,
                      style: widget.theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.data.subtitle,
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                        color: widget.isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: _hovered
                      ? widget.data.color
                      : widget.theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatefulWidget {
  final ThemeData theme;
  const _Footer({required this.theme});

  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.theme.brightness == Brightness.dark;

    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => launchUrl(
            Uri.parse('https://www.iesluisvives.es'),
            mode: LaunchMode.externalApplication,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.primaryBlue.withValues(alpha: 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: 'Para más información, visita la ',
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: 'web oficial del instituto',
                          style: widget.theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primaryBlue
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
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

class _SocialButton extends StatefulWidget {
  final String imagePath;
  final String url;

  const _SocialButton({required this.imagePath, required this.url});

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _hovered = false;

  Future<void> _launch() async {
    final uri = Uri.parse(widget.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir ${widget.url}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _launch,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _hovered
                ? (isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.06))
                : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Center(
            child: Image.asset(
              widget.imagePath,
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}