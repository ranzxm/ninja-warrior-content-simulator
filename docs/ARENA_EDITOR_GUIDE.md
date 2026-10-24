# Arena Editor Guide — M1b stabilization

The editor runs inside the game executable. Minimum window: 1280×720.

## Build a course

1. Press F2 or use **Edit Arena**. An active run requires stop confirmation.
2. Click **New**. Unsaved changes require discard confirmation.
3. Click a palette obstacle. This starts **PLACE**; it creates nothing yet. Move over the viewport, click once to place. The new obstacle is selected; tool returns to SELECT. Escape cancels without creating anything. Red ghost means invalid placement or object limit reached.
4. Select objects with left-click or the Course Route list. Empty space clears selection. F focuses selection.
5. Choose **MOVE**, drag in the viewport on XZ. Choose **ROTATE**, drag horizontally to rotate Y. Release commits one undo step; Escape restores the start. Shift+drag also moves in SELECT. Snap uses the displayed grid and 15-degree rotation increments.
6. Inspector **Transform** labels X/Y/Z and Y rotation individually. Enter numeric values, then **Apply Transform**. Y sets height. Reset position/rotation are separate actions. Root scaling is not supported; use validated dimensions.
7. Expand **Parameters**. Type a value and press Enter or leave the field. Spinner changes apply after release/brief inactivity. Changes retain focus and selection; invalid configurations preserve the previous geometry. Reset parameters restores type defaults. Duplicate/Delete are below parameters or available through shortcuts.
8. Select **Spawn** or **Finish** in the sidebar for their own inspector. Edit position/rotation and Finish dimensions; click its **Apply** button. Infrastructure cannot be deleted.
9. Reorder Course Route using Up/Down. New/duplicate obstacles append; deletion removes their route reference. Disabled obstacles remain visible/selectable in EDIT but have no gameplay collision. Disabled route entries block Test Play until re-enabled or route configuration changed.
10. **Validate** opens errors/warnings. Warnings are heuristics, not proof that a course is completable.

## Save and test

- Top bar: arena name, New, Open, Save, Test Play, Settings. Name applies on Enter/focus exit.
- Settings: arena ID, time limit and theme; **Set Meta** commits. Themes are metadata, not new visual theme assets.
- Open: saved file list plus **Save As** ID/name fields. IDs use letters, numbers, underscore/hyphen, up to 64 characters. No paths.
- Save: `user://arenas/<arena_id>.json`. Backup: `.json.bak`; verified temporary file: `.json.tmp`. Failures leave the dirty indicator and show an error. Windows replacement is not guaranteed power-loss atomic; preserve `.bak` for recovery.
- **Test Play / F2** validates, resets physics/timer/player and starts READY using the same arena. F2 returns to EDIT; unsaved changes persist.
- Undo/Redo retain 25 completed actions. Returning to saved content clears the dirty indicator. Save/load/reset do not require the Godot Editor.

## Controls

| Input | Action |
|---|---|
| F2 | EDIT / Test Play |
| Left-click | Select / place once |
| MOVE + drag; Shift+drag | XZ move, release commits |
| ROTATE + drag; Q/E | Y rotation; Q/E changes 15 degrees |
| Right-drag | Orbit |
| Middle-drag / Shift+right-drag | Pan |
| Wheel | Zoom, 3–120 m |
| F | Focus selected object; otherwise Spawn |
| Camera Reset / Frame All / Spawn | Reset view / frame course / focus start |
| Ctrl+D / Delete | Duplicate / delete obstacle, ignored while typing |
| Ctrl+S | Save including pending parameter edit |
| Ctrl+Z / Ctrl+Y | Undo / redo, ignored while typing |
| Escape | Cancel placement/drag, close file panel, leave text input |
| Help | Show controls |

Bottom status shows mode/tool, selected ID, snapping and saved/unsaved state. Hover truncated status text to read the complete message. Inspector scrolls vertically; no horizontal input rows. Placement height follows `placement_height` (default 0); place at ground then change Position Y in the inspector.

## Verification limits

Automated connected-control and rendered stress checks pass. Full human rapid-edit, restart round-trip and custom-course traversal acceptance remains pending. See `M1B_EDITOR_STABILITY_REPORT.md` for exact evidence, diagnostics and limitations.
