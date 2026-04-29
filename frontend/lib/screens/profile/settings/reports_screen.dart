import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reservives/i10n/app_localizations.dart';
import 'package:reservives/providers/reports_provider.dart';
import 'package:reservives/widgets/design_system.dart';
import 'package:reservives/config/app_theme.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/core/errors/friendly_error.dart';

class ReportIncidenciaScreen extends ConsumerStatefulWidget {
  const ReportIncidenciaScreen({super.key});

  @override
  ConsumerState<ReportIncidenciaScreen> createState() => _ReportIncidenciaScreenState();
}

class _ReportIncidenciaScreenState extends ConsumerState<ReportIncidenciaScreen> {
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
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = pickedFile.name;
      });
    }
  }

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

      final success = await ref.read(reportarIncidenciaProvider.notifier).reportar(
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
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 700;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // Cabecera idéntica a FavoritesScreen
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    children: [
                      RvGhostIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('incidents.title'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, isWeb ? 16 : 4, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RvPageHeader(
                          title: context.tr('incidents.new.title'),
                          subtitle: context.tr('incidents.new.subtitle'),
                        ),
                        const SizedBox(height: 32),

                        Text(
                          context.tr('incidents.description.label'),
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: _descriptionController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: context.tr('incidents.description.hint'),
                            filled: true,
                            fillColor: theme.cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Selector de imagen responsivo
                        if (isWeb)
                          _buildWebImagePicker(theme)
                        else
                          _buildMobileImagePicker(theme),

                        const SizedBox(height: 48),

                        // Botón de acción alineado o ancho completo
                        Align(
                          alignment: isWeb ? Alignment.centerRight : Alignment.center,
                          child: SizedBox(
                            width: isWeb ? 200 : double.infinity,
                            child: RvPrimaryButton(
                              onTap: _submit,
                              label: context.tr('incidents.submit'),
                              isLoading: _isUploading,
                              icon: Icons.send_rounded,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildMobileImagePicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('incidents.image.label'),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _imageContainer(theme, height: 180),
      ],
    );
  }

  Widget _buildWebImagePicker(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('incidents.image.label'),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('incidents.image.tapToSelect'),
                style: theme.textTheme.bodySmall,
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _imageBytes = null;
                    _imageName = null;
                  }),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(context.tr('incidents.image.remove')),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 3,
          child: _imageContainer(theme, height: 220),
        ),
      ],
    );
  }

  Widget _imageContainer(ThemeData theme, {required double height}) {
    return GestureDetector(
      onTap: _pickImage,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.1),
            ),
          ),
          child: _imageBytes != null
              ? ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(_imageBytes!, fit: BoxFit.cover),
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_rounded,
                size: 40,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('incidents.image.tapToSelect'),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}