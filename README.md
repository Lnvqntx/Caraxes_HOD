# Caraxes

Caraxes is a native Swift and AppKit desktop pet for macOS 26 or later. Milestone 1 shows a placeholder red dragon that bobs near the lower-right corner of the screen. Use **Caraxes → Quit Caraxes** in the menu bar to exit.

## Build and run

Open `Caraxes.xcodeproj` in Xcode 26 or later, select the **Caraxes** scheme and **My Mac**, then press **⌘R**. The project uses local ad hoc signing.

```sh
xcodebuild -project Caraxes.xcodeproj -scheme Caraxes -configuration Debug build
```

## Implementation

- `PetWindow` owns the transparent, borderless overlay and configures it to float across Spaces, including full-screen Spaces. It uses the current sprite position and image alpha to let clicks through the transparent area.
- `PetStateMachine` starts in `idle` and defines `sleep`, `fly`, `perch`, and `fire` for future behavior.
- `SpriteAnimator` runs the idle bob in Core Animation. The app samples a stationary pointer at 60 Hz only while it is within the area swept by the bob. Sleeping stops the animation and invalidates the pointer timer.
- `WindowTracker` is an empty stub for a later milestone.

## Review on macOS

1. Run the app and confirm that the red dragon bobs, the menu bar shows **Caraxes**, and the Dock has no Caraxes icon.
2. Put another app behind the sprite. Click through a transparent gap, then click on the visible dragon. Repeat with the pointer held still at the bobbing edge to check that clicks follow the sprite.
3. Switch Spaces and enter a full-screen Space. Check that the sprite stays visible and the window behind it keeps keyboard focus.
4. Leave the pointer away from the sprite and observe Caraxes in Activity Monitor. Use the menu bar’s **Quit Caraxes** item and confirm that the sprite and menu item disappear.
