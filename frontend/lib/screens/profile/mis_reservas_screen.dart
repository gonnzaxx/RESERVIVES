import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/screens/bookings/widgets/my_bookings_tab.dart';
import 'package:reservives/widgets/design_system.dart';

class MisReservasScreen extends ConsumerWidget {
  const MisReservasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isWeb = AppConstants.isWideScreen(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
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
                              context.tr('mis.reservas.eyebrow').toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w700,
                                color: theme.hintColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('mis.reservas.title'),
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
                const Expanded(child: ReservasTab()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
