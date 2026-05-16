import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/screens/bookings/widgets/spaces_tab.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/constants.dart';

class SpacesScreen extends ConsumerWidget {
  const SpacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = AppConstants.isWideScreen(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, isWeb ? 24 : 8),
                  child: RvPageHeader(
                    eyebrow: context.tr('spaces.eyebrow'),
                    title: context.tr('spaces.title'),
                  ),
                ),
                const Expanded(child: InstalacionesTab()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
