import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/primary_button.dart';
import 'profile_setup_controller.dart';

/// Profile setup. A short gradient header (carrying the login's horizon motif)
/// holds the avatar and email, then a calm white form collects name + optional
/// emergency contact.
class ProfileSetupView extends GetView<ProfileSetupController> {
  const ProfileSetupView({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Obx(
        () => LoadingOverlay(
          isLoading: controller.saving.value,
          message: 'Saving your profile…',
          child: controller.loading.value
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: <Widget>[
                    _Header(scheme: scheme),
                    Expanded(
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                          child: Form(
                            key: controller.formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  'Set up your profile',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This is how your friends will recognise you '
                                  'on the map.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 28),
                                TextFormField(
                                  controller: controller.nameField,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Your name',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: controller.validateName,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: controller.emergencyField,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Emergency contact (optional)',
                                    hintText: '+91 98765 43210',
                                    prefixIcon: Icon(Icons.emergency_outlined),
                                    helperText:
                                        'Alerted with your live location if you '
                                        'hit SOS.',
                                  ),
                                  validator: controller.validateEmergency,
                                ),
                                const SizedBox(height: 36),
                                PrimaryButton(
                                  label: 'Continue',
                                  icon: Icons.arrow_forward_rounded,
                                  onPressed: controller.save,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Gradient header with the avatar overlapping its bottom edge, plus email.
class _Header extends StatelessWidget {
  final ColorScheme scheme;
  const _Header({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final ProfileSetupController c = Get.find<ProfileSetupController>();
    return SizedBox(
      height: 210,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Container(
            height: 170,
            width: double.infinity,
            decoration: const BoxDecoration(color: AppColors.surfaceAccent),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.explore_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'RideClub',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Obx(() {
                      final String? mail = c.email.value;
                      if (mail == null || mail.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: Text(
                          mail,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          // Avatar overlapping the gradient's bottom edge.
          Positioned(bottom: 0, child: _PhotoPicker(scheme: scheme)),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final ColorScheme scheme;
  const _PhotoPicker({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final ProfileSetupController c = Get.find<ProfileSetupController>();
    return GestureDetector(
      onTap: () => _showPhotoSheet(context, c),
      child: Obx(() {
        final ImageProvider? provider = c.pickedImage.value != null
            ? FileImage(c.pickedImage.value!)
            : (c.existingPhotoUrl.value != null
                  ? CachedNetworkImageProvider(c.existingPhotoUrl.value!)
                        as ImageProvider
                  : null);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.surface, width: 4),
            boxShadow: AppElevation.strong(AppColors.surfaceAccent),
          ),
          child: Stack(
            children: <Widget>[
              CircleAvatar(
                radius: 48,
                backgroundColor: scheme.primaryContainer,
                backgroundImage: provider,
                child: provider == null
                    ? Icon(
                        Icons.person,
                        size: 48,
                        color: scheme.onPrimaryContainer,
                      )
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
                    boxShadow: AppElevation.soft(AppColors.sunset),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showPhotoSheet(BuildContext context, ProfileSetupController c) {
    Get.bottomSheet(
      SafeArea(
        child: Wrap(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Profile photo',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
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
