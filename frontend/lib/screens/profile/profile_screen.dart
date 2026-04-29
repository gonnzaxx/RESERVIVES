import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/utils/role_access.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/theme_provider.dart';
import 'package:reservives/services/auth_service.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/widgets/rv_image.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;

    if (auth.isLoading) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _buildSkeleton(context, isWeb),
            ),
          ),
        ),
      );
    }

    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, isWeb ? 32 : 12, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  RvPageHeader(
                    eyebrow: context.tr('profile.accountEyebrow'),
                    title: context.tr('profile.title'),
                  ),
                  const SizedBox(height: 24),

                  // Tarjeta de información de usuario
                  RvSurfaceCard(
                    gradient: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkHeroGradient
                        : const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFF2F4FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildAvatar(context, ref, user),
                        const SizedBox(height: 16),
                        Text(
                          user.nombreCompleto,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRoleBadge(context, user),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(AppRadii.m),
                      boxShadow: AppShadows.soft(context),
                      border: isWeb ? Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)) : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.m),
                      child: Column(
                        children: [
                          _divider(context),
                          _ProfileItem(
                            icon: Icons.favorite_rounded,
                            title: context.tr('profile.favoritesTitle'),
                            subtitle: context.tr('profile.favoritesSubtitle'),
                            color: AppColors.error,
                            onTap: () => context.pushNamed('favoritos'),
                          ),
                          _divider(context),
                          _ProfileItem(
                            icon: Icons.history_rounded,
                            title: context.tr('profile.activityTitle'),
                            subtitle: context.tr('profile.activitySubtitle'),
                            color: AppColors.primaryBlue,
                            onTap: () => context.pushNamed('actividad'),
                          ),
                          _divider(context),
                          _ProfileItem(
                            icon: Icons.how_to_vote_rounded,
                            title: context.tr('home.quick.vote.title'),
                            subtitle: context.tr('home.quick.vote.subtitle'),
                            color: Colors.orange.shade600,
                            onTap: () => context.pushNamed('votaciones'),
                          ),
                          _divider(context),
                          _ProfileItem(
                            icon: Icons.settings_rounded,
                            title: context.tr('profile.settingsTitle'),
                            subtitle: context.tr('profile.settingsSubtitle'),
                            color: const Color(0xFF636366),
                            onTap: () => context.pushNamed('ajustes'),
                          ),
                          _divider(context),
                          _ProfileDarkModeItem(
                            isDark: Theme.of(context).brightness == Brightness.dark,
                            onToggle: () => ref.read(themeProvider.notifier).toggleTheme(),
                            title: context.tr('profile.theme.title'),
                            subtitle: Theme.of(context).brightness == Brightness.dark
                                ? context.tr('profile.theme.subtitleDark')
                                : context.tr('profile.theme.subtitleLight'),
                          ),
                          if (hasAnyBackofficeAccess(user.rol)) ...[
                            _divider(context),
                            _ProfileItem(
                              icon: Icons.admin_panel_settings_rounded,
                              title: context.tr('profile.backofficeTitle'),
                              subtitle: context.tr('profile.backofficeSubtitle'),
                              color: AppColors.success,
                              onTap: () => context.pushNamed('admin'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Align(
                    alignment: isWeb ? Alignment.centerRight : Alignment.center,
                    child: SizedBox(
                      width: isWeb ? 250 : double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          await ref.read(authServiceProvider).logoutMicrosoft();
                          if (context.mounted) context.goNamed('login');
                        },
                        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                        label: Text(
                          context.tr('profile.logout'),
                          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, WidgetRef ref, dynamic user) {
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final image = await picker.pickImage(source: ImageSource.gallery);
        if (image == null) return;
        final bytes = await image.readAsBytes();
        final success = await ref.read(authServiceProvider).uploadAvatar(bytes, image.name);
        if (!context.mounted) return;
        if (success) {
          RvAlerts.success(context, context.tr('profile.avatarUpdated'));
        } else {
          RvAlerts.error(context, context.tr('profile.avatarUpdateError'));
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Stack(
          children: [
            RvAvatar(
              imageUrl: user.fullAvatarUrl,
              fallbackText: user.nombre,
              radius: 48,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 16, color: AppColors.accentPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(BuildContext context, dynamic user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            user.rol.value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        if (user.usesTokens) ...[
          const SizedBox(width: 12),
          const Icon(Icons.stars_rounded, size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 4),
          Text(
            '${user.tokens} ${context.tr('profile.tokens')}',
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _divider(BuildContext context) => Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 68,
      color: Theme.of(context).dividerColor.withOpacity(0.5)
  );

  Widget _buildSkeleton(BuildContext context, bool isWeb) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, isWeb ? 32 : 12, 20, 120),
      child: Column(
        children: [
          const RvPageHeader(
            eyebrow: 'CARGANDO...',
            title: 'Perfil',
            subtitle: 'Preparando tu cuenta...',
          ),
          const SizedBox(height: 24),
          RvSurfaceCard(
            child: Column(
              children: [
                const RvSkeleton(width: 96, height: 96, borderRadius: 100),
                const SizedBox(height: 16),
                const RvSkeleton(width: 200, height: 24),
                const SizedBox(height: 8),
                const RvSkeleton(width: 150, height: 16),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(5, (index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: RvSkeleton(width: double.infinity, height: 60, borderRadius: AppRadii.m),
          )),
        ],
      ),
    );
  }
}

class _ProfileDarkModeItem extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;
  final String title;
  final String subtitle;

  const _ProfileDarkModeItem({
    required this.isDark,
    required this.onToggle,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.accentPurple : AppColors.primaryBlue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
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
              Switch.adaptive(
                value: isDark,
                onChanged: (_) => onToggle(),
                activeThumbColor: AppColors.accentPurple,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    );
  }
}
