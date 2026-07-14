# Profile Screen (Edit + Sign Out) Design Spec

Date: 2026-07-14

## Goal

Add a Profile screen where the signed-in user can edit their name, photo,
and emergency contact, see their (read-only) email, and sign out. Reached
from a profile avatar in the rides-shell AppBar.

This is a self-contained feature reusing existing services
(`AuthService`, `UserService`), the `AppUser` model, `Validators`, and the
`ProfileSetupController` photo-pick/upload pattern. No data-model or
service changes.

## Current state (reused as-is)

- `AuthService.signOut()` — signs out of Google + Firebase.
- `UserService.fetch(uid)` / `watch(uid)` / `save(AppUser, {isNew})` /
  `uploadProfilePhoto(uid, File)` — all exist.
- `AppUser` — `uid, email, phone, name, photoUrl, emergencyContact,
  fcmToken, createdAt`.
- `Validators.name` / `Validators.emergencyContact`.
- `UiHelpers.confirm({title, message, confirmText, cancelText,
  destructive})` → `Future<bool>`; `UiHelpers.success/error/warning`.
- `ProfileSetupController` — the pattern to mirror for photo pick + upload
  + save (this new screen is essentially "profile setup, but for editing
  an existing profile and with a sign-out action instead of a
  proceed-to-home").
- `RidesShellView` AppBar currently has only a theme-toggle `IconButton`.

## New module: `lib/modules/profile/`

Following the existing GetX module structure (view + controller +
binding):

### `profile_controller.dart` — `ProfileController extends GetxController`

Fields (mirroring `ProfileSetupController`):
- `AuthService _auth`, `UserService _users`, `ImagePicker _picker`.
- `GlobalKey<FormState> formKey`.
- `TextEditingController nameField`, `emergencyField`.
- `Rxn<File> pickedImage`, `RxnString existingPhotoUrl`, `RxnString email`.
- `RxBool saving`, `RxBool loading`.

Methods:
- `onInit` → `_prefill()`: read `_auth.currentUser` for fallback
  name/photo/email, then `_users.fetch(uid)` to fill `nameField`,
  `emergencyField`, `existingPhotoUrl`, `email` from the saved profile.
  Same shape as `ProfileSetupController._prefill`.
- `pickPhoto(ImageSource)` → identical to `ProfileSetupController`.
- `save()` → validate form; upload photo if `pickedImage` set (non-fatal
  on failure, `UiHelpers.warning`); `_users.save(AppUser(...), isNew:
  false)` preserving email/phone from auth; on success
  `UiHelpers.success('Profile updated')` and stay on the screen (do NOT
  navigate away — unlike setup, which goes to home). Refresh
  `existingPhotoUrl` from the uploaded URL and clear `pickedImage` so the
  UI reflects the saved state.
- `signOut()` → `UiHelpers.confirm(title: 'Sign out?', message: 'You'll
  need to sign in again to see your rides.', confirmText: 'Sign out',
  destructive: true)`; if confirmed, `await _auth.signOut()` then
  `Get.offAllNamed(Routes.login)`.
- `validateName` / `validateEmergency` delegating to `Validators`.
- `onClose` disposes both text controllers.

### `profile_view.dart` — `ProfileView extends GetView<ProfileController>`

`Scaffold` with an AppBar titled "Profile". Body uses the current design
system (theme text styles, `AppSpacing`, `AppCard` where a card fits) and
a `LoadingOverlay` bound to `saving`. While `loading`, show a centered
spinner. Layout:
1. A centered avatar with a camera badge (tap → photo source sheet, same
   camera/gallery bottom sheet as profile-setup), showing `pickedImage`
   ?? `existingPhotoUrl` ?? person icon.
2. Read-only email line under the avatar (from `email`).
3. `Form` with `nameField` (label "Your name") and `emergencyField`
   (label "Emergency contact (optional)", helper text like setup),
   validated.
4. `PrimaryButton(label: 'Save changes', onPressed: save)`.
5. An `OutlinedButton.icon` "Sign out" in danger color at the bottom,
   `onPressed: signOut`.

### `profile_binding.dart` — `ProfileBinding extends Bindings`

`Get.lazyPut<ProfileController>(() => ProfileController())`.

## Routing

- Add `Routes.profile = '/profile'` to `app_routes.dart`.
- Register a `GetPage` for it in `app_pages.dart` (view +
  `ProfileBinding`, `Transition.rightToLeft`), plus the two new imports.

## Entry point

In `RidesShellView`'s AppBar `actions`, add a profile avatar `IconButton`
before (left of) the existing theme-toggle. It shows the user's photo if
available (via a small `CircleAvatar` reading
`Get.find<AuthService>().currentUser?.photoURL`, or a `person` icon
fallback) and `onPressed: () => Get.toNamed(Routes.profile)`.

## Non-goals

- No account deletion, no email change (Google-managed), no sign-in
  method change.
- No shared base class extracted from `ProfileSetupController` (only two
  usages — YAGNI; mirror the pattern instead).
- No changes to `AuthService`/`UserService`/`AppUser`.

## Testing / verification

- `flutter analyze` clean; existing tests pass (this adds a new module
  and one AppBar action; no existing test imports these).
- Manual on-device: open Profile from the AppBar avatar; edit name +
  emergency contact + photo and Save → success message, values persist
  (reopen to confirm); email shows read-only; Sign out → confirm dialog →
  returns to login and the nav stack is cleared (back button doesn't
  re-enter the app).

## Risk

Low — new self-contained module reusing proven services/patterns; the
only edit to existing code is one AppBar action + route registration.
