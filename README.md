# Caraxes

Caraxes is a native Swift and AppKit desktop pet for macOS 12.0 or later. It perches on the active window when one is available and takes short flights around the primary display on an empty desktop. Use **Caraxes → Quit Caraxes** in the menu bar to exit.

## Build and run

With the Apple Command Line Tools and Swift 5.7.2 or later, run this from the repository root:

```sh
./scripts/build_app.sh && open Caraxes.app
```

The script builds a native release executable, assembles and ad-hoc signs `Caraxes.app`, and prints its path. The build has no package dependencies and uses the host architecture, so an Intel Mac builds an x86_64 app. SwiftPM keeps build intermediates in `.build/`.

### Xcode

Open `Caraxes.xcodeproj` in Xcode, select the **Caraxes** scheme and **My Mac**, then press **⌘R**. The project uses local ad hoc signing.

```sh
xcodebuild -project Caraxes.xcodeproj -scheme Caraxes -configuration Debug build
```

## Install private sprites

Place the files in `~/Library/Application Support/CaraxesHOD/sprites/` before launching Caraxes.

```sh
mkdir -p "$HOME/Library/Application Support/CaraxesHOD/sprites"
```

| PNG file | Role |
| --- | --- |
| `sleep_rest.png` | Sleeping |
| `fly_side.png` | Level flight |
| `fly_diag_b.png` | Alternating flight pose |
| `fly_vertical.png` | Recognized by the loader, reserved for a later animation |
| `roar_front.png` | Idle and fire |
| `head_roar.png` | Recognized by the loader, reserved for a later animation |

Use PNGs with transparent backgrounds for sprite-shaped mouse interaction. Relaunch after adding or replacing files. Caraxes uses the bundled placeholder independently for any missing or unreadable pose. Sprites preserve their aspect ratio and render up to 220 points wide.

## Behavior

- With an eligible foreground window, Caraxes flies to its top edge or sits just inside the top-right corner when space above is limited. It follows the window, alternates between 5–15 seconds of idle and 30–120 seconds of sleep, and takes a short flight to a different foreground window.
- With no eligible window or a full-screen window, Caraxes bobs for 5–15 seconds, flies to a random position on the primary display in about 2.4 seconds, then sleeps for 30–120 seconds.
- During a flight, the poses alternate about every 0.4 seconds. The animator assumes the side pose faces right and the diagonal pose faces left, and mirrors them to match travel. The body tilts slightly along the direction of travel.
- A click on the visible sleeping sprite wakes it. A click during idle or flight triggers a 1.5-second flame effect and returns Caraxes to idle. Transparent pixels pass clicks through to the app underneath.
- Core Animation handles the sleeping breath and Zzz effects. Sleep uses a wake-up timer and, when perched, a geometry check around once a second. Awake perched tracking checks around four times a second.

AppKit owns the overlay in `PetWindow`. `PetStateMachine` schedules rest and activity, `SpriteAnimator` loads and animates poses, and `WindowTracker` estimates the main window from front-to-back, on-screen layer-zero bounds for the frontmost app. Full-screen detection compares the window bounds to display bounds. Tracking uses window identity and geometry, with no window titles or Screen Recording permission.

## Review on macOS

1. Launch without private PNGs and check that the placeholder works for each state. Then install the private PNGs and relaunch. Remove one file and relaunch to check the per-pose fallback.
2. Observe one full cycle. Confirm the flight remains on the primary display, the pose flips in both directions, and Caraxes stops moving when it lands.
3. Click through a transparent gap, click to wake the sleeping pet, and click again to trigger fire. Check the flame origin against the actual `roar_front` artwork. Its default anchor is 50% across and 58% up from the image's lower-left corner.
4. Check sleeping CPU in Activity Monitor. Confirm the overlay stays visible when switching Spaces and **Quit Caraxes** removes both the pet and menu item.
5. Activate a window at least 300 points wide. Drag it and switch between two windows of the same app. Check that Caraxes follows while idle and asleep and flies to the newly active window.
6. Move a window to the top of a display, then to displays positioned to the left of and above the primary display. Check top-edge and inside-corner placement.
7. Minimize the active window, enter and leave full screen, and switch Spaces. When no window qualifies, check that desktop roaming resumes.
