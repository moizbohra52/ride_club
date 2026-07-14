# Profile Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A Profile screen to edit name/photo/emergency-contact, show
read-only email, and sign out — reached from a rides-shell AppBar avatar.

**Architecture:** New `lib/modules/profile/` GetX module (view + controller
+ binding) mirroring `ProfileSetupController`'s photo/save pattern, plus a
route and one AppBar action.

**Tech Stack:** Flutter, GetX, image_picker, existing
`AuthService`/`UserService`/`AppUser`/`Validators`/`UiHelpers`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-14-profile-screen-design.md`.
- Do not modify `AuthService`, `UserService`, `AppUser`, `Validators`,
  `UiHelpers`.
- After every task: `flutter analyze` (no new issues) + `flutter test`
  (all pass). Not a git repo — skip commits.

---

### Task 1: Profile controller + binding

**Files:**
- Create: `lib/modules/profile/profile_controller.dart`
- Create: `lib/modules/profile/profile_binding.dart`

**Interfaces:**
- Produces: `ProfileController` with `formKey`, `nameField`,
  `emergencyField`, `pickedImage`, `existingPhotoUrl`, `email`, `saving`,
  `loading`, `pickPhoto(ImageSource)`, `save()`, `signOut()`,
  `validateName`, `validateEmergency`.
- Produces: `ProfileBinding`.

- [ ] **Step 1: Write `profile_controller.dart`** (use this file verbatim)

```dart
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

/// Edit the signed-in user's profile (name, photo, emergency contact) and
/// sign out. Mirrors [ProfileSetupController]'s photo/save pattern, but
/// stays on-screen after saving and offers a sign-out action.
class ProfileController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();
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

      await _users.save(
        AppUser(
          uid: uid,
          email: emailValue,
          phone: phone,
          name: nameField.text.trim(),
          photoUrl: photoUrl,
          emergencyContact: emergency,
        ),
        isNew: false,
      );

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
    await _auth.signOut();
    Get.offAllNamed(Routes.login);
  }

  String? validateName(String? v) => Validators.name(v);
  String? validateEmergency(String? v) => Validators.emergencyContact(v);
}
```

- [ ] **Step 2: Write `profile_binding.dart`**

```dart
import 'package:get/get.dart';
import 'profile_controller.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileController>(() => ProfileController());
  }
}
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: errors only from `profile_view.dart` not existing yet? No —
the view isn't referenced anywhere until Task 2/3, so analyze should be
CLEAN here. If it flags an unused `ProfileController` or similar, that's
fine to ignore only if it's the binding's lazyPut (it won't). Confirm no
real errors in the two new files.

- [ ] **Step 4: Test**

Run: `flutter test` → all existing tests pass.

---

### Task 2: Profile view + route registration

**Files:**
- Create: `lib/modules/profile/profile_view.dart`
- Modify: `lib/routes/app_routes.dart`
- Modify: `lib/routes/app_pages.dart`

**Interfaces:**
- Consumes: `ProfileController` (Task 1), `ProfileBinding` (Task 1).
- Produces: `Routes.profile`; a registered `GetPage`.

- [ ] **Step 1: Add the route constant**

Edit `lib/routes/app_routes.dart`, add after `rideDetail`:

```dart
  static const String profile = '/profile';
```

- [ ] **Step 2: Write `profile_view.dart`**

```dart
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
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
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
                child: const Icon(Icons.camera_alt, size: 15, color: Colors.white),
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
```

- [ ] **Step 3: Register the page in `app_pages.dart`**

Add imports (alphabetical with the others):

```dart
import '../modules/profile/profile_binding.dart';
import '../modules/profile/profile_view.dart';
```

Add a `GetPage` to the `pages` list (after the `rideDetail` entry):

```dart
    GetPage<dynamic>(
      name: Routes.profile,
      page: () => const ProfileView(),
      binding: ProfileBinding(),
      transition: Transition.rightToLeft,
    ),
```

- [ ] **Step 4: Analyze + test**

Run: `flutter analyze` → no new issues.
Run: `flutter test` → all pass.

---

### Task 3: AppBar entry point in rides shell

**Files:**
- Modify: `lib/modules/rides/rides_shell_view.dart`

**Interfaces:**
- Consumes: `Routes.profile`, `AuthService`.

- [ ] **Step 1: Add the profile avatar action**

Edit `lib/modules/rides/rides_shell_view.dart`. Add imports if missing:

```dart
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
```

In the `AppBar`'s `actions` list, add a profile `IconButton` BEFORE the
existing theme-toggle `Obx(...)`:

```dart
            IconButton(
              tooltip: 'Profile',
              onPressed: () => Get.toNamed(Routes.profile),
              icon: Builder(
                builder: (BuildContext context) {
                  final String? photo =
                      Get.find<AuthService>().currentUser?.photoURL;
                  if (photo == null) {
                    return const Icon(Icons.account_circle_outlined);
                  }
                  return CircleAvatar(
                    radius: 14,
                    backgroundImage: NetworkImage(photo),
                  );
                },
              ),
            ),
```

(Uses `NetworkImage` — a plain avatar in the AppBar; the heavier
`CachedNetworkImageProvider` isn't required here. `cached_network_image`
is only needed in the profile view itself.)

- [ ] **Step 2: Analyze + test**

Run: `flutter analyze` → no new issues.
Run: `flutter test` → all pass.

- [ ] **Step 3: Manual on-device verification**

1. Open the app to the rides shell; tap the profile avatar in the AppBar
   → Profile screen opens.
2. Email shows read-only; name + emergency prefilled from the saved
   profile.
3. Change the name, tap Save → "Profile updated" success; reopen Profile
   → the new name persisted.
4. Change the photo (camera/gallery) → Save → photo persists.
5. Tap Sign out → confirm dialog → after confirming, land on login;
   pressing back does not re-enter the app (stack cleared).

Report which checks pass; don't mark complete until all do.
