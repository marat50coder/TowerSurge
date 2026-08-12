# Tower Surge

Flutter (Android) replica of the *Tower Rush* style crash slot: a crane drops floor
after floor onto a tower, every floor multiplies the stake, and the player has to
cash out before a floor misses and the tower collapses.

The game is portrait only. The loading screen is the single place that supports both
portrait and landscape artwork. Everything is played offline: the network is only
touched when the player opens the Privacy Policy or Support page.

## Running

```bash
flutter pub get
flutter run -d <android-device>
```

Release build:

```bash
flutter build apk --release
```

Application id: `com.surgefort.towersurgegame`.

## Project layout

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | App entry, system UI setup, portrait lock after loading |
| `lib/core/` | Palette and text styles, persisted store, audio, sprite loading |
| `lib/game/tower_game.dart` | Game model: RNG, multipliers, bonus floors, physics, camera |
| `lib/game/scene_painter.dart` | `CustomPainter` that draws the whole playfield |
| `lib/screens/` | Loading, game and WebView screens |
| `lib/widgets/` | Top bar, bet controls, results panel, menu sheets, Temple wheel |
| `assets/` | Artwork, sounds and fonts shipped with the app |

## Math model

* Every BUILD press draws a floor multiplier from a weighted table; the tables get
  more generous (and more dangerous) at floors 4+ and 9+.
* The floor leaves the hook where the crane was when BUILD was pressed and is only
  nudged toward the tower (`_aimAssist`), so the stack ends up slightly ragged, and
  the landing spot is clamped so the tower can never reach a screen edge.
* A failed floor is not a collapse: it clips the top floor, is thrown sideways and
  falls past the tower under gravity while the tower stays standing.
* The house edge is taken **once**, on the first floor of a round
  (`_firstFloorRtp = 0.97`). All later floors are expectation neutral
  (`_fairStep`, tuned together with the bonus floors), so the return does not depend
  on how long the player keeps building — the same property real crash games have.
* Total win is capped at `maxMultiplier` (100x).
* Bonus floors, never on the first floor:
  * **Frozen Floor** – locks the current win as a payout floor; a later collapse still
    pays the frozen amount.
  * **Temple Floor** – spins a bonus wheel (x1.5 … x7, plus one FROZEN segment).
  * **Triple Build** – three guaranteed floors in a row.

`test/rtp_test.dart` is a Monte Carlo check that the return stays around 96–97 %
whether the player cashes out after 1, 3, 6 or 12 floors.

## Tests and visual review

```bash
flutter test
```

Besides the unit tests, the suite renders the real widgets to PNG files in `/tmp`
so the artwork can be reviewed without a device:

* `test/render_scene_test.dart` → `/tmp/scene_*.png` (painter only)
* `test/render_screen_test.dart` → `/tmp/screen_*.png` (full game screen, several rounds)
* `test/render_ui_test.dart` → `/tmp/ui_*.png` (loading, menu, info sheet, Temple wheel)
* `test/render_miss_test.dart` → `/tmp/miss_*.png` (a floor clipping the tower and tumbling off)

## Web pages

Privacy Policy and Support open in an in-app WebView
(`lib/screens/web_page_screen.dart`) from the menu:

* https://towersurge.com/privacy-policy.html
* https://towersurge.com/support.html

## Icon and splash

Both are hand written so they stay identical, and both come from
`assets/Tower_Surge_additional_assets/Icon.png`:

* `res/mipmap-anydpi-v26/ic_launcher.xml` and `res/drawable-anydpi-v26/ic_splash_logo.xml`
  are the same `<adaptive-icon>`: `@color/launch_bg` behind `@drawable/ic_launcher_fg`.
* `ic_launcher_fg` insets the artwork by 15dp of the 108dp layer (14%), which keeps the
  whole tower visible under the circle, squircle and teardrop masks without zooming in.
  Raise it to 18-20dp if a mask clips, drop it to 11-13dp if the art looks too small.
* `values-v31/styles.xml` (and the night variant) feed that drawable to the Android 12+
  splash through `windowSplashScreenAnimatedIcon`. It has to be an adaptive icon —
  a flat PNG is ignored and the platform quietly falls back to the launcher icon.
* Older releases use `drawable/launch_background.xml`, the same colour plus a PNG copy.
* `mipmap-*/ic_launcher.png` are pre-composed for API 25 and below.

`flutter_launcher_icons` is deliberately not used: it writes the artwork edge to edge
into the background layer, where every launcher mask crops it.

To change the artwork or the inset, regenerate `drawable-nodpi/ic_launcher_art.png`
and `mipmap-*/ic_launcher.png` from the source image and adjust the inset in
`drawable/ic_launcher_fg.xml`.
