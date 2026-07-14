# RideTogether Visual Refresh — Design Spec

Date: 2026-07-13

## Goal

Evolve RideTogether's existing Material 3 design (blue/orange brand, Poppins,
rounded cards, gradients) into a more polished, consistent, modern-feeling UI —
without changing navigation, animation timing, features, or the app's visual
identity (map/chat/SOS colors, member colors, brand hues stay as-is).

This is a **pure UI-layer refresh**: design tokens → shared widgets → a visual
pass over key screens. No GetX/state/service/model changes.

## Problems with the current UI

1. **Ad-hoc spacing/radii/shadows.** Every screen hand-picks `EdgeInsets` and
   `BorderRadius.circular(...)` values (10/12/14/16/18/22/24 all appear), and
   `BoxShadow` is a single flat layer per widget. Consistency is coincidental.
2. **Gradient overuse.** `AppColors.brandGradient` appears on the login hero,
   ride-code card, profile header, avatar camera badge, host accent strip, and
   host avatar icon. With that many uses it stops reading as a highlight.
3. **No codified type scale.** Font sizes/weights are inlined per-widget
   (`GoogleFonts.poppins(fontSize: 22, fontWeight: w800)` etc.) instead of
   coming from named `TextTheme` roles.
4. **Duplicated card chrome.** `_RideCard`, `_RequestTile`, `_MemberTile` (and
   others) each hand-roll the same "surface + border + shadow" container.

## Design tokens (new files under `lib/core/theme/`)

### `app_spacing.dart` — `AppSpacing`
```
xs = 4, sm = 8, md = 12, lg = 16, xl = 20, xxl = 28, xxxl = 40
```
Replaces hand-picked `EdgeInsets` magic numbers across screens.

### `app_radius.dart` — `AppRadius`
```
sm = 10   // chips, small badges
md = 14   // inputs, buttons, list tiles
lg = 18   // cards
xl = 24   // sheets, dialogs, hero blocks
```
Consolidates today's 10/12/14/16/18/22/24 spread into 4 steps. Each exposed
both as a `double` and as a ready `BorderRadius.circular(...)` getter (e.g.
`AppRadius.lgRadius`) to avoid repeating `BorderRadius.circular(AppRadius.lg)`
everywhere.

### `app_elevation.dart` — `AppElevation`
Dual-layer shadow helper — a tight, low-opacity dark shadow plus a soft, wide
tint shadow — instead of today's single flat `BoxShadow`. Three levels:
- `soft(Color tint)` — resting cards/tiles
- `medium(Color tint)` — raised cards (ride-code card, elevated buttons)
- `strong(Color tint)` — hero/floating elements (FAB, active CTA)

Each returns `List<BoxShadow>` so it drops directly into existing
`BoxDecoration(boxShadow: ...)` call sites.

### Typography scale (extend `AppTheme`)
Named roles built once from `GoogleFonts.poppinsTextTheme`, mapped onto
Flutter's `TextTheme` slots so screens use `Theme.of(context).textTheme.X`
instead of inlining font params:

| Role | Maps to | Size / weight |
|---|---|---|
| Display | `headlineLarge` | 28 / w800, tight letter-spacing |
| Headline | `headlineSmall` | 22 / w800 |
| Title | `titleLarge` | 16–18 / w700 |
| Body | `bodyMedium` | 14–15 / w400 |
| Label | `labelLarge` | 12–13 / w600 |
| Caption | `labelSmall` | 11–12 / w500, used for eyebrows like "RIDE CODE" |

Existing `cardTheme`/`inputDecorationTheme`/etc. in `AppTheme` get updated to
reference `AppRadius`/`AppElevation` instead of inline literals; their visual
result stays close to current (same radii family) but consistent.

## Color refinement (`AppColors`)

No hue changes to `seed`, `sunset`, status colors, or `memberColors` — these
are the app's identity and stay. One addition:

- `surfaceAccent` — a tonal container color (derived from `seed`, no
  gradient) for places that currently duplicate `brandGradient` purely for
  emphasis rather than as a true hero moment: profile header background,
  avatar camera badge, host accent strip, host avatar icon.

**Gradient is reserved for exactly two hero moments**, both already gradient
today: the login screen hero, and the ride-detail code card. Every other
current gradient use switches to solid `seed` / `surfaceAccent` /
`ColorScheme.primaryContainer` as appropriate.

## Shared widgets (`lib/widgets/`)

### `AppCard`
Replaces the copy-pasted "surface + border + shadow" `Container` pattern in
`_RideCard`, `_RequestTile`, `_MemberTile`, and similar. Props: `child`,
optional `onTap` (wraps in `Material`/`InkWell` when present), optional
`accentColor` (renders the left accent strip used by ride cards), `padding`
(defaults to `AppSpacing.lg`). Uses `AppRadius.lg` + `AppElevation.soft`
internally, dark/light aware via `ColorScheme`.

### `PrimaryButton` (existing file, restyled not rewritten)
Keeps its current press-scale interaction and gradient-variant support
(`useGradient`), but shadow/radius pull from `AppElevation`/`AppRadius`
instead of inline values. Behavior unchanged.

### `StatusBadge`
New small pill widget unifying the 3 hand-rolled variants already in the
codebase (chat unread count circle, "Host" tag, "Ended" tag). Props: `label`
or `count`, `color` (background derives a tonal variant automatically).

## Screen pass (visual only)

- **Login (`login_view.dart`):** hero keeps its gradient + route-motif
  painter unchanged; typography switches to the new text-theme roles; the
  "Continue with Google" button shadow uses `AppElevation`.
- **My Rides (`my_rides_tab.dart`):** `_RideCard` rebuilt on top of `AppCard`;
  host accent strip and host icon background switch from `brandGradient` to
  `surfaceAccent`/`primary` solid; unread badge switches to `StatusBadge`.
- **Ride Detail (`ride_detail_view.dart`):** code card keeps its gradient
  (hero moment #2); `_RequestTile`/`_MemberTile` rebuilt on `AppCard`; "Host"
  tag and chat unread badge switch to `StatusBadge`.
- **Profile Setup (`profile_setup_view.dart`):** header background switches
  from `brandGradient` to solid `surfaceAccent`/`seed` tonal; avatar camera
  badge switches from `accentGradient` to solid `sunset`/`surfaceAccent`
  (kept visually distinct from the header background); avatar glow shadow
  uses `AppElevation`.
- **Rides Shell / nav bar:** no visual change beyond whatever falls out of
  `AppTheme` token updates (already themed centrally).

Screens not explicitly listed (chat, live map, SOS, splash) are **not**
touched beyond incidental benefit from shared `AppTheme`/`AppCard` changes —
out of scope for this pass per the approved plan.

## Non-goals

- No changes to navigation structure, routing, or animation timing/curves.
- No changes to map, chat, or SOS visual identity (marker colors, bubble
  styles, alert dialogs) beyond incidental token consistency.
- No dark/light palette hue changes — `ColorScheme.fromSeed(AppColors.seed)`
  stays the source of truth.
- No new features or widgets beyond `AppCard`/`StatusBadge`.

## Testing / verification

- `flutter analyze` clean.
- Existing widget tests continue to pass (no controller/service logic
  touched, so no test updates expected; if a widget test asserts on now-
  removed inline styling it will be adjusted, not the underlying behavior).
- Visual check on Android emulator: login, my rides (empty + populated),
  ride detail (host + member view), profile setup — left to user per prior
  phases' pattern in this project.

## Risk

Low — UI-layer only, no GetX controllers/services/models touched. Fully
reversible per-file since each screen's visual pass is independent.
