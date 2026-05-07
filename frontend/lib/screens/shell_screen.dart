import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/notifications_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ShellScreen extends ConsumerStatefulWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!ref.read(authProvider).isGuest) {
        ref.invalidate(unreadNotificationsCountProvider);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!ref.read(authProvider).isGuest) {
        ref.invalidate(unreadNotificationsCountProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (!authState.isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Hero(
            tag: 'ies-logo-hero',
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Image.asset(
                AppAssets.logoPathForTheme(Theme.of(context).brightness),
                width: 140,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final location = GoRouterState.of(context).uri.path;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    int selectedIndex() {
      if (location.startsWith('/home')) return 0;
      if (location.startsWith('/servicios')) return 1;
      if (location.startsWith('/ai-chat')) return 2;
      if (location.startsWith('/cafeteria')) return 3;
      if (location.startsWith('/perfil')) return 4;
      return 0;
    }

    final items = [
      (context.tr('shell.nav.home'), Icons.home, Icons.home_outlined),
      (context.tr('shell.nav.bookings'), Icons.edit_calendar, Icons.calendar_month_outlined),
      ('Vivi', Icons.wechat_outlined, Icons.wechat_outlined),
      (context.tr('shell.nav.cafeteria'), Icons.restaurant_menu, Icons.local_cafe_outlined),
      (context.tr('shell.nav.profile'), Icons.person_rounded, Icons.person_outline_rounded),
    ];

    final activeIndex = selectedIndex();
    final isGuest = authState.isGuest;

    void navigate(int index) {
      HapticFeedback.selectionClick();
      switch (index) {
        case 0: context.goNamed('home'); break;
        case 1: context.goNamed('servicios'); break;
        case 2:
          if (isGuest) {
            context.pushNamed('restricted');
          } else {
            context.goNamed('ai_chat');
          }
          break;
        case 3: context.goNamed('cafeteria'); break;
        case 4: context.goNamed('perfil'); break;
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: isWide
            ? _WebHeader(
          items: items,
          activeIndex: activeIndex,
          onTap: navigate,
          isDarkMode: isDarkMode,
        )
            : null,
        body: isWide
            ? ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(
              height: size.height - 80,
              child: widget.child,
            ),
            if (kIsWeb) const _WebFooter(),
          ],
        )
            : widget.child,
        bottomNavigationBar: isWide
            ? null
            : _MobileBottomNavBar(
          items: items,
          activeIndex: activeIndex,
          isDarkMode: isDarkMode,
          onTap: navigate,
        ),
      ),
    );
  }
}

class _WebHeader extends ConsumerWidget implements PreferredSizeWidget {
  final List<(String, IconData, IconData)> items;
  final int activeIndex;
  final Function(int) onTap;
  final bool isDarkMode;

  const _WebHeader({
    required this.items,
    required this.activeIndex,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final isGuest = ref.watch(authProvider).isGuest;
    final unreadCount = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: (isDarkMode ? AppColors.darkSurface : Colors.white).withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    // Logo con efecto Hover simple
                    _HeaderLogo(onTap: () => context.goNamed('home')),

                    const SizedBox(width: 48),

                    // Items de Navegación con indicador inferior animado
                    Expanded(
                      child: Row(
                        children: List.generate(items.length, (index) {
                          final isSelected = activeIndex == index;
                          return _navItem(context, index, isSelected);
                        }),
                      ),
                    ),

                    // Acciones Derecha
                    _actionButtons(context, unreadCount, isGuest, user),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, bool isSelected) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? items[index].$2 : items[index].$3,
                size: 20,
                color: isSelected ? theme.colorScheme.primary : theme.hintColor,
              ),
              const SizedBox(width: 8),
              Text(
                items[index].$1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButtons(BuildContext context, int unreadCount, bool isGuest, dynamic user) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          icon: Badge(
            isLabelVisible: unreadCount > 0 && !isGuest,
            backgroundColor: theme.colorScheme.error,
            label: Text('$unreadCount', style: const TextStyle(fontSize: 10, color: Colors.white)),
            child: Icon(Icons.notifications_none_rounded, color: theme.hintColor),
          ),
          onPressed: () => context.pushNamed(isGuest ? 'restricted' : 'notificaciones'),
          tooltip: context.tr('notifications.title'),
        ),
        const SizedBox(width: 16),
        if (user != null)
          _ProfileAvatar(
            url: user.fullAvatarUrl,
            initial: user.nombre[0],
            onTap: () => context.pushNamed('perfil'),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}

class _HeaderLogo extends StatelessWidget {
  final VoidCallback onTap;
  const _HeaderLogo({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Hero(
          tag: 'app_logo',
          child: Image.asset(
            AppAssets.logoPathForTheme(Theme.of(context).brightness),
            height: 50,
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? url;
  final String initial;
  final VoidCallback onTap;

  const _ProfileAvatar({this.url, required this.initial, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primary,
          backgroundImage: url != null ? NetworkImage(url!) : null,
          child: url == null
              ? Text(initial.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              : null,
        ),
      ),
    );
  }
}

class _WebFooter extends StatelessWidget {
  const _WebFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              AppAssets.logoPathForTheme(Theme.of(context).brightness),
                              width: 54,
                              height: 54,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'RESERVIVES',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.tr('shell.footer.description'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 80),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('shell.footer.nav.title'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _FooterLink(label: context.tr('shell.footer.nav.home'), onTap: () => context.goNamed('home')),
                        _FooterLink(label: context.tr('shell.footer.nav.services'), onTap: () => context.goNamed('servicios')),
                        _FooterLink(label: context.tr('shell.footer.nav.cafeteria'), onTap: () => context.goNamed('cafeteria')),
                        _FooterLink(label: context.tr('shell.footer.nav.profile'), onTap: () => context.goNamed('perfil')),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('shell.footer.contact.title'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _FooterIconText(
                          icon: Icons.location_on_rounded,
                          text: context.tr('shell.footer.contact.address'),
                        ),
                        const SizedBox(height: 16),
                        const _FooterIconText(
                          icon: Icons.email_rounded,
                          text: 'secretaria@iesluisvives.es',
                        ),
                        const SizedBox(height: 16),
                        const _FooterIconText(
                          icon: Icons.phone_rounded,
                          text: '916 80 77 12',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),
              const Divider(),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('shell.footer.copyright').replaceAll('{year}', DateTime.now().year.toString()),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  Row(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterIconText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FooterIconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialImageButton extends StatelessWidget {
  final String imagePath;
  final String url;

  const _SocialImageButton({
    required this.imagePath,
    required this.url,
  });

  Future<void> _launchUrl() async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _launchUrl,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(4),
        child: Image.asset(
          imagePath,
          width: 28,
          height: 28,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _MobileBottomNavBar extends StatelessWidget {
  final List<(String, IconData, IconData)> items;
  final int activeIndex;
  final bool isDarkMode;
  final Function(int) onTap;

  const _MobileBottomNavBar({
    required this.items,
    required this.activeIndex,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0x661C1C1E) : const Color(0x4DFFFFFF),
            border: Border(
              top: BorderSide(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = activeIndex == index;
              final color = isSelected
                  ? Theme.of(context).colorScheme.primary
                  : isDarkMode
                  ? const Color(0xFF8E8E93)
                  : const Color(0xFF8A8A8E);

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(index),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.0 : 0.92,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: index == 0
                              ? Consumer(
                            builder: (context, ref, _) {
                              final count = ref.watch(unreadNotificationsCountProvider).value ?? 0;
                              if (count <= 0) return Icon(isSelected ? item.$2 : item.$3, size: 28, color: color);
                              return Badge(
                                label: Text(count > 99 ? '99+' : '$count', style: const TextStyle(fontSize: 8)),
                                child: Icon(isSelected ? item.$2 : item.$3, size: 28, color: color),
                              );
                            },
                          )
                              : Icon(
                            isSelected ? item.$2 : item.$3,
                            size: 28,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: color,
                            letterSpacing: -0.1,
                          ),
                          child: Text(item.$1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

