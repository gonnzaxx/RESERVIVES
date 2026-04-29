import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/navigation_provider.dart';
import 'package:reservives/screens/bookings/widgets/spaces_tab.dart';
import 'package:reservives/screens/bookings/widgets/my_bookings_tab.dart';
import 'package:reservives/screens/bookings/widgets/services_tab.dart';
import 'package:reservives/widgets/design_system.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(servicesTabIndexProvider);
    _controller = TabController(length: 3, vsync: this, initialIndex: initialIndex);
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
            constraints: const BoxConstraints(maxWidth: 1100),
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
                    children: const [
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: isDark
            ? Colors.white.withValues(alpha: 0.6)
            : Colors.black.withValues(alpha: 0.6),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: [
          Tab(text: context.tr('services.tabs.spaces')),
          Tab(text: context.tr('services.tabs.services')),
          Tab(text: context.tr('services.tabs.bookings')),
        ],
      ),
    );
  }
}