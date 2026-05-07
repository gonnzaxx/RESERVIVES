import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Devuelve la ruta del asset legal según tipo e idioma.
  String _legalAssetPath(String type, String langCode) {
    final lang = ['es', 'en', 'fr'].contains(langCode) ? langCode : 'es';
    return 'assets/legal/${type}_$lang.md';
  }

  Future<void> _showPolicy(
    BuildContext context,
    String title,
    String assetPath,
    bool isDark,
    bool isWeb,
  ) async {
    String body;
    try {
      body = await rootBundle.loadString(assetPath);
    } catch (_) {
      // Fallback al español si el idioma no tiene traducción
      final fallback = assetPath.replaceAll(RegExp(r'_(en|fr)\.md$'), '_es.md');
      body = await rootBundle.loadString(fallback);
    }

    if (!context.mounted) return;

    if (isWeb) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 640, maxHeight: 820),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                        ),
                      ),
                      RvGhostIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: Theme.of(context)
                        .dividerColor
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _MarkdownContent(body: body, isDark: isDark),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          expand: false,
          builder: (ctx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: Theme.of(ctx)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    color: Theme.of(ctx)
                        .dividerColor
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: _MarkdownContent(
                      body: body,
                      isDark: isDark,
                      scrollController: scrollController,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = MediaQuery.of(context).size.width > 750;
    final langCode = AppLocalizations.of(context).locale.languageCode;

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
                  padding: EdgeInsets.fromLTRB(8, 12, 20, isWeb ? 20 : 8),
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
                              context
                                  .tr('profile.accountEyebrow')
                                  .toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w700,
                                color: theme.hintColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('about.title'),
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
                  child: ListView(
                    padding:
                        EdgeInsets.fromLTRB(20, isWeb ? 8 : 4, 20, 48),
                    children: [
                      _AppCard(isDark: isDark, theme: theme, isWeb: isWeb)
                          .animate()
                          .fadeIn(delay: 80.ms, duration: 350.ms)
                          .slideY(
                            begin: 0.04,
                            delay: 80.ms,
                            duration: 350.ms,
                            curve: Curves.easeOutCubic,
                          ),

                      const SizedBox(height: 20),

                      _DevelopersCard(
                              isDark: isDark, theme: theme, isWeb: isWeb)
                          .animate()
                          .fadeIn(delay: 140.ms, duration: 350.ms)
                          .slideY(
                            begin: 0.04,
                            delay: 140.ms,
                            duration: 350.ms,
                            curve: Curves.easeOutCubic,
                          ),

                      const SizedBox(height: 20),

                      _FooterSection(
                        isDark: isDark,
                        theme: theme,
                        isWeb: isWeb,
                        onShowPolicy: (title, assetPath) => _showPolicy(
                          context,
                          title,
                          assetPath,
                          isDark,
                          isWeb,
                        ),
                        privacyAsset:
                            _legalAssetPath('privacy_policy', langCode),
                        termsAsset: _legalAssetPath('terms', langCode),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 350.ms)
                          .slideY(
                            begin: 0.04,
                            delay: 200.ms,
                            duration: 350.ms,
                            curve: Curves.easeOutCubic,
                          ),
                    ],
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

// Widget que renderiza el contenido markdown con estilos coherentes al tema.
class _MarkdownContent extends StatelessWidget {
  final String body;
  final bool isDark;
  final ScrollController? scrollController;

  const _MarkdownContent({
    required this.body,
    required this.isDark,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor =
        isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final dividerColor = theme.dividerColor.withValues(alpha: 0.4);

    return Markdown(
      controller: scrollController,
      data: body,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        h1: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: baseColor,
          letterSpacing: -0.4,
          height: 1.3,
        ),
        h2: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: baseColor,
          letterSpacing: -0.2,
          height: 1.3,
        ),
        h3: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: baseColor,
        ),
        p: theme.textTheme.bodyMedium?.copyWith(
          color: secondaryColor,
          height: 1.7,
        ),
        strong: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: baseColor,
        ),
        tableHead: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: baseColor,
        ),
        tableBody: theme.textTheme.bodySmall?.copyWith(
          color: secondaryColor,
          height: 1.5,
        ),
        tableBorder: TableBorder.all(color: dividerColor, width: 1),
        tableColumnWidth: const FlexColumnWidth(),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: dividerColor, width: 1),
          ),
        ),
        listBullet: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
        a: TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
        h1Padding: const EdgeInsets.only(top: 20, bottom: 6),
        h2Padding: const EdgeInsets.only(top: 16, bottom: 4),
        h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
        pPadding: const EdgeInsets.only(bottom: 4),
        blockSpacing: 10,
      ),
      onTapLink: (text, href, title) {
        if (href != null) launchUrl(Uri.parse(href));
      },
      padding: const EdgeInsets.only(bottom: 16),
    );
  }
}

class _AppCard extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final bool isWeb;

  const _AppCard({
    required this.isDark,
    required this.theme,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                AppAssets.logoPathForTheme(theme.brightness),
                width: 80,
                fit: BoxFit.contain,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'RESERVIVES',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),

          const SizedBox(height: 6),

          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              context.tr('about.versionLabel'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),

          const SizedBox(height: 18),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              context.tr('about.description'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevelopersCard extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final bool isWeb;

  const _DevelopersCard({
    required this.isDark,
    required this.theme,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    final devs = [
      (
        name: context.tr('about.developers.dev1'),
        url: 'https://www.linkedin.com/in/gonzalo-santiago-ariza/',
      ),
      (
        name: context.tr('about.developers.dev2'),
        url: 'https://www.linkedin.com/in/jorge-sepulveda-martin/',
      ),
      (
        name: context.tr('about.developers.dev3'),
        url: 'https://www.linkedin.com/in/alvaro-lorenzo301/',
      ),
    ];

    final infos = [
      _InfoData(
        icon: Icons.auto_stories_outlined,
        color: AppColors.accentPurple,
        title: context.tr('about.tfg.label'),
        content: context.tr('about.tfg.description'),
      ),
      _InfoData(
        icon: Icons.favorite_border_rounded,
        color: AppColors.error,
        title: context.tr('about.thanks.title'),
        content: context.tr('about.thanks.description'),
      ),
      _InfoData(
        icon: Icons.history_edu_rounded,
        color: AppColors.warning,
        title: context.tr('about.legacy.title'),
        content: context.tr('about.legacy.description'),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('about.developers.title').toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 0.9,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (isWeb)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DevList(
                        devs: devs, isDark: isDark, theme: theme),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: _InfoList(
                        infos: infos, isDark: isDark, theme: theme),
                  ),
                ],
              )
            else ...[
              _DevList(devs: devs, isDark: isDark, theme: theme),
              const SizedBox(height: 24),
              Divider(
                color: theme.dividerColor.withValues(alpha: 0.4),
                height: 1,
              ),
              const SizedBox(height: 24),
              _InfoList(infos: infos, isDark: isDark, theme: theme),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoData {
  final IconData icon;
  final Color color;
  final String title;
  final String content;
  const _InfoData({
    required this.icon,
    required this.color,
    required this.title,
    required this.content,
  });
}

class _DevList extends StatelessWidget {
  final List<({String name, String url})> devs;
  final bool isDark;
  final ThemeData theme;

  const _DevList({
    required this.devs,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: devs
          .map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LinkedInButton(
                    name: d.name,
                    url: d.url,
                    isDark: isDark,
                    theme: theme),
              ))
          .toList(),
    );
  }
}

class _InfoList extends StatelessWidget {
  final List<_InfoData> infos;
  final bool isDark;
  final ThemeData theme;

  const _InfoList({
    required this.infos,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: infos
          .map((info) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _InfoSection(
                    info: info, isDark: isDark, theme: theme),
              ))
          .toList(),
    );
  }
}

class _FooterSection extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final bool isWeb;
  final void Function(String title, String assetPath) onShowPolicy;
  final String privacyAsset;
  final String termsAsset;

  const _FooterSection({
    required this.isDark,
    required this.theme,
    required this.isWeb,
    required this.onShowPolicy,
    required this.privacyAsset,
    required this.termsAsset,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _FooterItem(
        icon: Icons.privacy_tip_rounded,
        color: AppColors.primaryBlue,
        title: context.tr('about.privacy.title'),
        subtitle: context.tr('about.privacy.subtitle'),
        onTap: () => onShowPolicy(
          context.tr('about.privacy.title'),
          privacyAsset,
        ),
      ),
      _FooterItem(
        icon: Icons.description_rounded,
        color: AppColors.accentPurple,
        title: context.tr('about.terms.title'),
        subtitle: context.tr('about.terms.subtitle'),
        onTap: () => onShowPolicy(
          context.tr('about.terms.title'),
          termsAsset,
        ),
      ),
      _FooterItem(
        icon: Icons.code_rounded,
        color: AppColors.success,
        title: context.tr('about.licenses.title'),
        subtitle: context.tr('about.licenses.subtitle'),
        onTap: () => showLicensePage(
          context: context,
          applicationName: 'RESERVIVES',
          applicationVersion: '1.0.0',
          applicationLegalese: context.tr('about.legalese'),
        ),
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
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  indent: 68,
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              _AboutTile(item: items[i], isDark: isDark, theme: theme),
            ],
          ],
        ),
      ),
    );
  }
}

class _FooterItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FooterItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _AboutTile extends StatefulWidget {
  final _FooterItem item;
  final bool isDark;
  final ThemeData theme;

  const _AboutTile({
    required this.item,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_AboutTile> createState() => _AboutTileState();
}

class _AboutTileState extends State<_AboutTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.item.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: _hovered
              ? (widget.isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02))
              : Colors.transparent,
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.item.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.item.icon,
                  color: widget.item.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: widget.theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.subtitle,
                      style: widget.theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: widget.theme.hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedInButton extends StatefulWidget {
  final String name;
  final String url;
  final bool isDark;
  final ThemeData theme;

  const _LinkedInButton({
    required this.name,
    required this.url,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_LinkedInButton> createState() => _LinkedInButtonState();
}

class _LinkedInButtonState extends State<_LinkedInButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(widget.url)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? primary.withValues(alpha: 0.08)
                : primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? primary.withValues(alpha: 0.25)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/icons/linkedin_icon.png',
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.name,
                  style: widget.theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color:
                    primary.withValues(alpha: _hovered ? 0.8 : 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final _InfoData info;
  final bool isDark;
  final ThemeData theme;

  const _InfoSection({
    required this.info,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: info.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(info.icon, size: 17, color: info.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                info.content,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.5,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
