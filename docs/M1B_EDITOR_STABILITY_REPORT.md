# M1b — Editor Crash Fix & UX Stabilization

Date: 2026-10-24. Baseline: `c7d15639c221b509cd187bf0a270914cf488169e`.
Branch: `fix/m1b-editor-ux-stability`. Status: **PARTIAL** — automated safeguards pass; complete human acceptance remains pending.

## Crash investigation

Operator symptom: application force-closes while changing Stepping Pads dimensions; other dimension fields potentially affected.

Baseline reproduction used the actual connected Pad Width SpinBox, focus acquisition, and `spin.value = 2.5`, after selecting demo Stepping Pads in EDIT. Godot **4.7.2.stable.official.ed1daf0bf**, `--headless --debug`:

```text
BASELINE_REPRO: pad_dimensions.x 1.8 to 2.5
ERROR: Object '<Object#50398759138>' was freed or unreferenced while a signal is being emitted from it.
Try connecting to the signal using 'CONNECT_DEFERRED' flag, or use queue_free() ...
... avoid this error and potential crashes.
at: ~Object (core/object/object.cpp:2324)
_refresh_inspector_ui (arena_editor.gd:956)
update_selected_parameters (arena_editor.gd:462)
update_selected_parameter (arena_editor.gd:444)
_on_param_vec3_axis_changed (arena_editor.gd:1141)
BASELINE_REPRO: sender_survived=false
EXIT=0
```

**Confirmed defect:** synchronous destruction of the emitting Control. **Not confirmed:** a native process crash or the exclusive cause of the operator's termination. This reproduction exited normally despite an engine error. No native crash stack/minidump was obtained. The exact original human force-close remains unreproduced. Geometry teardown was a separate source-inspected risk, not a proven native crash cause.

Baseline log: `%LOCALAPPDATA%/Temp/opencode/m1b-baseline-repro.log` on this machine. The final regression test replaces the unsafe baseline probe; it asserts survival instead of merely logging it.

## Fixes / source responsibilities

| Files | Change |
|---|---|
| `scripts/editor/ui/parameter_inspector.gd` | Stable descriptor-driven controls; staged edits, Enter/focus-exit commit; 300ms spinner coalescing, wait for mouse release; no recursive value signals; focus/caret preserved. |
| `scripts/editor/ui/editor_layout.gd`, `scenes/editor/arena_editor_ui.tscn` | Composed native toolbar/docks/collapsible sections, labeled rows, Settings/Help windows, separate marker inspector. |
| `scripts/editor/arena_editor.gd` | Coordinator retains public API; one-action drag snapshots, tools, single-shot placement, wire selection, save-point dirty tracking, pending-edit flush at selection/save/duplicate/delete/mode/history boundaries. |
| `scripts/obstacles/obstacle_base.gd` | No-op parameter detection, rollback, local resources, cached mesh-inclusive bounds, geometry revision/signal, explicit deferred physics-callback request API. |
| `scripts/obstacles/obs_01_stepping_pads.gd` … `obs_06_warped_wall.gd` | Reuse pad/slab bodies and mesh/shape resources; resize paired geometry together; retire excess pads without immediate destruction. |
| `scripts/arena/obstacle_factory.gd` | Per-axis pad/platform descriptor limits match runtime validators. |
| `scripts/arena/arena_repository.gd` | Exact-byte temporary verification, checked backup/replacement errors; no direct truncating final write. |
| `tests/smoke_test_m1b_editor_stability.gd` | Connected controls, real viewport key/mouse events, six-type geometry stress, history, persistence, modes, layout. |
| `tests/geometry_safeguards_check.gd` | No-op/rollback/resource identity, peer isolation, bounds, pad retirement, deferred request copy. |
| `tests/arena_repository_preservation_check.gd` | Exact bytes, backup failure, read-only replacement failure, temporary-open failure; isolated temp directory. |

### Inspector transaction lifecycle

`value_changed` only stages values. Enter/focus exit schedules commit after the event stack. Spinner batches commit after 300ms inactivity and mouse release. Pending edits flush before selection and persistence boundaries. The same schema keeps the same nodes; changing schema detaches old controls and queues deletion. Accepted values synchronize without emitting new changes or rewriting matching focused text. Rejections restore valid values and leave undo unchanged.

Numeric transforms use **Apply Transform**, one snapshot for the whole XYZ/Y configuration. Drag preview updates transforms only; release serializes once. Escape restores drag origin without a history entry. History retains 25 complete snapshots, recovers selection by ID after reconstruction, compares against the saved document for clean/dirty state.

### Geometry safety

GUI commits occur outside signal/query-flush callbacks. `apply_parameters()` remains synchronous for existing safe callers and tests; physics-trigger callbacks must use `request_apply_parameters()` (copied data, deferred invocation). Simulation stops before changed geometry is installed. Validators reject before rebuilding. Existing fixed-shape bodies/resources resize in place; generated wall slabs persist; excess pads lose collisions, detach, then queue deletion. Anchors, triggers, picking bounds, enabled/editor flags update together. Unchanged configurations do not reset traversal or rebuild.

This is not a promise that arbitrary external callers can mutate physics inside query-flush callbacks. Use the deferred API. Cached bounds cover reset/editor geometry, not swept movement over an entire simulation cycle. Editor pick bodies persist disabled after leaving EDIT, avoiding destruction during transitions; no active pick collision during PLAY.

### Save safety ceiling

Backup creation failure blocks overwrite. Verified temporary bytes replace the target via `DirAccess.rename_absolute`; errors preserve/restore the previous target where possible and retain diagnostic errors. **Windows Godot rename is not guaranteed power-loss atomic**: native engine replacement can have a delete/move gap. `.bak` remains the recovery path; do not claim interruption-proof atomic persistence.

## UX before / after

- Crowded top bar becomes name + New/Open/Save/Test Play/Settings; metadata moves into Settings.
- Unlabeled horizontal numeric groups become single labeled rows, vertical scrolling only.
- Spawn/Finish have their own inspector states, selected with dedicated sidebar buttons.
- Palette now starts PLACE without creating anything. One viewport click places one obstacle, selects it, returns to SELECT. Escape cancels. Ghost uses type-specific bounds with red invalid feedback.
- Filled selection volume becomes line edges, without collision or obstruction.
- SELECT/MOVE/ROTATE tools visible below viewport. MOVE drags XZ; ROTATE drags Y, optional 15-degree snap. Inspector controls Y height. Camera Reset/Frame All/Spawn supplement orbit/pan/zoom/F.
- Help, status tooltip, dirty state and validation report remain accessible. All six palette items visible at 720p; inspector may scroll vertically.

## Automated evidence

Executed with the exact Windows Godot 4.7.2 binary, Compatibility renderer. No existing tests weakened or removed.

| Command suffix | Result |
|---|---|
| `--headless --editor --path . --quit` | PASS, exit 0 |
| `--headless --path . -s res://tests/smoke_test_m0.gd` | PASS, exit 0 |
| `--headless --path . -s res://tests/smoke_test_m1a.gd` | PASS, exit 0 |
| `--headless --path . -s res://tests/smoke_test_m1a_stabilization.gd` | PASS, 200 checks, exit 0 |
| `--headless --path . -s res://tests/smoke_test_m1b.gd` | PASS, 156 checks, exit 0 |
| `--headless --path . -s res://tests/geometry_safeguards_check.gd` | PASS, exit 0 |
| `--headless --path . -s res://tests/arena_repository_preservation_check.gd` | PASS, exit 0 |
| `--headless --debug --path . -s res://tests/smoke_test_m1b_editor_stability.gd` | PASS, 1,798 checks, 244 parameter operations, exit 0 |
| `--debug --path . -s res://tests/smoke_test_m1b_editor_stability.gd` | PASS, same 1,798 checks/244 operations, exit 0; rendered OpenGL 3.3 Intel UHD 620 |

The stability suite includes actual connected SpinBox signals, keyboard Enter, real viewport spinner-arrow mouse input, pending selection switch, enable/disable, 20 duplicates, deletes, repeated undo/redo, drag transactions, save-point history, save/load, post-load edits, PLAY/EDIT, palette cancellation/placement. Fixed-schema stress alternates all axes/min/max where vector parameters exist, 36 operations per type plus 24 generated pad-count changes. Mesh/collider pairs and anchors are checked throughout. Deliberate invalid-parameter tests emit expected diagnostic warnings; debug builds also report pre-existing unused-signal/integer-division warnings, not runtime errors. The isolated repository fault-injection suite deliberately creates a directory at the backup filename: Godot reports `Failed to open ... preservation.json.bak` from `DirAccess.copy`; the expected error return and unchanged target bytes are asserted. This injected filesystem error is not an editor interaction error.

Rendered screenshots: `user://editor_stability_1280x720.png`, `user://editor_stability_1600x900.png`, `user://editor_stability_1920x1080.png`. Bounds checks pass at all sizes; screenshots inspected at 720p and 1080p. Rendered scripted input is **automated GUI-event-path testing**, not a completed human acceptance playthrough.

## Interactive acceptance

| Requested scenario | Status |
|---|---|
| 1 — Human rapid resizing through all six obstacles | NOT RUN completely; automated connected-control equivalent PASS |
| 2 — Human end-to-end creation/usability | NOT RUN completely; automated workflow PASS |
| 3 — Human save, close, relaunch, load | NOT RUN; same-process disk round-trip PASS |
| 4 — Human traversal/retry/return/edit | NOT RUN; mode integration and existing physics regressions PASS |
| 5 — Human resolution interaction at all sizes | NOT RUN; rendered screenshots/layout checks PASS |

Native desktop launch succeeded. OS-level input automation was attempted but did not reliably establish intended editor interactions; no manual acceptance PASS is inferred from it. No new native termination observed in executed scripted tests.

## Resource observations

Rendered fixed-schema resize batches: scene node counts unchanged per type (501, 480, 521, 505, 490, 480 respectively); resource count **56 before/after each batch**. Objects steady after first lazy initialization. Godot static memory approximately **48.0–48.6 MB** in these batches; first pads batch increased ~0.29 MB, subsequent batches changed by kilobytes. Final scene with duplicated objects: 996 nodes, 96 resources, ~52.1 MB Godot static allocation. These are Godot counters, not Windows working-set/VRAM measurements. Snapshots intentionally retain up to 25 arena configurations.

No unbounded growth observed in this bounded test. FPS, 1% low, physics CPU time, long-duration leak behavior and target-hardware benchmark: **NOT MEASURED**. Rendering on UHD 620 is not a 30/60 FPS certification.

## Reproducible developer procedure

```powershell
$godot = 'C:\Users\xyzkl\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe'
& $godot --debug --path . --log-file "$env:LOCALAPPDATA\Temp\opencode\editor-debug.log" -- --editor-diagnostics
```

Enter EDIT, select Pads in Course Route, scroll to Pad Size. Type Width/Height/Length and press Enter, use arrows, change selection, duplicate, undo/redo, save/load, test play. Diagnostics identify instance/type, attempted parameter dictionary (including keys), validation and rebuild start/completion/revision. Invalid edits log failures without flooding physics frames or mouse motion. If force-close occurs, retain log and Windows Application Error event/minidump, record last input/value and exact exit code. Never infer crash absence from exit 0 alone.

## Definition of Done / remaining limits

| Criterion | Result |
|---|---|
| Crash reproduced/fixed or unreproduced native status clearly documented | PASS: lifecycle engine error reproduced and removed; original native force-close unconfirmed |
| Controls survive events, do not destroy emitter | PASS automated |
| Safe repeated geometry changes across six types | PASS automated, safe-callback contract above |
| Mesh/collider/anchors/pick synchronized | PASS automated |
| Readable 720p labeled inputs; no horizontal inspector overflow | PASS automated bounds + screenshot review |
| Predictable single-shot palette and unobstructive selection | PASS automated/rendered |
| One drag / committed parameter transaction = one undo | PASS automated |
| Save/load and EDIT/PLAY preserved | PASS automated |
| Existing regressions and new stress suites | PASS |
| Complete manual GUI acceptance, restart round-trip and traversal | PENDING / NOT RUN |

No known new reproducible crash after safeguards. Human confirmation of the original failure path remains a release gate; M1b is not declared DONE. Native Windows atomic replacement limitation remains documented. No M2a functionality added; next action is human M1b acceptance, then M2a only after acceptance.
