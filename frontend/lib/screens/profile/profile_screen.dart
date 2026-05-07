import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/core/utils/role_access.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/theme_provider.dart';
import 'package:reservives/services/auth_service.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

import '../../widgets/rv_image.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 850;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            isWeb ? 48 : 20,
            24,
            isWeb ? 80 : 40,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
              child: _buildBody(context, ref, auth, isWeb),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      WidgetRef ref,
      AuthState auth,
      bool isWeb,
      ) {
    if (auth.isLoading) return _ProfileSkeleton(isWeb: isWeb);
    if (auth.isGuest) return _GuestView(ref: ref, isWeb: isWeb);
    if (auth.user == null) return _UserNullView(isWeb: isWeb);
    return _AuthenticatedView(ref: ref, user: auth.user!, isWeb: isWeb);
  }
}

class _GuestView extends ConsumerWidget {
  final WidgetRef ref;
  final bool isWeb;

  const _GuestView({required this.ref, required this.isWeb});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final userCard = _GuestCard(ref: ref)
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);

    final options = _OptionsList(
      ref: ref,
      items: _guestOptions(context, ref, theme),
    ).animate().fadeIn(delay: 120.ms, duration: 350.ms);

    return Column(
      crossAxisAlignment:
      isWeb ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        _ProfileHeader(isWeb: isWeb),
        const SizedBox(height: 32),
        if (isWeb)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: userCard),
              const SizedBox(width: 28),
              Expanded(flex: 3, child: options),
            ],
          )
        else ...[
          userCard,
          const SizedBox(height: 20),
          options,
        ],
      ],
    );
  }

  List<_OptionsItem> _guestOptions(
      BuildContext context,
      WidgetRef ref,
      ThemeData theme,
      ) {
    final isDark = theme.brightness == Brightness.dark;
    return [
      _OptionsItem.nav(
        icon: Icons.school_rounded,
        color: const Color(0xFFD4A017),
        title: context.tr('settings.ies.title'),
        subtitle: context.tr('settings.ies.subtitle'),
        onTap: () => context.pushNamed('ies_info'),
      ),
      _OptionsItem.nav(
        icon: Icons.settings_rounded,
        color: const Color(0xFF636366),
        title: context.tr('profile.settingsTitle'),
        subtitle: context.tr('profile.settingsSubtitle'),
        onTap: () => context.pushNamed('ajustes'),
      ),
      _OptionsItem.toggle(
        icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: isDark ? AppColors.accentPurple : AppColors.primaryBlue,
        title: context.tr('profile.theme.title'),
        subtitle: isDark
            ? context.tr('profile.theme.subtitleDark')
            : context.tr('profile.theme.subtitleLight'),
        value: isDark,
        onToggle: () => ref.read(themeProvider.notifier).toggleTheme(),
      ),
    ];
  }
}

class _AuthenticatedView extends ConsumerWidget {
  final WidgetRef ref;
  final dynamic user;
  final bool isWeb;

  const _AuthenticatedView({
    required this.ref,
    required this.user,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final userCard = _UserCard(user: user)
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);

    final options = _OptionsList(
      ref: ref,
      items: _authOptions(context, ref, theme, isDark),
    ).animate().fadeIn(delay: 120.ms, duration: 350.ms);

    final logout = _LogoutButton(
      isWeb: isWeb,
      onTap: () => _showLogoutDialog(context, ref),
    ).animate().fadeIn(delay: 200.ms, duration: 350.ms);

    return Column(
      crossAxisAlignment:
      isWeb ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        _ProfileHeader(isWeb: isWeb),
        const SizedBox(height: 32),
        if (isWeb)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: userCard),
              const SizedBox(width: 28),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    options,
                    const SizedBox(height: 20),
                    logout,
                  ],
                ),
              ),
            ],
          )
        else ...[
          userCard,
          const SizedBox(height: 20),
          options,
          const SizedBox(height: 28),
          logout,
        ],
      ],
    );
  }

  List<_OptionsItem> _authOptions(
      BuildContext context,
      WidgetRef ref,
      ThemeData theme,
      bool isDark,
      ) {
    return [
      _OptionsItem.nav(
        icon: Icons.favorite_rounded,
        color: AppColors.error,
        title: context.tr('profile.favoritesTitle'),
        subtitle: context.tr('profile.favoritesSubtitle'),
        onTap: () => context.pushNamed('favoritos'),
      ),
      _OptionsItem.nav(
        icon: Icons.school_rounded,
        color: const Color(0xFFD4A017),
        title: context.tr('settings.ies.title'),
        subtitle: context.tr('settings.ies.subtitle'),
        onTap: () => context.pushNamed('ies_info'),
      ),
      _OptionsItem.nav(
        icon: Icons.how_to_vote_rounded,
        color: Colors.orange.shade600,
        title: context.tr('home.quick.vote.title'),
        subtitle: context.tr('home.quick.vote.subtitle'),
        onTap: () => context.pushNamed('votaciones'),
      ),
      _OptionsItem.nav(
        icon: Icons.settings_rounded,
        color: const Color(0xFF636366),
        title: context.tr('profile.settingsTitle'),
        subtitle: context.tr('profile.settingsSubtitle'),
        onTap: () => context.pushNamed('ajustes'),
      ),
      _OptionsItem.toggle(
        icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: isDark ? AppColors.accentPurple : AppColors.primaryBlue,
        title: context.tr('profile.theme.title'),
        subtitle: isDark
            ? context.tr('profile.theme.subtitleDark')
            : context.tr('profile.theme.subtitleLight'),
        value: isDark,
        onToggle: () => ref.read(themeProvider.notifier).toggleTheme(),
      ),
      if (hasAnyBackofficeAccess(user.rol))
        _OptionsItem.nav(
          icon: Icons.admin_panel_settings_rounded,
          color: AppColors.success,
          title: context.tr('profile.backofficeTitle'),
          subtitle: context.tr('profile.backofficeSubtitle'),
          onTap: () => context.pushNamed('admin'),
        ),
    ];
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: RvSurfaceCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.tr('profile.logout.confirm.title'),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('profile.logout.confirm.msg'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop('cancel'),
                        child: Text(context.tr('generic.cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop('logout'),
                        child: Text(context.tr('profile.logout')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == 'logout') {
      await ref.read(authServiceProvider).logoutMicrosoft();
      if (context.mounted) context.go('/login');
    }
  }
}

class _UserNullView extends StatelessWidget {
  final bool isWeb;
  const _UserNullView({required this.isWeb});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: isWeb ? 60 : 30),
        const RvLogoLoader(),
        const SizedBox(height: 24),
        Text(
          context.tr('profile.error.title'),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(context.tr('profile.error.msg'), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        SizedBox(
          width: isWeb ? 250 : double.infinity,
          child: OutlinedButton(
            onPressed: () => context.goNamed('home'),
            child: Text(context.tr('profile.error.back')),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final bool isWeb;
  const _ProfileHeader({required this.isWeb});

  @override
  Widget build(BuildContext context) {
    return RvPageHeader(
      eyebrow: context.tr('profile.accountEyebrow'),
      title: context.tr('profile.title'),
      textAlign: isWeb ? TextAlign.left : TextAlign.left,
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _GuestCard extends ConsumerWidget {
  final WidgetRef ref;
  const _GuestCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkHeroGradient : AppColors.lightHeroGradient,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          // Avatar con gradiente
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 38,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            context.tr('profile.guestTitle'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            context.tr('profile.subtitle.text'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          RvPrimaryButton(
            label: context.tr('profile.login.text'),
            icon: Icons.login_rounded,
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.goNamed('login');
            },
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final dynamic user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkHeroGradient : AppColors.lightHeroGradient,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          // Avatar
          RvAvatar(
            imageUrl: user.fullAvatarUrl,
            fallbackText: user.nombre,
            radius: 44,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),

          const SizedBox(height: 16),

          // Nombre
          Text(
            user.nombreCompleto,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 4),

          // Email
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.email,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Rol + tokens
          _RoleBadges(user: user, theme: theme),
        ],
      ),
    );
  }
}

class _RoleBadges extends StatelessWidget {
  final dynamic user;
  final ThemeData theme;
  const _RoleBadges({required this.user, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Text(
            user.rol.value,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (user.usesTokens)
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.stars_rounded,
                  size: 14,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 5),
                Text(
                  '${user.tokens} tokens',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Modelo de ítem para la lista de opciones. Soporta navegación y toggle.
class _OptionsItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isToggle;
  final bool toggleValue;
  final VoidCallback? onToggle;

  const _OptionsItem._({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isToggle = false,
    this.toggleValue = false,
    this.onToggle,
  });

  factory _OptionsItem.nav({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      _OptionsItem._(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      );

  factory _OptionsItem.toggle({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required VoidCallback onToggle,
  }) =>
      _OptionsItem._(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
        isToggle: true,
        toggleValue: value,
        onToggle: onToggle,
      );
}

class _OptionsList extends StatelessWidget {
  final WidgetRef ref;
  final List<_OptionsItem> items;

  const _OptionsList({required this.ref, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              _OptionsItemTile(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionsItemTile extends StatefulWidget {
  final _OptionsItem item;
  const _OptionsItemTile({required this.item});

  @override
  State<_OptionsItemTile> createState() => _OptionsItemTileState();
}

class _OptionsItemTileState extends State<_OptionsItemTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = widget.item;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovered
            ? (isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02))
            : Colors.transparent,
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          title: Text(
            item.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            item.subtitle,
            style: theme.textTheme.bodySmall,
          ),
          trailing: item.isToggle
              ? Switch.adaptive(
            value: item.toggleValue,
            onChanged: (_) {
              HapticFeedback.selectionClick();
              item.onToggle?.call();
            },
            activeTrackColor: AppColors.accentPurple,
          )
              : Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: theme.hintColor,
          ),
          onTap: item.isToggle
              ? () {
            HapticFeedback.selectionClick();
            item.onToggle?.call();
          }
              : item.onTap,
        ),
      ),
    );
  }
}

class _LogoutButton extends StatefulWidget {
  final bool isWeb;
  final VoidCallback onTap;

  const _LogoutButton({required this.isWeb, required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
      widget.isWeb ? Alignment.centerRight : Alignment.center,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.isWeb ? 220 : double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.error.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.error.withValues(
                    alpha: _hovered ? 0.8 : 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('profile.logout'),
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

class _ProfileSkeleton extends StatelessWidget {
  final bool isWeb;
  const _ProfileSkeleton({required this.isWeb});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RvSkeleton(width: 90, height: 12, borderRadius: 6),
        const SizedBox(height: 10),
        const RvSkeleton(width: 180, height: 32, borderRadius: 8),
        const SizedBox(height: 32),
        if (isWeb)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(flex: 2, child: _UserCardSkeleton()),
              SizedBox(width: 28),
              Expanded(flex: 3, child: _OptionsListSkeleton()),
            ],
          )
        else
          const Column(
            children: [
              _UserCardSkeleton(),
              SizedBox(height: 20),
              _OptionsListSkeleton(),
            ],
          ),
      ],
    );
  }
}

class _UserCardSkeleton extends StatelessWidget {
  const _UserCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadii.l),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: const Column(
        children: [
          RvSkeleton(width: 88, height: 88, borderRadius: 100),
          SizedBox(height: 16),
          RvSkeleton(width: 180, height: 22, borderRadius: 6),
          SizedBox(height: 8),
          RvSkeleton(width: 140, height: 14, borderRadius: 6),
          SizedBox(height: 18),
          RvSkeleton(width: 100, height: 28, borderRadius: 100),
        ],
      ),
    );
  }
}

class _OptionsListSkeleton extends StatelessWidget {
  const _OptionsListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
            (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RvSkeleton(
            width: double.infinity,
            height: 64,
            borderRadius: AppRadii.m,
          ),
        ),
      ),
    );
  }
}