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
import '../../services/user_service.dart';

/// Collects the user's name, optional photo, and optional emergency contact,
/// then writes `users/{uid}` and proceeds to home.
///
/// Pre-fills from the Google account (name, photo, email) — captured either in
/// the sign-in stub or read live from FirebaseAuth. Photo upload uses Firebase
/// Storage; if it fails we still save the rest of the profile.
class ProfileSetupController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();
  final ImagePicker _picker = ImagePicker();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController nameField = TextEditingController();
  final TextEditingController emergencyField = TextEditingController();

  final Rxn<File> pickedImage = Rxn<File>();
  final RxnString existingPhotoUrl = RxnString();
  final RxnString email = RxnString(); // shown read-only, from Google
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
    // Live Google data is the fallback if the Firestore stub isn't there yet.
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
      Log.e('prefill failed', error: e, stack: s);
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
      UiHelpers.error('Could not open the ${source == ImageSource.camera ? 'camera' : 'gallery'}.');
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
      // 1) Upload photo if a new one was picked (non-fatal on failure).
      String? photoUrl = existingPhotoUrl.value;
      final File? img = pickedImage.value;
      if (img != null) {
        try {
          photoUrl = await _users.uploadProfilePhoto(uid, img);
        } catch (e, s) {
          Log.e('photo upload failed', error: e, stack: s);
          UiHelpers.warning('Saved without photo — upload failed. You can add it later.');
        }
      }

      // 2) Write the profile. Email/phone come from the Google account.
      final String emailValue =
          email.value ?? _auth.currentUser?.email ?? '';
      final String phone = _auth.currentUser?.phoneNumber ?? '';
      final String? emergency = emergencyField.text.trim().isEmpty
          ? null
          : emergencyField.text.trim();

      await _users.save(
        AppUser(
          uid: uid,
          email: emailValue,
          phone: phone,
          name: nameField.text.trim(),
          photoUrl: photoUrl,
          emergencyContact: emergency,
        ),
        // merge:true is used under the hood, so createdAt from the sign-in stub
        // is preserved; isNew only controls the serverTimestamp default.
        isNew: false,
      );

      Get.offAllNamed(Routes.home);
    } catch (e, s) {
      Log.e('profile save failed', error: e, stack: s);
      UiHelpers.error('Could not save your profile. Check your connection and retry.');
    } finally {
      saving.value = false;
    }
  }

  String? validateName(String? v) => Validators.name(v);
  String? validateEmergency(String? v) => Validators.emergencyContact(v);
}
