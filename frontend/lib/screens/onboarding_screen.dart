import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/i10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  bool _isLastPage = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    context.goNamed('login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ).animate(onPlay: (c) => c.repeat()).rotate(duration: 20.seconds),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
              ),
            ).animate(onPlay: (c) => c.repeat()).moveY(
                begin: 0, end: 30, duration: 3.seconds, curve: Curves.easeInOut
            ).then().moveY(begin: 30, end: 0, duration: 3.seconds, curve: Curves.easeInOut),
          ),

          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      context.tr('onboarding.skip'),
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _isLastPage = index == 3;
                      });
                    },
                    children: [
                      _buildPage(
                        context,
                        title: context.tr('onboarding.slide1.title'),
                        subtitle: context.tr('onboarding.slide1.subtitle'),
                        icon: Icons.calendar_month_rounded,
                      ),
                      _buildPage(
                        context,
                        title: context.tr('onboarding.slide2.title'),
                        subtitle: context.tr('onboarding.slide2.subtitle'),
                        icon: Icons.build_circle_rounded,
                      ),
                      _buildPage(
                        context,
                        title: context.tr('onboarding.slide3.title'),
                        subtitle: context.tr('onboarding.slide3.subtitle'),
                        icon: Icons.restaurant_menu_rounded,
                      ),
                      _buildPage(
                        context,
                        title: context.tr('onboarding.slide4.title'),
                        subtitle: context.tr('onboarding.slide4.subtitle'),
                        icon: Icons.notifications_active_rounded,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: 4,
                        effect: ExpandingDotsEffect(
                          activeDotColor: theme.colorScheme.primary,
                          dotColor: isDark ? Colors.white24 : Colors.black12,
                          dotHeight: 8,
                          dotWidth: 8,
                          spacing: 8,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isLastPage
                            ? SizedBox(
                          key: const ValueKey('start_btn'),
                          width: 140,
                          child: RvPrimaryButton(
                            label: context.tr('onboarding.start'),
                            onTap: _finishOnboarding,
                            icon: Icons.check_circle_outline,
                          ),
                        )
                            : Container(
                          key: const ValueKey('next_btn'),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOutCubic,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, {required String title, required String subtitle, required IconData icon}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    blurRadius: 40,
                    spreadRadius: 10,
                  )
                ]
            ),
            child: Icon(
              icon,
              size: 100,
              color: theme.colorScheme.primary,
            ),
          ).animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 60),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 20),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}
