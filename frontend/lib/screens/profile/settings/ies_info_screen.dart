import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:url_launcher/url_launcher.dart';

class IesInfoScreen extends StatelessWidget {
  const IesInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
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
                        child: Text(context.tr('iesinfo.title'), style: theme.textTheme.titleLarge),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      children: [
                        RvSurfaceCard(
                          gradient: isDark
                              ? AppColors.darkHeroGradient
                              : const LinearGradient(
                            colors: [Color(0xFFFFFFFF), Color(0xFFF0F4FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/logo_luis_vives.png',
                                width: 82,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.tr('iesinfo.header.name'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              RvBadge(
                                label: context.tr('iesinfo.badge.label'),
                                icon: Icons.emoji_events_rounded,
                                color: const Color(0xFFD4A017),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                context.tr('iesinfo.address'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodySmall?.color,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),

                              const Divider(height: 1),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  _SocialImageButton(
                                    imagePath: 'assets/icons/youtube_icon.png',
                                    url: 'https://www.youtube.com/channel/UCj7gHk5ClkuXJnzwnE1IJiQ',
                                  ),
                                  SizedBox(width: 24),
                                  _SocialImageButton(
                                    imagePath: 'assets/icons/x_icon.png',
                                    url: 'https://twitter.com/ies_luisvives',
                                  ),
                                  SizedBox(width: 24),
                                  _SocialImageButton(
                                    imagePath: 'assets/icons/linkedin_icon.png',
                                    url: 'https://www.linkedin.com/company/ies-luis-vives/',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Contact info
                        Container(
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(AppRadii.m),
                            boxShadow: AppShadows.soft(context),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.m),
                            child: Column(
                              children: [
                                _ContactTile(
                                  icon: Icons.badge_rounded,
                                  label: context.tr('iesinfo.contact.code.label'),
                                  value: context.tr('iesinfo.contact.code.value'),
                                  color: AppColors.primaryBlue,
                                ),
                                _divider(context),
                                _ContactTile(
                                  icon: Icons.phone_rounded,
                                  label: context.tr('iesinfo.contact.phone.label'),
                                  value: context.tr('iesinfo.contact.phone.value'),
                                  color: AppColors.success,
                                  onTap: () => launchUrl(Uri.parse('tel:916807712')),
                                ),
                                _divider(context),
                                _ContactTile(
                                  icon: Icons.email_rounded,
                                  label: context.tr('iesinfo.contact.email.label'),
                                  value: context.tr('iesinfo.contact.email.value'),
                                  color: AppColors.accentPurple,
                                  onTap: () => launchUrl(Uri.parse('mailto:secretaria@iesluisvives.org')),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            context.tr('iesinfo.families.title'),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: isWeb ? 2 : 1,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 16,
                              childAspectRatio: isWeb ? 3.5 : 4.5,
                              children: [
                                _FamilyCard(
                                  icon: Icons.computer_rounded,
                                  title: context.tr('family.informatics.title'),
                                  color: AppColors.primaryBlue,
                                ),
                                _FamilyCard(
                                  icon: Icons.business_center_rounded,
                                  title: context.tr('family.management.title'),
                                  color: AppColors.accentPurple,
                                ),
                                _FamilyCard(
                                  icon: Icons.precision_manufacturing_rounded,
                                  title: context.tr('family.mechanical.title'),
                                  color: const Color(0xFF8B7355),
                                ),
                                _FamilyCard(
                                  icon: Icons.smart_toy_rounded,
                                  title: context.tr('family.mecatronics.title'),
                                  color: const Color(0xFF607D8B),
                                ),
                                _FamilyCard(
                                  icon: Icons.spa_rounded,
                                  title: context.tr('family.personalImage.title'),
                                  color: const Color(0xFFE91E63),
                                ),
                                _FamilyCard(
                                  icon: Icons.fitness_center_rounded,
                                  title: context.tr('family.physical.title'),
                                  color: AppColors.success,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                      ],
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

  Widget _divider(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 56,
      color: Theme.of(context).dividerColor,
    );
  }
}

// Widget para las imágenes sociales con enlace
class _SocialImageButton extends StatelessWidget {
  final String imagePath;
  final String url;

  const _SocialImageButton({required this.imagePath, required this.url});

  Future<void> _launchUrl() async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _launchUrl,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Image.asset(
            imagePath,
            width: 32, // Un poco más grande para esta pantalla
            height: 32,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.open_in_new_rounded, size: 16, color: Theme.of(context).dividerColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _FamilyCard({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadii.m),
        boxShadow: AppShadows.soft(context),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
