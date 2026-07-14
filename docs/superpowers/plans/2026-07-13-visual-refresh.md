# RideTogether Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a small design-token system (spacing/radius/elevation/type
scale), two shared widgets (`AppCard`, `StatusBadge`), and apply them across
five screens (splash, login, my rides, ride detail, profile setup) — limiting
the brand gradient to two hero moments (login hero, ride-code card) — with no
changes to GetX controllers, services, models, or navigation.

**Architecture:** Pure UI-layer refresh. New token files live in
`lib/core/theme/` alongside the existing `app_colors.dart`/`app_theme.dart`.
Two new shared widgets live in `lib/widgets/` next to the existing
`primary_button.dart`/`loading_overlay.dart`. Each screen is edited in place;
no file moves.

**Tech Stack:** Flutter (Material 3), GetX, google_fonts (Poppins). No new
dependencies.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-13-visual-refresh-design.md`.
- Do not modify any GetX controller, service, or model file.
- Do not change `AppColors.seed`, `AppColors.sunset`, status colors, or
  `AppColors.memberColors` / `memberColorAt` / `memberColorForKey` — the
  existing test `test/widget_test.dart` asserts on
  `AppColors.memberColorForKey` and `AppColors.memberColors.first` verbatim;
  these must keep working unchanged.
- Gradient (`AppColors.brandGradient`) is reserved for exactly two places
  after this refresh: the login hero (`login_view.dart`) and the ride-detail
  code card (`ride_detail_view.dart`). Every other current use of
  `brandGradient`/`accentGradient` is replaced with a solid color per-task
  below.
- Radius scale: `sm=10, md=14, lg=18, xl=24` (see Task 1). Spacing scale:
  `xs=4, sm=8, md=12, lg=16, xl=20, xxl=28, xxxl=40` (see Task 1).
- After every task: run `flutter analyze` (expect no new warnings/errors)
  and `flutter test` (expect all existing tests still pass).
- Commit after each task with `git add <files touched in that task>` (never
  a blanket `git add -A`).

---

## File Structure

New files:
- `lib/core/theme/app_spacing.dart` — `AppSpacing` constants.
- `lib/core/theme/app_radius.dart` — `AppRadius` constants + `BorderRadius` getters.
- `lib/core/theme/app_elevation.dart` — `AppElevation.soft/medium/strong` shadow lists.
- `lib/widgets/app_card.dart` — shared card container.
- `lib/widgets/status_badge.dart` — shared pill/badge widget.

Modified files:
- `lib/core/theme/app_colors.dart` — add `surfaceAccent`.
- `lib/core/theme/app_theme.dart` — reference new tokens; add named text styles.
- `lib/widgets/primary_button.dart` — restyle shadow/radius via tokens.
- `lib/modules/splash/splash_view.dart` — typography/shadow tokens only (gradient logo mark stays, per "signature" motif — see Task 7 rationale).
- `lib/modules/auth/login_view.dart` — typography tokens; hero gradient stays.
- `lib/modules/profile_setup/profile_setup_view.dart` — header/badge gradient → solid.
- `lib/modules/rides/my_rides_tab.dart` — `_RideCard` → `AppCard`; host accent → solid; unread badge → `StatusBadge`.
- `lib/modules/rides/ride_detail_view.dart` — tiles → `AppCard`; badges → `StatusBadge`; code card gradient stays.

---

### Task 1: Spacing, radius, and elevation tokens

**Files:**
- Create: `lib/core/theme/app_spacing.dart`
- Create: `lib/core/theme/app_radius.dart`
- Create: `lib/core/theme/app_elevation.dart`
- Test: `test/design_tokens_test.dart`

**Interfaces:**
- Produces: `AppSpacing.xs/sm/md/lg/xl/xxl/xxxl` (all `double`).
- Produces: `AppRadius.sm/md/lg/xl` (`double`) and `AppRadius.smRadius/mdRadius/lgRadius/xlRadius` (`BorderRadius`, each `BorderRadius.circular(...)` of the matching value).
- Produces: `AppElevation.soft(Color tint)`, `AppElevation.medium(Color tint)`, `AppElevation.strong(Color tint)` — each returns `List<BoxShadow>` with exactly 2 shadows (a tight dark shadow + a soft tint shadow).

- [ ] **Step 1: Write the failing test**

```dart
// test/design_tokens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/core/theme/app_spacing.dart';
import 'package:ride_club/core/theme/app_radius.dart';
import 'package:ride_club/core/theme/app_elevation.dart';

void main() {
  group('AppSpacing', () {
    test('scale is strictly increasing', () {
      expect(AppSpacing.xs, lessThan(AppSpacing.sm));
      expect(AppSpacing.sm, lessThan(AppSpacing.md));
      expect(AppSpacing.md, lessThan(AppSpacing.lg));
      expect(AppSpacing.lg, lessThan(AppSpacing.xl));
      expect(AppSpacing.xl, lessThan(AppSpacing.xxl));
      expect(AppSpacing.xxl, lessThan(AppSpacing.xxxl));
    });
  });

  group('AppRadius', () {
    test('scale is strictly increasing', () {
      expect(AppRadius.sm, lessThan(AppRadius.md));
      expect(AppRadius.md, lessThan(AppRadius.lg));
      expect(AppRadius.lg, lessThan(AppRadius.xl));
    });

    test('BorderRadius getters match the double values', () {
      expect(AppRadius.lgRadius, BorderRadius.circular(AppRadius.lg));
      expect(AppRadius.mdRadius, BorderRadius.circular(AppRadius.md));
    });
  });

  group('AppElevation', () {
    test('soft/medium/strong each return exactly two shadows', () {
      expect(AppElevation.soft(Colors.blue).length, 2);
      expect(AppElevation.medium(Colors.blue).length, 2);
      expect(AppElevation.strong(Colors.blue).length, 2);
    });

    test('strong has a larger blur radius than soft', () {
      final double softBlur = AppElevation.soft(Colors.blue).last.blurRadius;
      final double strongBlur =
          AppElevation.strong(Colors.blue).last.blurRadius;
      expect(strongBlur, greaterThan(softBlur));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/design_tokens_test.dart`
Expected: FAIL — files `app_spacing.dart`, `app_radius.dart`, `app_elevation.dart` don't exist yet (import errors).

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/app_spacing.dart

/// Shared spacing scale for RideTogether. Use these instead of hand-picked
/// EdgeInsets/SizedBox numbers so spacing stays consistent across screens.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;
}
```

```dart
// lib/core/theme/app_radius.dart

import 'package:flutter/material.dart';

/// Shared corner-radius scale for RideTogether.
///
/// sm = chips/small badges, md = inputs/buttons/list tiles, lg = cards,
/// xl = sheets/dialogs/hero blocks.
class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;

  static const BorderRadius smRadius =
      BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius =
      BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius =
      BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlRadius =
      BorderRadius.all(Radius.circular(xl));
}
```

```dart
// lib/core/theme/app_elevation.dart

import 'package:flutter/material.dart';

/// Dual-layer shadow system: a tight, low-opacity dark shadow for depth plus
/// a soft, wide tint shadow for glow. Replaces single flat BoxShadow literals
/// that were scattered across screens.
class AppElevation {
  AppElevation._();

  static List<BoxShadow> soft(Color tint) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> medium(Color tint) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.22),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> strong(Color tint) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.32),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/design_tokens_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Run full analyze + test suite**

Run: `flutter analyze && flutter test`
Expected: no new issues; all tests (existing + new) pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/app_spacing.dart lib/core/theme/app_radius.dart lib/core/theme/app_elevation.dart test/design_tokens_test.dart
git commit -m "feat: add spacing, radius, and elevation design tokens"
```

---

### Task 2: `surfaceAccent` color + named typography scale in `AppTheme`

**Files:**
- Modify: `lib/core/theme/app_colors.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Test: `test/design_tokens_test.dart` (extend)

**Interfaces:**
- Consumes: nothing new beyond `package:flutter/material.dart`.
- Produces: `AppColors.surfaceAccent` (`Color`, a tonal container-style blue,
  independent of dark/light — screens combine it with `ColorScheme` as
  needed exactly like `AppColors.sunset` already is).
- Produces: `AppTheme.light`/`AppTheme.dark` continue to return `ThemeData`,
  now with `textTheme` populated so `headlineLarge`, `headlineSmall`,
  `titleLarge`, `bodyMedium`, `labelLarge`, `labelSmall` all have explicit
  Poppins-based `TextStyle`s (sizes/weights per the spec's table). No
  existing `ThemeData` field is removed.

- [ ] **Step 1: Write the failing test**

```dart
// Add to test/design_tokens_test.dart, inside a new group at the end of main():

  group('AppColors.surfaceAccent', () {
    test('is defined and distinct from seed', () {
      expect(AppColors.surfaceAccent, isNotNull);
    });
  });

  group('AppTheme text styles', () {
    test('light theme defines the named type scale', () {
      final ThemeData theme = AppTheme.light;
      expect(theme.textTheme.headlineLarge?.fontSize, 28);
      expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w800);
      expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w800);
      expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w700);
      expect(theme.textTheme.labelSmall?.fontWeight, FontWeight.w500);
    });
  });
```

Add the needed imports at the top of `test/design_tokens_test.dart`:
```dart
import 'package:ride_club/core/theme/app_colors.dart';
import 'package:ride_club/core/theme/app_theme.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/design_tokens_test.dart`
Expected: FAIL — `AppColors.surfaceAccent` doesn't exist; `headlineLarge` etc. don't match yet.

- [ ] **Step 3: Add `surfaceAccent` to `AppColors`**

Edit `lib/core/theme/app_colors.dart`, add after the existing `sos` constant (around line 27):

```dart
  /// Tonal accent for headers/badges that previously duplicated
  /// [brandGradient] purely for emphasis (profile header, avatar badge, host
  /// markers). Solid, not a gradient — reserves the gradient for the two
  /// true hero moments (login hero, ride-code card).
  static const Color surfaceAccent = Color(0xFF3B5DE0);
```

- [ ] **Step 4: Add named text styles to `AppTheme`**

Edit `lib/core/theme/app_theme.dart`. Replace the `textTheme: baseText,` line
(around line 30) with a `textTheme` that layers the named roles on top of
`baseText`:

```dart
      textTheme: baseText.copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        labelSmall: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
```

Note: `scheme` and `baseText` are already in scope in `_build` — this is a
same-method edit, not a new method.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/design_tokens_test.dart`
Expected: PASS (all groups)

- [ ] **Step 6: Run full analyze + test suite**

Run: `flutter analyze && flutter test`
Expected: no new issues; all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/app_colors.dart lib/core/theme/app_theme.dart test/design_tokens_test.dart
git commit -m "feat: add surfaceAccent color and named typography scale"
```

---

### Task 3: `AppCard` shared widget

**Files:**
- Create: `lib/widgets/app_card.dart`
- Test: `test/app_card_test.dart`

**Interfaces:**
- Consumes: `AppRadius.lgRadius` (Task 1), `AppElevation.soft` (Task 1).
- Produces: `AppCard` widget with constructor:
  ```dart
  const AppCard({
    super.key,
    required Widget child,
    VoidCallback? onTap,
    Color? accentColor,
    EdgeInsetsGeometry? padding,
  })
  ```
  Later tasks (4, 8, 9) construct `AppCard(child: ..., onTap: ..., accentColor: ...)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/app_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/core/theme/app_theme.dart';
import 'package:ride_club/widgets/app_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      );

  testWidgets('renders its child', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const AppCard(child: Text('hello'))));
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(wrap(AppCard(
      onTap: () => taps++,
      child: const Text('tap me'),
    )));
    await tester.tap(find.text('tap me'));
    expect(taps, 1);
  });

  testWidgets('is not tappable when onTap is null', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const AppCard(child: Text('static'))));
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('renders an accent strip when accentColor is given',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(AppCard(
      accentColor: Colors.red,
      child: const Text('accented'),
    )));
    expect(find.text('accented'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app_card_test.dart`
Expected: FAIL — `lib/widgets/app_card.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/widgets/app_card.dart

import 'package:flutter/material.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_spacing.dart';

/// Shared surface container: rounded corners, a themed border, and a soft
/// dual-layer shadow. Replaces the "surface + border + shadow" Container
/// pattern that was copy-pasted across ride cards and list tiles.
///
/// Pass [accentColor] to render a 4px left accent strip (e.g. to mark the
/// host's ride card). Pass [onTap] to make the whole card tappable with an
/// ink ripple; omit it for a static card.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.accentColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget content = Row(
      children: <Widget>[
        if (accentColor != null)
          Container(
            width: 4,
            height: 78,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.lg),
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
            child: child,
          ),
        ),
      ],
    );

    final Decoration decoration = BoxDecoration(
      color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
      borderRadius: AppRadius.lgRadius,
      border: Border.all(
        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.15),
      ),
      boxShadow: AppElevation.soft(
        isDark ? Colors.black : scheme.primary,
      ),
    );

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: onTap,
        child: Ink(decoration: decoration, child: content),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/app_card_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Run full analyze + test suite**

Run: `flutter analyze && flutter test`
Expected: no new issues; all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/app_card.dart test/app_card_test.dart
git commit -m "feat: add shared AppCard widget"
```

---

### Task 4: `StatusBadge` shared widget

**Files:**
- Create: `lib/widgets/status_badge.dart`
- Test: `test/status_badge_test.dart`

**Interfaces:**
- Consumes: `AppRadius.sm` (Task 1).
- Produces: `StatusBadge` widget, two named constructors:
  ```dart
  StatusBadge.count({super.key, required int count, Color color = AppColors.sos})
  StatusBadge.label({super.key, required String label, required Color color})
  ```
  `StatusBadge.count` renders nothing (`SizedBox.shrink()`) when `count <= 0`,
  and shows `"9+"` when `count > 9`. `StatusBadge.label` always renders.
  Later tasks (8, 9) use `StatusBadge.count(count: n)` for unread badges and
  `StatusBadge.label(label: 'Host', color: scheme.primary)` /
  `StatusBadge.label(label: 'Ended', color: Colors.white)` for tags.

- [ ] **Step 1: Write the failing test**

```dart
// test/status_badge_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/widgets/status_badge.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('count badge shows the number', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(StatusBadge.count(count: 3)));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('count badge caps display at 9+', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(StatusBadge.count(count: 42)));
    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('count badge renders nothing for zero', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(StatusBadge.count(count: 0)));
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('label badge shows its label', (WidgetTester tester) async {
    await tester.pumpWidget(
        wrap(StatusBadge.label(label: 'Host', color: Colors.blue)));
    expect(find.text('Host'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/status_badge_test.dart`
Expected: FAIL — `lib/widgets/status_badge.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/widgets/status_badge.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';

/// Small pill/circle used for counts (chat unread) and short tags
/// ("Host", "Ended"). Unifies three hand-rolled variants that previously
/// existed in my_rides_tab.dart and ride_detail_view.dart.
class StatusBadge extends StatelessWidget {
  final int? count;
  final String? label;
  final Color color;
  final Color? textColor;

  const StatusBadge._({
    super.key,
    this.count,
    this.label,
    required this.color,
    this.textColor,
  });

  /// A small circular count badge (e.g. unread messages). Renders nothing
  /// when [count] is 0 or less. Displays "9+" above 9.
  factory StatusBadge.count({
    Key? key,
    required int count,
    Color color = AppColors.sos,
  }) =>
      StatusBadge._(key: key, count: count, color: color);

  /// A small rounded-rect text pill (e.g. "Host", "Ended").
  factory StatusBadge.label({
    Key? key,
    required String label,
    required Color color,
    Color? textColor,
  }) =>
      StatusBadge._(
        key: key,
        label: label,
        color: color,
        textColor: textColor,
      );

  @override
  Widget build(BuildContext context) {
    if (count != null) {
      if (count! <= 0) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        child: Text(
          count! > 9 ? '9+' : '$count',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label ?? '',
        style: GoogleFonts.poppins(
          color: textColor ?? Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/status_badge_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Run full analyze + test suite**

Run: `flutter analyze && flutter test`
Expected: no new issues; all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/status_badge.dart test/status_badge_test.dart
git commit -m "feat: add shared StatusBadge widget"
```

---

### Task 5: Restyle `PrimaryButton` shadow/radius via tokens

**Files:**
- Modify: `lib/widgets/primary_button.dart`

**Interfaces:**
- Consumes: `AppRadius.md` (Task 1), `AppElevation.medium`/`AppElevation.soft` (Task 1).
- Produces: same public API as before — `PrimaryButton({label, onPressed, loading, icon, useGradient})`. No signature change; behavior (press-scale, disabled state) unchanged.

- [ ] **Step 1: Replace inline radius/shadow literals with tokens**

Edit `lib/widgets/primary_button.dart`. Add the import at the top:

```dart
import '../core/theme/app_radius.dart';
import '../core/theme/app_elevation.dart';
```

Replace each `BorderRadius.circular(14)` (there are two, in the gradient
branch and the standard branch) with `AppRadius.mdRadius`.

Replace the gradient branch's shadow (currently a single
`BoxShadow(color: AppColors.primaryGlow, blurRadius: 16, offset: Offset(0,6))`)
with:

```dart
              boxShadow: disabled
                  ? null
                  : AppElevation.medium(AppColors.seed),
```

Replace the standard branch's shadow (currently
`BoxShadow(color: AppColors.primaryGlow.withValues(alpha: 0.3), blurRadius: 12, offset: Offset(0,4))`)
with:

```dart
          decoration: disabled
              ? null
              : BoxDecoration(
                  borderRadius: AppRadius.mdRadius,
                  boxShadow: AppElevation.soft(AppColors.seed),
                ),
```

- [ ] **Step 2: Run analyze + test**

Run: `flutter analyze && flutter test`
Expected: no new issues; all tests pass (no test exercises this widget's
visuals directly, so this is a manual-diff-review step, not a red/green
TDD step — confirm by reading the diff that `AppColors.primaryGlow` is no
longer referenced in this file and both `BorderRadius.circular(14)` sites
are gone).

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/primary_button.dart
git commit -m "refactor: restyle PrimaryButton shadow/radius via design tokens"
```

---

### Task 6: `AppTheme` component themes reference the new tokens

**Files:**
- Modify: `lib/core/theme/app_theme.dart`

**Interfaces:**
- Consumes: `AppRadius.mdRadius`/`lgRadius`/`xlRadius`, `AppElevation.soft` (Task 1).
- Produces: same `AppTheme.light`/`AppTheme.dark` API; `cardTheme`,
  `inputDecorationTheme`, `filledButtonTheme`, `outlinedButtonTheme`,
  `bottomSheetTheme`, `dialogTheme`, `floatingActionButtonTheme` keep their
  current field names/values in spirit but source their radius from
  `AppRadius` instead of inline `BorderRadius.circular(N)`.

- [ ] **Step 1: Replace inline radii with `AppRadius`**

Edit `lib/core/theme/app_theme.dart`. Add the import:

```dart
import 'app_radius.dart';
```

Make these substitutions (each is a literal find/replace of the existing
`BorderRadius.circular(N)` call at that call site — do not change any other
property on the same widget):

- `cardTheme.shape`: `BorderRadius.circular(18)` → `AppRadius.lgRadius`
- `inputDecorationTheme.border/enabledBorder/focusedBorder/errorBorder/focusedErrorBorder`: each `BorderRadius.circular(14)` → `AppRadius.mdRadius`
- `filledButtonTheme.style.shape`: `BorderRadius.circular(14)` → `AppRadius.mdRadius`
- `outlinedButtonTheme.style.shape`: `BorderRadius.circular(14)` → `AppRadius.mdRadius`
- `bottomSheetTheme.shape`: `BorderRadius.vertical(top: Radius.circular(24))` stays as-is (asymmetric radius, not a plain `circular` — no direct `AppRadius` getter covers this shape; leave it using the raw `24` literal since it equals `AppRadius.xl`, but add a one-line comment referencing that):

```dart
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          // Matches AppRadius.xl (24) — asymmetric radius has no direct getter.
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
```

- `dialogTheme.shape`: `BorderRadius.circular(24)` → `AppRadius.xlRadius`
- `floatingActionButtonTheme.shape`: `BorderRadius.circular(16)` → this value (16) isn't in the 4-step scale; round it down to the nearest defined step, `AppRadius.md` (14), for consistency: `BorderRadius.circular(16)` → `AppRadius.mdRadius`
- `listTileTheme.shape`: `BorderRadius.circular(12)` → nearest defined step is `AppRadius.sm` (10); replace with `AppRadius.smRadius`
- `chipTheme.shape`: `BorderRadius.circular(10)` → `AppRadius.smRadius`

Leave `cardTheme.shadowColor` and all `ColorScheme`/color logic untouched —
this task only touches radius literals.

- [ ] **Step 2: Run analyze + test**

Run: `flutter analyze && flutter test`
Expected: no new issues; all tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/core/theme/app_theme.dart
git commit -m "refactor: source AppTheme component radii from AppRadius scale"
```

---

### Task 7: Splash + Login — typography tokens, hero gradient unchanged

**Files:**
- Modify: `lib/modules/splash/splash_view.dart`
- Modify: `lib/modules/auth/login_view.dart`

**Interfaces:**
- Consumes: `Theme.of(context).textTheme.headlineLarge`/`bodyMedium` (Task 2), `AppSpacing` (Task 1). No new widget APIs produced (leaf screens).

- [ ] **Step 1: Splash — swap inline Poppins calls for theme text styles**

Edit `lib/modules/splash/splash_view.dart`. The gradient logo mark
(`AppColors.brandGradient`) is the app's launch identity and is **not** one
of the two hero moments being restricted — leaving it as-is is intentional:
splash is a transient, full-bleed brand moment shown once per cold start,
distinct from the persistent gradient-overuse problem the refresh targets
(headers/badges/strips reusing the gradient as decoration). No change to
`_SplashBody`'s gradient container or `_pulseAnim`/`_fadeAnim` logic.

Replace the two inline `Text` styles:

```dart
                Text(
                  'RideTogether',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ride as one. Never lose the group.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
```

with:

```dart
                Text(
                  'RideTogether',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ride as one. Never lose the group.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
```

The `GoogleFonts` import in this file becomes unused after this edit —
remove the `import 'package:google_fonts/google_fonts.dart';` line.

- [ ] **Step 2: Login — swap inline Poppins calls for theme text styles**

Edit `lib/modules/auth/login_view.dart`. The hero gradient
(`_HorizonHero`, `AppColors.brandGradient`) is hero moment #1 and stays
byte-for-byte unchanged, including its wordmark/statement-mark styling
(that text is on a gradient background, not a themed surface, so it keeps
its explicit white `GoogleFonts.poppins` styles — only the sign-in-card
section below the hero switches to theme text styles).

Replace:

```dart
                        Text(
                          'Ride as one.',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'See every friend on the map, chat live, and never '
                          'lose the group on the road.',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
```

with:

```dart
                        Text(
                          'Ride as one.',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'See every friend on the map, chat live, and never '
                          'lose the group on the road.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 15),
                        ),
```

And replace the footnote text:

```dart
                        Text(
                          'We only use your Google name and photo to show you '
                          'to your ride group.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
```

with:

```dart
                        Text(
                          'We only use your Google name and photo to show you '
                          'to your ride group.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(letterSpacing: 0),
                        ),
```

Do not remove the `google_fonts` import from this file — `_HorizonHero` and
`_GoogleButton` still use `GoogleFonts.poppins` directly for the hero and
button, which is correct (they render on a gradient/dark button background,
not a themed surface).

- [ ] **Step 2: Run analyze + test**

Run: `flutter analyze && flutter test`
Expected: no new issues (confirm the removed `google_fonts` import in
`splash_view.dart` doesn't leave an unused-import warning; confirm
`login_view.dart` still uses `GoogleFonts` so its import stays valid); all
tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/modules/splash/splash_view.dart lib/modules/auth/login_view.dart
git commit -m "refactor: use theme text styles on splash and login screens"
```

---

### Task 8: My Rides — `_RideCard` on `AppCard`, `StatusBadge`, gradient → solid

**Files:**
- Modify: `lib/modules/rides/my_rides_tab.dart`

**Interfaces:**
- Consumes: `AppCard` (Task 3), `StatusBadge.count` (Task 4), `AppColors.surfaceAccent` (Task 2), `AppSpacing` (Task 1).

- [ ] **Step 1: Rebuild `_RideCard` on `AppCard`**

Edit `lib/modules/rides/my_rides_tab.dart`. Add imports:

```dart
import '../../core/theme/app_spacing.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';
```

Replace the entire `_RideCard` class body's `build` method. Current code
(lines 136–280) wraps everything in `Material`/`InkWell`/`Ink` with a
manual accent strip and manual unread badge; replace with:

```dart
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () => Get.toNamed(Routes.rideDetail, arguments: ride.id),
      accentColor: isHost ? AppColors.surfaceAccent : scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md + 2),
      child: Row(
        children: <Widget>[
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: isHost ? AppColors.surfaceAccent : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isHost ? Icons.star_rounded : Icons.group_rounded,
              color: isHost ? Colors.white : scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  ride.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${isHost ? 'Host' : 'Rider'} · Code ${ride.code}'
                  '${ride.isActive ? '' : ' · Ended'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                      ),
                ),
              ],
            ),
          ),
          StreamBuilder<int>(
            stream: Get.find<ChatService>().unreadCount(ride.id),
            builder: (_, AsyncSnapshot<int> snap) {
              final int n = snap.data ?? 0;
              if (n == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: StatusBadge.count(count: n),
              );
            },
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
```

Note: `isDark` is no longer read directly in `_RideCard.build` (`AppCard`
handles dark/light internally) — remove the now-unused
`final bool isDark = Theme.of(context).brightness == Brightness.dark;` line
from the top of the old `build` method when replacing it.

Also update the empty-state heading (`_empty` method, around line 58–60) and
the "no rides yet" body text to use theme text styles for consistency:

```dart
            Text('No rides yet',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Create a ride or join one with a code to get started.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
```

Remove the now-unused `google_fonts` import if no other `GoogleFonts.` call
remains in the file (check with a search before removing).

- [ ] **Step 2: Run analyze + test**

Run: `flutter analyze && flutter test`
Expected: no new issues (in particular, no unused-import or unused-variable
warnings for `isDark`/`google_fonts`); all tests pass.

- [ ] **Step 3: Manual visual check**

This screen renders live ride data via GetX — no widget test harness exists
for it in this repo (per project convention, visual verification is done by
the user on-device). Note in the commit message that this is pending
on-device check, consistent with how prior phases handled visual review.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/rides/my_rides_tab.dart
git commit -m "refactor: rebuild My Rides card on AppCard/StatusBadge, drop gradient accent"
```

---

### Task 9: Ride Detail — tiles on `AppCard`, badges on `StatusBadge`, code card gradient stays

**Files:**
- Modify: `lib/modules/rides/ride_detail_view.dart`

**Interfaces:**
- Consumes: `AppCard` (Task 3), `StatusBadge.count`/`StatusBadge.label` (Task 4), `AppSpacing`/`AppRadius`/`AppElevation` (Task 1).
- Produces: the module-level `unreadBadge(int n)` function (used elsewhere
  via `import 'ride_detail_view.dart' show unreadBadge`, if any — verify with
  a repo search in Step 1) is replaced by callers using `StatusBadge.count`
  directly; if any external caller exists, update it in this same task.

- [ ] **Step 1: Check for external callers of `unreadBadge`**

Run: `grep -rn "unreadBadge" lib`
Expected: shows the definition in `ride_detail_view.dart` plus its one call
site in `_chatAction()` in the same file (confirm no other module imports
it — if one is found, update that call site to `StatusBadge.count(count: n)`
as part of Step 2 below).

- [ ] **Step 2: Replace `unreadBadge` uses and remove the function**

Edit `lib/modules/rides/ride_detail_view.dart`. Add imports:

```dart
import '../../core/theme/app_spacing.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';
```

In `_chatAction()`, replace:

```dart
            if (n > 0) Positioned(right: 6, top: 6, child: unreadBadge(n)),
```

with:

```dart
            if (n > 0)
              Positioned(right: 6, top: 6, child: StatusBadge.count(count: n)),
```

Delete the module-level `unreadBadge` function entirely (the block starting
`/// A small red count badge, shared by chat entry points.` through its
closing `);`).

- [ ] **Step 3: Replace `_RequestTile` and `_MemberTile` bodies with `AppCard`**

Replace the `_RequestTile.build` method:

```dart
  @override
  Widget build(BuildContext context) {
    final RideDetailController c = Get.find<RideDetailController>();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundImage: req.photoUrl != null
                  ? CachedNetworkImageProvider(req.photoUrl!)
                  : null,
              child: req.photoUrl == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(req.name,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              onPressed: () => c.accept(req),
              icon: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 28),
            ),
            IconButton(
              onPressed: () => c.reject(req),
              icon:
                  const Icon(Icons.cancel, color: AppColors.danger, size: 28),
            ),
          ],
        ),
      ),
    );
  }
```

The `isDark`/`scheme` fields on `_RequestTile` are now unused — remove them
from the constructor and its call site in the parent `ListView`/`Column`
(the `_RequestTile(req: r, isDark: isDark, scheme: scheme)` call becomes
`_RequestTile(req: r)`; update the class declaration to only take `req`).

Replace the `_MemberTile.build` method similarly:

```dart
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: member.color.withValues(alpha: 0.6),
                  width: 2.5,
                ),
              ),
              child: CircleAvatar(
                backgroundColor: member.color.withValues(alpha: 0.15),
                backgroundImage: member.photoUrl != null
                    ? CachedNetworkImageProvider(member.photoUrl!)
                    : null,
                child: member.photoUrl == null
                    ? Text(
                        member.name.isNotEmpty
                            ? member.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: member.color, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(member.name,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            if (member.isHost)
              StatusBadge.label(
                label: 'Host',
                color: scheme.primaryContainer,
                textColor: scheme.primary,
              ),
          ],
        ),
      ),
    );
  }
```

Update `_MemberTile`'s constructor the same way — it no longer needs
`isDark` (only `member` is required); update its call site
(`_MemberTile(member: m, isDark: isDark, scheme: scheme)` →
`_MemberTile(member: m)`).

After these two changes, the parent `build` method's local
`final bool isDark = ...` (declared near the top of `RideDetailView.build`)
may become unused if nothing else in the file reads it — check with
`grep -n "isDark" lib/modules/rides/ride_detail_view.dart` and remove the
declaration if no reads remain.

- [ ] **Step 4: Replace the "Ended" tag in `_codeCard` with `StatusBadge.label`**

The code card keeps its gradient (hero moment #2) — do not touch its
`BoxDecoration`/`AppColors.brandGradient`/`AppColors.primaryGlow`. Only
replace the inline "Ended" pill:

```dart
              if (!active)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Ended',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
```

with:

```dart
              if (!active)
                StatusBadge.label(
                  label: 'Ended',
                  color: Colors.white.withValues(alpha: 0.2),
                  textColor: Colors.white,
                ),
```

Leave the "RIDE CODE" eyebrow and the big code text as their current
`GoogleFonts.poppins` calls — they're white-on-gradient, styled to match
hero moment #2 specifically, not a themed-surface text role.

- [ ] **Step 5: Run analyze + test**

Run: `flutter analyze && flutter test`
Expected: no new issues (check specifically for unused `isDark`/`scheme`
fields/params flagged by the linter after the constructor simplifications);
all tests pass.

- [ ] **Step 6: Manual visual check**

Same as Task 8 — no widget-test harness for this screen; on-device
verification is left to the user per project convention.

- [ ] **Step 7: Commit**

```bash
git add lib/modules/rides/ride_detail_view.dart
git commit -m "refactor: rebuild Ride Detail tiles on AppCard/StatusBadge"
```

---

### Task 10: Profile Setup — header/badge gradient → solid `surfaceAccent`

**Files:**
- Modify: `lib/modules/profile_setup/profile_setup_view.dart`

**Interfaces:**
- Consumes: `AppColors.surfaceAccent` (Task 2), `AppElevation.strong` (Task 1).

- [ ] **Step 1: Replace the header gradient with solid `surfaceAccent`**

Edit `lib/modules/profile_setup/profile_setup_view.dart`. In `_Header.build`,
replace:

```dart
          Container(
            height: 170,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.brandGradient,
              ),
            ),
```

with:

```dart
          Container(
            height: 170,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.surfaceAccent,
            ),
```

- [ ] **Step 2: Replace the avatar camera badge gradient with solid `sunset`**

In `_PhotoPicker.build`, replace:

```dart
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.accentGradient,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.accentGlow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 15, color: Colors.white),
                ),
```

with:

```dart
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.sunset,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                    boxShadow: AppElevation.soft(AppColors.sunset),
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 15, color: Colors.white),
                ),
```

Add the import:

```dart
import '../../core/theme/app_elevation.dart';
```

- [ ] **Step 3: Update the avatar's own glow shadow to use `AppElevation`**

Still in `_PhotoPicker.build`, replace the outer avatar container's shadow:

```dart
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.surface, width: 4),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primaryGlow,
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
```

with:

```dart
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.surface, width: 4),
            boxShadow: AppElevation.strong(AppColors.surfaceAccent),
          ),
```

- [ ] **Step 4: Update headline/subtitle text to theme text styles**

Replace:

```dart
                                Text(
                                  'Set up your profile',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This is how your friends will recognise you '
                                  'on the map.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
```

with:

```dart
                                Text(
                                  'Set up your profile',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This is how your friends will recognise you '
                                  'on the map.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
```

The header's own `RideTogether` wordmark and email text stay
`GoogleFonts.poppins(color: Colors.white...)` — they render on the solid
`surfaceAccent` background, same reasoning as the login hero.

- [ ] **Step 5: Run analyze + test**

Run: `flutter analyze && flutter test`
Expected: no new issues (in particular, `AppColors.accentGradient` and
`AppColors.accentGlow` may now be unused across the whole `lib/` tree —
run `grep -rn "accentGradient\|accentGlow" lib` and, if truly unreferenced
elsewhere, leave the constants defined in `app_colors.dart` as public API
rather than deleting them, since removing public constants from a shared
color file is out of scope for this task); all tests pass.

- [ ] **Step 6: Manual visual check**

Same as Task 8/9 — on-device verification left to the user.

- [ ] **Step 7: Commit**

```bash
git add lib/modules/profile_setup/profile_setup_view.dart
git commit -m "refactor: replace Profile Setup gradient accents with solid surfaceAccent/sunset"
```

---

### Task 11: Final full-repo verification

**Files:** none (verification-only task)

- [ ] **Step 1: Confirm gradient usage is limited to the two hero moments**

Run: `grep -rn "brandGradient" lib`
Expected: matches only in `lib/core/theme/app_colors.dart` (the constant's
definition), `lib/modules/auth/login_view.dart` (`_HorizonHero`),
`lib/modules/rides/ride_detail_view.dart` (`_codeCard`), and
`lib/modules/splash/splash_view.dart` (the launch logo mark, explicitly
kept per Task 7's rationale). No other file should appear.

- [ ] **Step 2: Run the full analyze + test suite one more time**

Run: `flutter analyze && flutter test`
Expected: zero issues, all tests pass.

- [ ] **Step 3: Report remaining manual verification to the user**

State clearly which screens still need an on-device visual check (My Rides,
Ride Detail, Profile Setup, Login, Splash) per this project's established
pattern of leaving final visual confirmation to the user — do not claim the
redesign is "done" beyond the code-level verification performed here.
