import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/navigation_provider.dart';
import 'package:reservives/screens/bookings/widgets/spaces_tab.dart';
import 'package:reservives/screens/bookings/widgets/my_bookings_tab.dart';
import 'package:reservives/screens/bookings/widgets/services_tab.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _controller;
  bool _guestMode = false;

  @override
  void initState() {
    super.initState();
    _guestMode = ref.read(authProvider).isGuest;
    final initialIndex = ref.read(servicesTabIndexProvider);
    final tabLength = _guestMode ? 2 : 3;
    final safeIndex = initialIndex >= tabLength ? 0 : initialIndex;
    _controller = TabController(length: tabLength, vsync: this, initialIndex: safeIndex);
    _controller.addListener(() {
      if (!_controller.indexIsChanging) {
        ref.read(servicesTabIndexProvider.notifier).setIndex(_controller.index);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;

    ref.listen(servicesTabIndexProvider, (previous, next) {
      if (_controller.index != next) {
        _controller.animateTo(next);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, isWeb ? 24 : 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RvPageHeader(
                        eyebrow: context.tr('services.eyebrow'),
                        title: context.tr('services.title'),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isWeb ? 600 : double.infinity),
                          child: _PillsTabBar(controller: _controller),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _controller,
                    children: _guestMode
                        ? const [
                            InstalacionesTab(),
                            ServiciosTab(),
                          ]
                        : const [
                            InstalacionesTab(),
                            ServiciosTab(),
                            ReservasTab(),
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

class _PillsTabBar extends StatelessWidget {
  final TabController controller;

  const _PillsTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 54,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: TabBar(
            controller: controller,
            indicator: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.5),
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            tabs: [
              Tab(text: context.tr('services.tabs.spaces')),
              Tab(text: context.tr('services.tabs.services')),
              if (controller.length == 3)
                Tab(text: context.tr('services.tabs.bookings')),
            ],
          ),
        ),
      ),
    );
  }
}


