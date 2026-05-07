import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/providers/auth_provider.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      if (!mounted) return;

      final error = ref.read(authProvider).error;
      if (error == null) {
        if (hasSeenOnboarding) {
          context.goNamed('login');
        } else {
          context.goNamed('onboarding');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'ies-logo-hero',
              child: Image.asset(
                AppAssets.logoPathForTheme(Theme.of(context).brightness),
                width: 180,
                fit: BoxFit.contain,
              ),
            ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
            const SizedBox(height: 40),

            Consumer(
              builder: (context, ref, child) {
                final error = ref.watch(authProvider).error;
                if (error != null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Error: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return const CupertinoActivityIndicator(radius: 14);
              },
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }
}
