# Grapple Ghosts

**Swing through a floating city and race your ghosts.**

A 3D grapple-hook time-trial game for Android, built with Godot 4.7.
This repository is the initial movement prototype, now playable on the phone.

![Touch prototype](docs/prototype.png)

## Prototype controls

| Action | Desktop | Phone |
|---|---|---|
| Move | WASD | Left stick |
| Look | Mouse | Drag on the right side |
| Sprint | Shift | Push the stick to the edge |
| Jump | Space | JUMP |
| Grapple | Hold right mouse | Hold GRAPPLE |
| Release the mouse | Esc | — |

The cyan blocks and the tower are grappleable. Swing around, climb the tower,
then try to cross the gaps without touching the ground.

## Run

```bash
godot --path .
```

## Android build

```bash
godot --headless --path . --export-debug "Android" build/grapple-ghosts.apk
adb install -r build/grapple-ghosts.apk
```

The Android preset targets `arm64-v8a` and uses the package
`com.soda.grappleghosts`.

## Roadmap

1. **Swing feel** — rope tension, reel-in, release boost, coyote time.
2. **Course** — one island district with a 60–90 second route, rings and gaps.
3. **Ghosts** — record the player's transform and replay the best run as a ghost.
4. **Timer + medals** — bronze / silver / gold; personal best.
5. ~~**Touch controls**~~ — left stick, drag look, hold GRAPPLE, JUMP; tested on the phone.
6. **Characters** — anime skins from Blender, third-person optional.
7. **Content** — three routes, shortcuts, secrets, weather/time of day.

## Design rules

- The fun must be in the **movement**, not in unlocks or story.
- No combat, inventory or open world until the swing loop is genuinely fun.
- Every course should be readable at speed and support at least two lines.
- Keep runs short enough for a phone session.

## Status

Bootstrap / movement prototype with working mobile controls. Not a finished game.
