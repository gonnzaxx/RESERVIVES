import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('about.title'),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, isWeb ? 16 : 4, 20, 40),
                    children: [
                      RvSurfaceCard(
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/logo_luis_vives.png',
                              width: 72,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'RESERVIVES',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.tr('about.versionLabel'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('about.description'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Divider(height: 1),
                            ),

                            Text(
                              context.tr('about.developers.title').toUpperCase(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Lista vertical de desarrolladores para mejor UX en móvil
                            _LinkedInButton(
                              name: context.tr('about.developers.dev1'),
                              url: 'https://www.linkedin.com/in/gonzalo-santiago-ariza/',
                            ),
                            const SizedBox(height: 8),
                            _LinkedInButton(
                              name: context.tr('about.developers.dev2'),
                              url: 'https://www.linkedin.com/in/jorge-sepulveda-martin/',
                            ),
                            const SizedBox(height: 8),
                            _LinkedInButton(
                              name: context.tr('about.developers.dev3'),
                              url: 'https://www.linkedin.com/in/alvaro-lorenzo301/',
                            ),

                            const SizedBox(height: 28),

                            _InfoSection(
                              title: context.tr('about.tfg.label'),
                              content: context.tr('about.tfg.description'),
                              icon: Icons.auto_stories_outlined,
                            ),

                            const SizedBox(height: 16),

                            _InfoSection(
                              title: context.tr('about.thanks.title'),
                              content: context.tr('about.thanks.description'),
                              icon: Icons.favorite_border_rounded,
                              iconColor: Colors.redAccent,
                            ),

                            const SizedBox(height: 16),

                            _InfoSection(
                              title: context.tr('about.legacy.title'),
                              content: context.tr('about.legacy.description'),
                              icon: Icons.history_edu_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _AboutItem(
                        icon: Icons.privacy_tip_rounded,
                        title: context.tr('about.privacy.title'),
                        subtitle: context.tr('about.privacy.subtitle'),
                        color: AppColors.primaryBlue,
                        onTap: () => _showPolicy(
                          context,
                          context.tr('about.privacy.title'),
                          context.tr('about.privacy.body'),
                          isWeb,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AboutItem(
                        icon: Icons.description_rounded,
                        title: context.tr('about.terms.title'),
                        subtitle: context.tr('about.terms.subtitle'),
                        color: AppColors.accentPurple,
                        onTap: () => _showPolicy(
                          context,
                          context.tr('about.terms.title'),
                          context.tr('about.terms.body'),
                          isWeb,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AboutItem(
                        icon: Icons.code_rounded,
                        title: context.tr('about.licenses.title'),
                        subtitle: context.tr('about.licenses.subtitle'),
                        color: AppColors.success,
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'RESERVIVES',
                          applicationVersion: '1.0.0',
                          applicationLegalese: context.tr('about.legalese'),
                        ),
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

  void _showPolicy(BuildContext context, String title, String body, bool isWeb) {
    if (isWeb) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const Divider(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
                    ),
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
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
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
}

class _LinkedInButton extends StatelessWidget {
  final String name;
  final String url;

  const _LinkedInButton({required this.name, required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(url)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Image.asset('assets/icons/linkedin_icon.png', width: 20, height: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color? iconColor;

  const _InfoSection({
    required this.title,
    required this.content,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor ?? theme.colorScheme.primary.withValues(alpha: 0.6)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AboutItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadii.m),
        boxShadow: AppShadows.soft(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.m),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).dividerColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}