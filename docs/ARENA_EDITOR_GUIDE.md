# ARENA EDITOR GUIDE — Ninja Warrior Content Simulator (M1b)

## 1. Overview
The in-game Arena Editor runs directly inside the application (`PLAY` ↔ `EDIT` mode) without requiring the Godot Editor. It allows creating, customizing, validating, saving, loading, and test-playing 3D obstacle courses at `1280×720` or higher.

## 2. Switching Between PLAY and EDIT Modes
- Press **`F2`** or click **`Edit Arena (F2)`** on the Gameplay HUD to enter `EDIT` mode.
- If a competition run is currently `RUNNING`, a confirmation dialog asks before stopping the run.
- In `EDIT` mode, click **`Test Play (F2)`** or press **`F2`** to validate the arena and launch `PLAY` mode from the edited `SpawnPoint`.
- Returning from `Test Play` to `EDIT` mode preserves all placed obstacles, route ordering, and unsaved modification flags.

## 3. Editor Camera & Viewport Controls

| Input | Action |
|---|---|
| `Right Mouse Drag` | Orbit camera around focus point |
| `Middle Mouse Drag` / `Shift + Right Drag` | Pan camera horizontally and vertically |
| `Mouse Wheel Up / Down` | Zoom in / out (`3.0m` to `120.0m`) |
| `F` | Focus camera on selected obstacle (or `SpawnPoint` if none selected) |
| `Left Click` (3D Viewport) | Select obstacle under cursor (or place obstacle when in placement mode) |
| `Shift + Left Drag` | Move selected obstacle across the horizontal XZ plane |
| `Q / E` | Rotate selected obstacle `-15°` / `+15°` around Y axis |
| `Ctrl + D` | Duplicate selected obstacle with a new unique `instance_id` |
| `Delete` | Delete selected obstacle and remove its route entry |
| `Ctrl + S` | Save current arena to `user://arenas/<arena_id>.json` |
| `Ctrl + Z / Ctrl + Y` | Undo / Redo (up to 25 snapshots) |
| `Esc` | Cancel active placement mode or close file dialog |
| `F2` | Toggle `EDIT` / `PLAY` mode |

## 4. Building & Editing an Arena
1. **New Arena:** Click **`New`** on the top toolbar to start a blank course with `SpawnPoint` and `FinishZone`.
2. **Obstacle Palette (Left Dock):** Click any of the 6 obstacle types (`Stepping Pads`, `Balance Beam`, `Moving Platform`, `Rotating Sweeper`, `Swinging Pendulum`, `Warped Wall`) to place an instance and enter placement mode. Move the mouse in the 3D viewport to position the ghost preview and left-click to place additional instances, or press `Esc` to exit placement mode.
3. **Inspector (Right Dock):**
   - Edit `Position (X, Y, Z)` and `Rotation Y` numerically, or click `Rst Pos` / `Rst Rot`.
   - Toggle `Obstacle Enabled` (`is_enabled`).
   - Adjust obstacle-specific parameters (`pad_count`, `beam_length`, `movement_speed`, `travel_mode`, `rotation_speed`, `swing_amplitude_deg`, `wall_height`, etc.). Invalid values are rejected atomically without corrupting geometry.
   - Note: Arbitrary root node scaling is locked to `(1, 1, 1)` so physics colliders remain exact; all dimensions are controlled through validated obstacle parameters.
4. **Spawn & Finish Editor (Right Dock):** Adjust `SpawnPoint` (`X, Y, Z, Rot Y`) and `FinishZone` (`X, Y, Z, Rot Y, Size X/Y/Z`), then click **`Apply Spawn & Finish`**.
5. **Ordered Route Panel (Left Dock):** View the required completion sequence (`1. ob_000001`, `2. ob_000002`, ...) and reorder obstacles using **`Move Up`** / **`Move Down`**.
6. **Validate & Save:** Click **`Validate`** to inspect errors and warnings. Click **`Save (Ctrl+S)`** or **`Open / Save As`** to persist to `user://arenas/`.
