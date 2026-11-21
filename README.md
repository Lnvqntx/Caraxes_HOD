# Caraxes

Caraxes is a native Swift and AppKit desktop pet for macOS 26 or later. It spends most of its time resting and takes short flights around the primary display. Use **Caraxes → Quit Caraxes** in the menu bar to exit.

## Build and run

Open `Caraxes.xcodeproj` in Xcode 26 or later, select the **Caraxes** scheme and **My Mac**, then press **⌘R**. The project uses local ad hoc signing.

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

- Caraxes bobs for 5–15 seconds, flies to a random position on the primary display in about 2.4 seconds, then sleeps for 30–120 seconds.
- During a flight, the poses alternate about every 0.4 seconds. The animator assumes the side pose faces right and the diagonal pose faces left, and mirrors them to match travel. The body tilts slightly along the direction of travel.
- A click on the visible sleeping sprite wakes it. A click during idle or flight triggers a 1.5-second flame effect and returns Caraxes to idle. Transparent pixels pass clicks through to the app underneath.
- Core Animation handles the sleeping breath and Zzz effects. The wake-up timer is the only app timer active during sleep.

AppKit owns the overlay in `PetWindow`. `PetStateMachine` schedules rest and activity, `SpriteAnimator` loads and animates poses, and `WindowTracker` remains a stub.

## Review on macOS

1. Launch without private PNGs and check that the placeholder works for each state. Then install the private PNGs and relaunch. Remove one file and relaunch to check the per-pose fallback.
2. Observe one full cycle. Confirm the flight remains on the primary display, the pose flips in both directions, and Caraxes stops moving when it lands.
3. Click through a transparent gap, click to wake the sleeping pet, and click again to trigger fire. Check the flame origin against the actual `roar_front` artwork. Its default anchor is 50% across and 58% up from the image's lower-left corner.
4. Check sleeping CPU in Activity Monitor. Confirm the overlay stays visible when switching Spaces and **Quit Caraxes** removes both the pet and menu item.
