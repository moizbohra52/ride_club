import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/logger.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../models/app_user.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/local_alerts_service.dart';
import '../../services/ride_service.dart';
import '../../services/user_service.dart';

/// Edit the signed-in user's profile (name, photo, emergency contact) and
/// sign out. Mirrors [ProfileSetupController]'s photo/save pattern, but
/// stays on-screen after saving and offers a sign-out action.
class ProfileController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();
  final RideService _rides = Get.find<RideService>();
  final ImagePicker _picker = ImagePicker();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController nameField = TextEditingController();
  final TextEditingController emergencyField = TextEditingController();

  final Rxn<File> pickedImage = Rxn<File>();
  final RxnString existingPhotoUrl = RxnString();
  final RxnString email = RxnString();
  final RxBool saving = false.obs;
  final RxBool loading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _prefill();
  }

  @override
  void onClose() {
    nameField.dispose();
    emergencyField.dispose();
    super.onClose();
  }

  Future<void> _prefill() async {
    final user = _auth.currentUser;
    nameField.text = user?.displayName ?? '';
    existingPhotoUrl.value = user?.photoURL;
    email.value = user?.email;
    try {
      final String? uid = _auth.uid;
      if (uid != null) {
        final AppUser? existing = await _users.fetch(uid);
        if (existing != null) {
          if (existing.name.isNotEmpty) nameField.text = existing.name;
          emergencyField.text = existing.emergencyContact ?? '';
          existingPhotoUrl.value = existing.photoUrl ?? existingPhotoUrl.value;
          if (existing.email.isNotEmpty) email.value = existing.email;
        }
      }
    } catch (e, s) {
      Log.e('profile prefill failed', error: e, stack: s);
    } finally {
      loading.value = false;
    }
  }

  Future<void> pickPhoto(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 80,
      );
      if (file != null) pickedImage.value = File(file.path);
    } catch (e, s) {
      Log.e('pickPhoto failed', error: e, stack: s);
      UiHelpers.error(
          'Could not open the ${source == ImageSource.camera ? 'camera' : 'gallery'}.');
    }
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final String? uid = _auth.uid;
    if (uid == null) {
      UiHelpers.error('Your session ended. Please sign in again.');
      Get.offAllNamed(Routes.login);
      return;
    }
    saving.value = true;
    try {
      String? photoUrl = existingPhotoUrl.value;
      final File? img = pickedImage.value;
      if (img != null) {
        try {
          photoUrl = await _users.uploadProfilePhoto(uid, img);
        } catch (e, s) {
          Log.e('photo upload failed', error: e, stack: s);
          UiHelpers.warning(
              'Saved without photo — upload failed. You can add it later.');
        }
      }
      final String emailValue = email.value ?? _auth.currentUser?.email ?? '';
      final String phone = _auth.currentUser?.phoneNumber ?? '';
      final String? emergency = emergencyField.text.trim().isEmpty
          ? null
          : emergencyField.text.trim();

      final String newName = nameField.text.trim();
      await _users.save(
        AppUser(
          uid: uid,
          email: emailValue,
          phone: phone,
          name: newName,
          photoUrl: photoUrl,
          emergencyContact: emergency,
        ),
        isNew: false,
      );

      // Push the new name/photo into every ride the user is already in, so old
      // rides don't keep showing the stale snapshot. Best-effort: don't fail
      // the whole save if this sync hiccups.
      try {
        await _rides.syncMemberProfile(name: newName, photoUrl: photoUrl);
      } catch (e, s) {
        Log.e('ride member profile sync failed', error: e, stack: s);
      }

      // Reflect the saved state in the UI and stay on the screen.
      existingPhotoUrl.value = photoUrl;
      pickedImage.value = null;
      UiHelpers.success('Profile updated');
    } catch (e, s) {
      Log.e('profile save failed', error: e, stack: s);
      UiHelpers.error(
          'Could not save your profile. Check your connection and retry.');
    } finally {
      saving.value = false;
    }
  }

  Future<void> signOut() async {
    final bool ok = await UiHelpers.confirm(
      title: 'Sign out?',
      message: "You'll need to sign in again to see your rides.",
      confirmText: 'Sign out',
      destructive: true,
    );
    if (!ok) return;
    Get.find<LocalAlertsService>().stop();
    await _auth.signOut();
    Get.offAllNamed(Routes.login);
  }

  String? validateName(String? v) => Validators.name(v);
  String? validateEmergency(String? v) => Validators.emergencyContact(v);
}
