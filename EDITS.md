# Editing & rebuilding TPVR locally

This is a from-source working copy of [JoeyAW/TPVR](https://github.com/JoeyAW/TPVR)
(a VR mod of the Dusklight Twilight Princess PC port fork), set up so we can edit
and rebuild without touching the original install.

## Layout

| What | Where |
| --- | --- |
| Source (this repo) | `D:\Games\TwilightVRPlus` |
| Build tree | `C:\Dev\TPVR-build\windows-msvc-rwdi` |
| Debug build tree | `C:\Dev\TPVR-build\windows-msvc-debug` |
| OpenXR SDK (prebuilt) | `C:\Dev\TPVR-deps\openxr-sdk` |
| Built game | `C:\Dev\TPVR-build\windows-msvc-rwdi\dusklight.exe` |
| Your original install (untouched) | `D:\Games\TwilightVR` |

The build tree is on `C:` to spare `D:` space; the built folder is
self-contained (`dusklight.exe`, `res\`, runtime `*.dll`, `mods\*.dusk`), so it
runs straight from the build directory.

## Build

```bat
build.bat              :: RelWithDebInfo build (what you normally want)
build.bat debug        :: Debug build
build.bat clean        :: wipe the RelWithDebInfo build tree, then build
build.bat debug clean  :: wipe the Debug build tree, then build
build.bat configure    :: only run the CMake configure step (no compile)
```

- **Close the game first.** If `dusklight.exe` is running it locks the exe and
  the link fails with `LNK1104`. The script checks and refuses to build.
- Incremental builds only recompile what changed, so iterating on a source file
  is quick.
- The script loads the MSVC dev environment itself, so you can run it from any
  terminal.

## Run

```bat
run.bat                :: launch the RelWithDebInfo build
run.bat debug          :: launch the Debug build
```

It passes `--dvd <your disc image>`. If your disc image path changes, edit the
`DVD` line in `run.bat`.

## Toolchain (already set up — nothing to install)

- **MSVC cl + CMake 3.31.6 + Ninja** from your
  *Visual Studio 2022 Build Tools* install. `build.bat` puts them on `PATH`.
- **Dawn (WebGPU), SDL3, nod** are downloaded as *prebuilt* packages by aurora
  on the first configure — **no Rust, no vcpkg, no Dawn compile**.
- **OpenXR**: the prebuilt Khronos Windows loader lives at
  `C:\Dev\TPVR-deps\openxr-sdk` and is wired in via `OpenXR_DIR`.
- Local build names are defined in `CMakeUserPresets.json` (`win-local-rwdi`,
  `win-local-debug`) so the checkout's upstream `CMakePresets.json` stays clean.

## Source map

- `src/` — the Twilight Princess decompilation (game logic, actors, camera).
- `libs/` — JSystem, dolphin/revolution SDK reimplementations.
- `src/dusk/` — the PC-port shell: settings, UI, audio, mod loader.
- `src/dusk/vr/` — the VR mod (`vr_main.cpp` + `vr_*.hpp`).
- `mods/` — in-tree mods, built into `*.dusk` packages.
- `res/` — fonts, icons, RmlUi styles.

## Settings / config vars

- Declared in `src/dusk/settings.h`, given defaults + registered in
  `src/dusk/settings.cpp`. Values persist to
  `%APPDATA%\TwilitRealm\Dusklight\config.json`.
- Read at runtime with `getSettings().<group>.<name>.getValue()` and written
  with `.setValue(...)`.
- To add a bool setting: add a `ConfigVar<bool>` member to the right struct in
  `settings.h`, add `.name {"group.key", default}` to the `g_userSettings`
  initializer and a matching `Register(g_userSettings.group.name)` call in
  `settings.cpp`. Expose it in the menu in `src/dusk/ui/settings.cpp`.

## Action bindings (controller / keyboard hotkeys)

These are the bindable "actions" (like *First Person Camera*, *Toggle Minimap*).

Checklist to add one:

1. Add the enum value to `ActionBinds` in `src/dusk/action_bindings.h`
   (before `COUNT`).
2. Add `std::array<ActionBindConfigVar, 4> yourName;` to the `actionBindings`
   struct in `settings.h`.
3. In `settings.cpp`, initialise `.yourName { ActionBindConfigVar{"actionBindings.yourName_port0", PAD_NATIVE_BUTTON_INVALID}, ... }`
   for ports 0-3 and add the four `Register(...)` calls.
4. In `action_bindings.cpp`, add
   `{ActionBinds::YOUR_NAME, {&getSettings().actionBindings.yourName, "Display Name"}}`
   to `getActionBinds()`.
5. Consume it with `getActionBindTrig(ActionBinds::YOUR_NAME, port)` (edge) or
   `getActionBindHold(...)`. `updateActionBindings()` runs once per frame (from
   `libs/JSystem/.../JUTGamePad.cpp`), so a plain check where you need the
   effect is enough.

It then shows up automatically in the in-game controller-config UI, where you
press the button/combo to bind it.

## Worked example — "Toggle VR Third Person" (already done)

Makes the existing *VR → Appearance → Third Person* setting bindable to a
button. Files changed:

- `src/dusk/action_bindings.h` — added `TOGGLE_VR_THIRD_PERSON`.
- `src/dusk/settings.h` — added `actionBindings.toggleVrThirdPerson`.
- `src/dusk/settings.cpp` — default keys (`actionBindings.toggleVrThirdPerson_portN`) + `Register`.
- `src/dusk/action_bindings.cpp` — map entry + an edge-trigger at the end of
  `updateActionBindings()` that flips `getSettings().game.vrThirdPerson`.

**To bind it:** open the Dusklight menu (hold **Right Trigger + Start** ~1s) →
controller configuration → **Toggle VR Third Person** → press a button. It
toggles between first- and third-person VR live.

### Hardcoded long-press (no binding UI needed)

Per request, there's also a fixed gesture that needs no controller setup:

- **Hold the left thumbstick click (the VR button mapped to the game's Z
  button) for 2 seconds** to toggle first/third person. It fires once per
  press — release to re-arm.

Implemented in `src/dusk/vr/vr_main.cpp`, right after `leftStickClickHeld` is
read (search for `kViewToggleHoldSec`). Change the `2.0f` there to adjust the
hold time. Note the left stick click also still acts as the game's Z button
while held.

## HUD snaps on snap turn (not on manual look)

By default the HUD/menu billboard low-pass filters head orientation so it
feels steady (`updateHudSmoothing()`, `src/dusk/vr/vr_stereo_render.hpp`). A
snap turn jumped the whole view 45° in one frame, so the panel visibly lagged
behind while it damped across the jump. Fix:

- `src/dusk/vr/vr_smooth_turn.hpp` — new one-frame global
  `dusk::vr::g_instantYawJumpThisFrame`, set by `updateSnapTurn()` (and by
  `snapScriptedCameraYaw()` for cutscene/Z-target camera cuts).
- `src/dusk/vr/vr_stereo_render.hpp` — `updateHudSmoothing()` consumes the
  flag and snaps `g_hudSmoothedWorldForward` straight to the raw direction for
  that frame instead of damping.

Net effect: manual head turns still interpolate as before; an instantaneous
yaw jump (snap turn, scripted camera cut) makes the HUD/menu panel snap with
the world.

**Per-mode damping:** the panel damping factor is now chosen by the caller:

- Third person: `kHudDampingAlpha` (`vr_stereo_render.hpp`, default `0.08f`).
- First person: `kHudDampingAlphaFirstPerson` (default `0.4f`) — snappier, since
  a lagging panel is much more obvious when the camera is your head.
- `updateHudSmoothing(headPose, yawRad, dampingAlpha)` takes the factor as a
  parameter; `vr_main.cpp`'s tick() picks it from `isVrFirstPerson(link)`.

Raise `kHudDampingAlphaFirstPerson` toward 1.0 for even snappier first-person
tracking; lower it for steadier.

## Third person while climbing ladders/walls/vines

In first person, the camera is anchored to Link's body, so it bobbed with every
hand-over-hand climb step. While climbing a ladder/wall/vine the VR view now
falls back to third person automatically and returns to first person the moment
the climb ends.

- `include/d/actor/d_a_alink.h` — new `daAlink_c::checkVrClimbState()`: true for
  the whole climb sequence (the moving procs `checkClimbMove()` covers, plus
  the climb/ladder up-down start/end/wait transitions, hang->climb, and vine
  climb mode).
- `src/dusk/vr/vr_link_visibility.hpp` — `isFirstPerson()` returns false while
  `checkVrClimbState()` is true.

This reuses the same proven third-person fallback as Wolf form/cutscenes: the
VR camera anchors to the flatscreen game camera (`view->lookat.eye`), which
follows behind Link and faces him, with free head-look on top. Returning to
first person is automatic when the climb procs end.

If the game camera angle during a specific climb isn't "a nice spot", that's a
separate (larger) change — the fallback uses the game's own chase camera.

## Carried/grabbed items no longer sit on your face

In VR, an item you pick up (carry or hold to throw) was rendered right in
front of the camera. Cause: `setBodyPartPos()` (`src/d/actor/d_a_alink.cpp`)
overrides Link's hand positions with the real VR controllers, and
`daAlink_c::setGrabItemPos()` (`src/d/actor/d_a_alink_grab.inc`) places the
grabbed/carried actor relative to those hands (a held item averages both),
so it lands at your face — in both first and third person.

Fix, **first person only** (in `setGrabItemPos()`, just before its `return`):
when rendering to the headset in first person, push the item away from Link's
eye along the ground plane and a bit downward. Constants
`kGrabVrAwayUnits` / `kGrabVrDownUnits` (default `25` / `10`; TP is
~35 units/metre, so ~0.7 m away / ~0.3 m down). Raise them if the item is
still too close, lower/zero them if it now floats too far.

**Third person:** the item should be in Link's arms, not at the camera. Both
VR overrides are now gated on `isVrFirstPerson(this)`:

- `setBodyPartPos()` (`d_a_alink.cpp`) only replaces Link's hand positions
  with the tracked controllers in first person. In third person the animated
  hand positions are kept, so a held item is placed in his animated arms.
  (The hand *models* were already only controller-tracked in first person —
  `refreshTrackedHandDrawMtxLive()` is gated the same way — so this just
  matches the item to the visible arms.)
- The push-away offset in `setGrabItemPos()` is skipped in third person so it
  isn't shoved out of his arms.

Because the third-person item is positioned relative to Link's own body, it
stays in his arms even if the third-person camera moves/orbits.

If you'd rather have it rigidly tracked to the right controller (and
optionally scaled down) instead, that's a change in the same function — say
the word.

## HD texture pack (TPDE+ 1.2.0)

Installed (both this build and the original install share the same data folder):

- Location: `%APPDATA%\TwilitRealm\Dusklight\texture_replacements\GZ2\...`
  (5637 files, 8.27 GB of Dolphin-style `.dds`/`.png` textures).
- Dusklight scans `texture_replacements\` **recursively** and matches files by
  the Dolphin `tex1_<W>x<H>_<hash>[_<tlutHash>]_<fmt>.<ext>` name — the `GZ2`
  folder name is irrelevant, and conflicts are resolved by sorted path order
  (the `1..5` folders win over `6 - Alt Textures` / `7 - Water Displacement`).
- Controlled by the `game.enableTextureReplacements` config var (default
  **on**), toggled in the graphics tuner.
- Loaded at startup (`dusk::texture_replacements::reload()`); textures are
  decoded/uploaded on demand by background workers with a ~4 GB cache, so the
  first sighting of each texture can hitch briefly.
- To disable temporarily: set `"game.enableTextureReplacements": false` in
  `config.json`, or move/rename the `texture_replacements` folder.
- To drop the optional water-displacement look, delete
  `...\texture_replacements\GZ2\7 - Water Displacement`.

## Git

This is a normal fork clone (`origin` = `JoeyAW/TPVR`). Use `git status` /
`git diff` to review your edits and commit them to keep your own history. The
upstream `CMakePresets.json` and build scripts are left intact; our local
additions are `CMakeUserPresets.json`, `build.bat`, `run.bat`, `EDITS.md`.

## Gotchas

- Editing `settings.h` triggers a broad recompile (it's included widely) —
  still only a minute or two.
- If a build fails on a nonsensical syntax error in a file nobody touched, check
  for stray keystrokes (the upstream notes mention VS stealing focus).
- VR renders on the HMD; the desktop window mirrors one eye when enabled.
