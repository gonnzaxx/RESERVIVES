import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/reports_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/core/errors/friendly_error.dart';
import 'package:reservives/config/constants.dart';

class ReportIncidenciaScreen extends ConsumerStatefulWidget {
  const ReportIncidenciaScreen({super.key});

  @override
  ConsumerState<ReportIncidenciaScreen> createState() =>
      _ReportIncidenciaScreenState();
}

class _ReportIncidenciaScreenState
    extends ConsumerState<ReportIncidenciaScreen> {
  final _descriptionController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageName;
  bool _isUploading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
      });
    }
  }

  void _removeImage() => setState(() {
    _imageBytes = null;
    _imageName = null;
  });

  Future<void> _submit() async {
    if (_descriptionController.text.trim().isEmpty) {
      RvAlerts.error(context, context.tr('incidents.error.description'));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      String? uploadedImageUrl;

      if (_imageBytes != null && _imageName != null) {
        final uploadResponse = await apiClient.postMultipart(
          '/uploads/imagen',
          fileField: 'file',
          fileBytes: _imageBytes!,
          fileName: _imageName!,
        );
        uploadedImageUrl = uploadResponse['url'] as String?;
      }

      final success = await ref
          .read(reportarIncidenciaProvider.notifier)
          .reportar(
        _descriptionController.text.trim(),
        imagenUrl: uploadedImageUrl,
      );

      if (mounted) {
        setState(() => _isUploading = false);
        if (success) {
          RvAlerts.success(context, context.tr('incidents.success'));
          Navigator.pop(context);
        } else {
          RvAlerts.error(context, context.tr('incidents.error'));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        RvAlerts.error(context, toFriendlyErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: AppConstants.webMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                  EdgeInsets.fromLTRB(8, 12, 20, isWeb ? 20 : 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('profile.accountEyebrow').toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 0.9,
                                fontWeight: FontWeight.w700,
                                color: theme.hintColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('incidents.title'),
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

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        20, isWeb ? 8 : 4, 20, 60),
                    child: isWeb
                        ? _WebLayout(
                      isDark: isDark,
                      theme: theme,
                      descriptionController: _descriptionController,
                      imageBytes: _imageBytes,
                      onPickImage: _pickImage,
                      onRemoveImage: _removeImage,
                      onSubmit: _submit,
                      isUploading: _isUploading,
                    )
                        : _MobileLayout(
                      isDark: isDark,
                      theme: theme,
                      descriptionController: _descriptionController,
                      imageBytes: _imageBytes,
                      onPickImage: _pickImage,
                      onRemoveImage: _removeImage,
                      onSubmit: _submit,
                      isUploading: _isUploading,
                    ),
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

class _MobileLayout extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final TextEditingController descriptionController;
  final Uint8List? imageBytes;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSubmit;
  final bool isUploading;

  const _MobileLayout({
    required this.isDark,
    required this.theme,
    required this.descriptionController,
    required this.imageBytes,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSubmit,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoBanner(isDark: isDark, theme: theme)
            .animate()
            .fadeIn(delay: 80.ms, duration: 300.ms),

        const SizedBox(height: 24),

        _FieldLabel(
          label: context.tr('incidents.description.label'),
          theme: theme,
        ).animate().fadeIn(delay: 120.ms, duration: 300.ms),
        const SizedBox(height: 10),
        _DescriptionField(
          controller: descriptionController,
          isDark: isDark,
          theme: theme,
        ).animate().fadeIn(delay: 160.ms, duration: 300.ms),

        const SizedBox(height: 28),

        _FieldLabel(
          label: context.tr('incidents.image.label'),
          theme: theme,
        ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
        const SizedBox(height: 10),
        _ImagePicker(
          imageBytes: imageBytes,
          height: 180,
          isDark: isDark,
          theme: theme,
          onTap: onPickImage,
        ).animate().fadeIn(delay: 220.ms, duration: 300.ms),

        if (imageBytes != null) ...[
          const SizedBox(height: 10),
          _RemoveImageButton(onTap: onRemoveImage)
              .animate()
              .fadeIn(duration: 200.ms),
        ],

        const SizedBox(height: 40),

        RvPrimaryButton(
          onTap: onSubmit,
          label: context.tr('incidents.submit'),
          isLoading: isUploading,
          icon: Icons.send_rounded,
        ).animate().fadeIn(delay: 260.ms, duration: 300.ms),
      ],
    );
  }
}

class _WebLayout extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final TextEditingController descriptionController;
  final Uint8List? imageBytes;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSubmit;
  final bool isUploading;

  const _WebLayout({
    required this.isDark,
    required this.theme,
    required this.descriptionController,
    required this.imageBytes,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSubmit,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoBanner(isDark: isDark, theme: theme)
            .animate()
            .fadeIn(delay: 80.ms, duration: 300.ms),

        const SizedBox(height: 28),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(
                    label: context.tr('incidents.description.label'),
                    theme: theme,
                  ),
                  const SizedBox(height: 10),
                  _DescriptionField(
                    controller: descriptionController,
                    isDark: isDark,
                    theme: theme,
                    minLines: 8,
                  ),
                ],
              ).animate().fadeIn(delay: 120.ms, duration: 300.ms),
            ),

            const SizedBox(width: 28),

            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(
                    label: context.tr('incidents.image.label'),
                    theme: theme,
                  ),
                  const SizedBox(height: 10),
                  _ImagePicker(
                    imageBytes: imageBytes,
                    height: 220,
                    isDark: isDark,
                    theme: theme,
                    onTap: onPickImage,
                  ),
                  if (imageBytes != null) ...[
                    const SizedBox(height: 10),
                    _RemoveImageButton(onTap: onRemoveImage),
                  ],
                ],
              ).animate().fadeIn(delay: 160.ms, duration: 300.ms),
            ),
          ],
        ),

        const SizedBox(height: 40),

        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 200,
            child: RvPrimaryButton(
              onTap: onSubmit,
              label: context.tr('incidents.submit'),
              isLoading: isUploading,
              icon: Icons.send_rounded,
            ),
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _InfoBanner({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.m),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.report_problem_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              context.tr('incidents.new.subtitle'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _FieldLabel({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _DescriptionField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final ThemeData theme;
  final int minLines;

  const _DescriptionField({
    required this.controller,
    required this.isDark,
    required this.theme,
    this.minLines = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.m),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft(context),
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        minLines: minLines,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: context.tr('incidents.description.hint'),
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          contentPadding: const EdgeInsets.all(18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.m),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePicker extends StatefulWidget {
  final Uint8List? imageBytes;
  final double height;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _ImagePicker({
    required this.imageBytes,
    required this.height,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_ImagePicker> createState() => _ImagePickerState();
}

class _ImagePickerState extends State<_ImagePicker> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;
    final hasImage = widget.imageBytes != null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: hasImage
                ? Colors.transparent
                : (widget.isDark
                ? AppColors.darkCard
                : Colors.white),
            borderRadius: BorderRadius.circular(AppRadii.m),
            border: Border.all(
              color: hasImage
                  ? Colors.transparent
                  : (_hovered
                  ? primary.withValues(alpha: 0.40)
                  : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06))),
              width: 1.5,
            ),
            boxShadow: hasImage ? AppShadows.soft(context) : null,
          ),
          child: hasImage
              ? ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.m),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(widget.imageBytes!, fit: BoxFit.cover),
                if (_hovered)
                  Container(
                    color: Colors.black.withValues(alpha: 0.40),
                    child: const Center(
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _hovered
                      ? primary.withValues(alpha: 0.12)
                      : primary.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 26,
                  color: primary.withValues(
                      alpha: _hovered ? 0.9 : 0.5),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('incidents.image.tapToSelect'),
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  color: widget.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveImageButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RemoveImageButton({required this.onTap});

  @override
  State<_RemoveImageButton> createState() => _RemoveImageButtonState();
}

class _RemoveImageButtonState extends State<_RemoveImageButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.error.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                size: 15,
                color: AppColors.error,
              ),
              const SizedBox(width: 6),
              Text(
                context.tr('incidents.image.remove'),
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}