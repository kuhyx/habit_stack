# Design audit — habit_stack

Generated against safe-design-rules (anthonyhobday.com/sideprojects/saferules).
Report only — nothing in this repo was changed by the audit itself.

## Flutter app (lib/)

Theme entry point: `lib/main.dart:19-32` — `MaterialApp.theme`/`darkTheme`,
both built from a single `ColorScheme.fromSeed(seedColor: const
Color(0xFF66BB6A))` (light) and the same seed with `Brightness.dark`. No
dedicated `theme.dart`; no `textTheme`, `elevation`, `shadow`, or
`buttonTheme` overrides anywhere in the repo. 15 `.dart` files total; UI
styling only appears in `lib/main.dart`, `lib/screens/habit_list_screen.dart`,
`lib/screens/habit_form_screen.dart`, `lib/screens/streak_screen.dart` (grepped
`Colors.|Color(0x|fontSize|BorderRadius|boxShadow|EdgeInsets|elevation|shape:`
across all of `lib/` to confirm — `models/`, `services/`, `desktop/` are pure
logic, no hits).

### Violations

- **Rule 2 (saturate your neutrals)** — `lib/screens/streak_screen.dart:118` —
  `_DayCell` uses `Colors.grey.shade300` for the not-done state, a flat
  Material gray with no relation to the seeded `ColorScheme`'s tonal neutrals
  → use `Theme.of(context).colorScheme.surfaceContainerHighest` (or another
  scheme-derived neutral) so the gray is tinted consistently with the rest of
  the palette.
- **Rule 4 (everything deliberate)** — `lib/screens/habit_list_screen.dart:99`
  and `lib/screens/streak_screen.dart:118` — both hardcode `Colors.green` for
  the "done" state instead of a token from the app's own `ColorScheme`
  (`colorScheme.primary` or a named semantic color) → replace with a
  scheme-derived color so "done" has one deliberate definition instead of two
  independent literals that happen to look similar.
- **Rule 19 (outer padding ≥ inner padding)** — `lib/screens/habit_form_screen.dart:126`
  sets the scroll container's outer padding to `EdgeInsets.all(16)`, but the
  gaps between grouped children inside it are `SizedBox(height: 24)` at
  `habit_form_screen.dart:172` and `:177` — inner spacing (24) exceeds the
  container's own edge padding (16) → either grow the outer padding to ≥24 or
  shrink those inter-section gaps to ≤16.
- **Rule 20 (body text ≥16px)** — `lib/screens/streak_screen.dart:57`
  (`Text('No habits yet.')`), `lib/screens/streak_screen.dart:77`
  (`Text('Streak: $streak day...')`), and
  `lib/screens/habit_list_screen.dart:90` (`Text('No habits yet -- add one
  below.')`) — all are bare `Text` widgets with no explicit `style`, so they
  fall back to Material 3's default `bodyMedium` (14px), below the platform
  default of 16px → apply `Theme.of(context).textTheme.bodyLarge` (16px) or
  set an explicit `TextStyle(fontSize: 16)`.
- **Rule 28 (lower icon contrast next to text)** — `lib/screens/habit_list_screen.dart:82-83`
  (streak `IconButton`) and `:97-100` (done/not-done leading `Icon` in each
  `ListTile`) — icons render at full theme contrast directly beside body text
  with no opacity/dimming applied → apply `.withValues(alpha: ~0.7-0.8)` (or
  the M3 `onSurfaceVariant` token) to de-emphasize icons relative to adjacent
  text.

### Not applicable

- Rule 5 (optical alignment) — only stock Material icons/widgets in
  standard slots (`ListTile` leading, `AppBar` actions); no custom shapes
  with off-center bounding boxes to align by eye.
- Rule 6 (letter-spacing/line-height by size) — no custom `textTheme` or
  per-size `TextStyle` overrides exist to check; app relies entirely on
  Material 3's built-in type scale.
- Rule 7 (container border contrast) — no `Border`/`BorderSide` usage
  anywhere in `lib/` (confirmed via grep).
- Rule 9 (distinct brightness values in palette) — only one seed color is
  used; there's no multi-color palette to check for brightness collisions.
  The one place two greens do coexist is covered under Rule 4 above.
- Rule 13 (12-column grid) — single-column mobile list/form layouts
  throughout; no grid system in play.
- Rule 15 (closer elements lighter) — no manual z-stack/elevation values
  set anywhere; only default `FloatingActionButton`/button elevation.
- Rule 16 (shadow blur ≈ 2× distance) — no custom `BoxShadow` anywhere in
  the repo (confirmed via grep).
- Rule 18 (container brightness limits) — no stacked custom-colored
  containers (e.g. cards on cards); rows are plain `ListTile`s on the
  scaffold background.
- Rule 21 (line length ~70 chars) — all body copy is short phrases (habit
  sentences, streak counts); no paragraph-length text to measure.
- Rule 24 (nest corners properly) — no manually authored corner radii
  anywhere in `lib/` (confirmed via grep for `BorderRadius`/`radius`); the
  one custom shape (`streak_screen.dart:119`, `BoxShape.circle`) isn't a
  nested-corner case.
- Rule 25 (avoid adjacent hard divides) — no `Divider` or stacked border
  usage found; `ListView.builder` rows have no manual separators.
- Rule 26 (no shadows in dark interfaces) — no shadow/elevation theming
  exists to selectively disable for `darkTheme`; both themes share
  identical (default) elevation behavior, so there's no dark-specific
  authored shadow to flag.

### Notes

- **No dedicated theme file and no typography/shape/elevation tokens at
  all** — `lib/main.dart:19-32` only sets `colorScheme` via
  `ColorScheme.fromSeed`. This is why 9 of the 12 N/A rules above are N/A
  "by absence" rather than by a checked-and-passing decision: there's
  nothing authored to audit for typography, borders, shadows, or corner
  radii. If a future pass wants those rules to mean something, it needs a
  `lib/theme.dart` with an explicit `textTheme`, `elevation`, and
  `outlinedButtonTheme`/`filledButtonTheme` first.
- The two `Colors.green` / `Colors.grey.shade300` literals (Rules 2, 4) are
  the only two points where the app diverges from single-source-of-truth
  theming — fixing both is a small, contained change (2 files, 3 call
  sites) once scoped as its own task.
