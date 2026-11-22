# Caraxes

Caraxes is a Chrome extension that puts a small dragon on your browser tabs. It rests between short flights. Click the sprite to wake it or make it breathe fire.

## Install in Chrome

1. Open `chrome://extensions` and turn on **Developer mode**.
2. Click **Load unpacked** and choose this repository’s `extension/` folder.
3. Reload an existing HTTP or HTTPS tab, or open a new tab. Pin **Caraxes** from Chrome’s Extensions menu to reach the settings popup.

The popup saves the on/off setting, sprite width, and disabled domains. A disabled domain also covers its subdomains. Chrome restricts extensions on internal pages and some protected sites. Caraxes supplies its own new tab page, where the search box submits to Google.

## Optional sprites

Place your PNGs in `extension/sprites/` and reload the extension and open tabs. The folder is ignored by Git. Missing PNGs use an inline red dragon.

| File | Pose |
| --- | --- |
| `sleep_rest.png` | Sleep |
| `fly_side.png` | Level flight, assumed to face right |
| `fly_diag_b.png` | Diagonal flight, assumed to face left |
| `fly_vertical.png` | Available for future poses |
| `roar_front.png` | Idle and fire |
| `head_roar.png` | Available for future poses |

## Behavior

Caraxes rests near the right edge of the viewport, above the Google logo on the Google homepage, or above the search box on its new tab page. Each short flight returns to that perch. Sleep uses CSS effects and a single wake-up timer. Click, resize, visibility, and storage handlers respond to their events. Background tabs pause the timer and animations until visible again.
