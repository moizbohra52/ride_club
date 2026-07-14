import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import 'profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Obx(
        () => LoadingOverlay(
          isLoading: controller.saving.value,
          message: 'Saving…',
          child: controller.loading.value
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl,
                        AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
                    child: Form(
                      key: controller.formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Center(child: _PhotoPicker(scheme: scheme)),
                          const SizedBox(height: AppSpacing.md),
                          Obx(() {
                            final String? mail = controller.email.value;
                            return Text(
                              mail == null || mail.isEmpty ? '' : mail,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          }),
                          const SizedBox(height: AppSpacing.xxl),
                          TextFormField(
                            controller: controller.nameField,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Your name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: controller.validateName,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextFormField(
                            controller: controller.emergencyField,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Emergency contact (optional)',
                              hintText: '+91 98765 43210',
                              prefixIcon: Icon(Icons.emergency_outlined),
                              helperText:
                                  'Alerted with your live location if you hit SOS.',
                            ),
                            validator: controller.validateEmergency,
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          PrimaryButton(
                            label: 'Save changes',
                            icon: Icons.check_rounded,
                            onPressed: controller.save,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                              minimumSize: const Size.fromHeight(54),
                            ),
                            onPressed: controller.signOut,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Sign out'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final ColorScheme scheme;
  const _PhotoPicker({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final ProfileController c = Get.find<ProfileController>();
    return GestureDetector(
      onTap: () => _showPhotoSheet(context, c),
      child: Obx(() {
        final ImageProvider? provider = c.pickedImage.value != null
            ? FileImage(c.pickedImage.value!)
            : (c.existingPhotoUrl.value != null
                ? CachedNetworkImageProvider(c.existingPhotoUrl.value!)
                    as ImageProvider
                : null);
        return Stack(
          children: <Widget>[
            CircleAvatar(
              radius: 48,
              backgroundColor: scheme.primaryContainer,
              backgroundImage: provider,
              child: provider == null
                  ? Icon(Icons.person,
                      size: 48, color: scheme.onPrimaryContainer)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.sunset,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: const Icon(Icons.camera_alt,
                    size: 15, color: Colors.white),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showPhotoSheet(BuildContext context, ProfileController c) {
    Get.bottomSheet(
      SafeArea(
        child: Wrap(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('Profile photo',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Get.back();
                c.pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Get.back();
                c.pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }
}
