import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/services/api_client.dart';

class BrandingState {
  final String? logoLightUrl;
  final String? logoDarkUrl;
  final String? appName;
  final String? primaryColor;
  final String? themeModeName;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final bool isLoading;
  final bool iaHabilitada;

  const BrandingState({
    this.logoLightUrl,
    this.logoDarkUrl,
    this.appName,
    this.primaryColor,
    this.themeModeName,
    this.contactEmail,
    this.contactPhone,
    this.address,
    this.isLoading = false,
    this.iaHabilitada = true,
  });

  bool get hasCustomLogo => logoLightUrl != null || logoDarkUrl != null;

  Color get effectivePrimaryColor {
    if (primaryColor != null && primaryColor!.isNotEmpty) {
      try {
        final hex = primaryColor!.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    return const Color(0xFFB53F7A);
  }

  ThemeMode get effectiveThemeMode {
    switch (themeModeName) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  BrandingState copyWith({
    String? logoLightUrl,
    String? logoDarkUrl,
    String? appName,
    String? primaryColor,
    String? themeModeName,
    String? contactEmail,
    String? contactPhone,
    String? address,
    bool? isLoading,
    bool? iaHabilitada,
  }) {
    return BrandingState(
      logoLightUrl: logoLightUrl ?? this.logoLightUrl,
      logoDarkUrl: logoDarkUrl ?? this.logoDarkUrl,
      appName: appName ?? this.appName,
      primaryColor: primaryColor ?? this.primaryColor,
      themeModeName: themeModeName ?? this.themeModeName,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      isLoading: isLoading ?? this.isLoading,
      iaHabilitada: iaHabilitada ?? this.iaHabilitada,
    );
  }
}

class BrandingNotifier extends Notifier<BrandingState> {
  @override
  BrandingState build() {
    Future.microtask(loadBranding);
    return const BrandingState(isLoading: true);
  }

  Future<void> loadBranding() async {
    state = state.copyWith(isLoading: true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/admin/configuracion/public');
      final data = response as Map<String, dynamic>;

      state = BrandingState(
        logoLightUrl: data['logo_light_url'] as String?,
        logoDarkUrl: data['logo_dark_url'] as String?,
        appName: data['app_name'] as String?,
        primaryColor: data['app_primary_color'] as String?,
        themeModeName: data['app_default_theme'] as String?,
        contactEmail: data['app_contact_email'] as String?,
        contactPhone: data['app_contact_phone'] as String?,
        address: data['app_address'] as String?,
        isLoading: false,
        iaHabilitada: data['ia_habilitada']?.toString().toLowerCase() != 'false',
      );
    } catch (_) {
      state = const BrandingState(isLoading: false);
    }
  }
}

final brandingProvider = NotifierProvider<BrandingNotifier, BrandingState>(
  BrandingNotifier.new,
);
