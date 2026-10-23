# M1A STABILIZATION REPORT — Gameplay Integrity & Regression Hardening

> **Milestone:** M1a Stabilization  
> **Baseline Commit:** `4da865dda574352ea66ef6f00a0901475b5f5f29`  
> **Engine:** Godot 4.7.2.stable.official.ed1daf0bf (`gl_compatibility`)  
> **Date:** 24 October 2026

---

## 1. Audit Findings & Root Causes

| ID | Defect / Gap Found in Baseline (`4da865d`) | Root Cause |
|---|---|---|
| **F-01** | Setting `ObstacleBase.is_enabled = false` hid meshes and stopped `_physics_process`, but left colliders and `Area3D` triggers active in the physics space. | `_apply_enabled_state()` only changed `visible` and `process_mode` without zeroing `CollisionObject3D` layers/masks, disabling `CollisionShape3D`, or disabling `Area3D.monitoring`. |
| **F-02** | Obstacle progress incremented on `EntryTrigger` (`obstacle_entered`) instead of requiring full obstacle traversal (`NOT_STARTED → ENTERED → COMPLETED`). | Obstacles lacked `ExitTrigger` (`Area3D`) nodes and `RunSession` did not distinguish between entering an obstacle (`IN PROGRESS`) and clearing it (`CLEARED`). |
| **F-03** | `FinishZone` allowed transitioning to `FINISHED` whenever `RunSession.state == RUNNING`, without verifying that all 6 required obstacles were completed in order. | `RunSession` lacked an ordered route contract (`required_obstacle_ids`) and `can_finish_run()` guard. |
| **F-04** | Incomplete parameter round-trip and non-atomic `apply_parameters()` across obstacles (`platform_size` missing in `OBS-03` setter; `push_strength` missing in `OBS-04`; `knockback_speed` missing in `OBS-05`; unknown keys ignored; invalid string/NaN inputs coerced instead of rejected). | `_apply_obstacle_parameters()` mutated fields directly using permissive `float()`/`int()` casts and did not validate key whitelists or types before assignment. |
| **F-05** | Dynamic obstacles (`MovingPlatform`, `RotatingSweeper`, `SwingingPendulum`) animated continuously even in `READY` and terminal states (`FINISHED`/`FAILED`/`TIMEOUT`), and `MovingPlatform` `LOOP` wrap did not sync `PhysicsServer3D` transform state. | Obstacles lacked an explicit `start_simulation()` / `stop_simulation()` lifecycle tied to `RunSession` state transitions. |
| **F-06** | `MainApp` allowed obstacle entry triggers to implicitly start a run from `READY` and converted falls during `READY` into `RUNNING → FAILED` attempts. | `_on_stage_obstacle_entered()` and `_handle_player_fall()` called `run_session.start_run()` when in `READY`. |

---

## 2. Implemented Fixes & Technical Decisions

1. **Recursive Collision Activation (`ObstacleBase._sync_collision_tree`):**
   - Stores original `collision_layer` and `collision_mask` on every descendant `StaticBody3D`, `AnimatableBody3D`, and `Area3D` via metadata (`_orig_collision_layer`, `_orig_collision_mask`), plus `_orig_monitoring` / `_orig_monitorable` on `Area3D`.
   - Setting `is_enabled = false` hides visuals, stops simulation (`simulation_active = false`), zeroes `collision_layer` and `collision_mask` (both immediately and via `set_deferred`), sets `CollisionShape3D.disabled = true` (immediate + deferred), and disables `Area3D.monitoring` / `monitorable`.
   - Setting `is_enabled = true` restores original layers, masks, shapes, and area monitoring across repeated cycles and geometry rebuilds.

2. **Explicit Traversal States & `ExitTrigger` Volumes:**
   - Added `ObstacleBase.TraversalState` (`NOT_STARTED`, `ENTERED`, `COMPLETED`) and added `ExitTrigger` (`Area3D`) to all 6 obstacle scenes (`obs_01` through `obs_06`).
   - `RunSession` tracks `current_obstacle_id`, `current_obstacle_name`, `current_obstacle_status` (`READY` / `IN PROGRESS` / `CLEARED`), `last_entered_obstacle_id`, `last_completed_obstacle_id`, and `completed_obstacle_ids`.
   - `record_obstacle_entered()` marks the expected next obstacle `ENTERED` (`IN PROGRESS`) without incrementing `completed_obstacle_ids`.
   - `record_obstacle_completed()` requires the obstacle to be in `ENTERED` state, marks it `COMPLETED` (`CLEARED`), and increments `completed_obstacle_ids` once.

3. **Sequential Course Route Validation & Anti-Skip (`RunSession`):**
   - `RunSession.configure_route(obstacle_ids, enabled_map)` registers the ordered list of required obstacle instance IDs from `StageDemoArena`.
   - Out-of-order entries/completions, duplicate exits, and early `FinishZone` overlaps are rejected.
   - `can_finish_run()` requires `state == RUNNING` and every required obstacle instance in `required_obstacle_ids` to be enabled and `COMPLETED`.

4. **Atomic Parameter Contract & JSON Round-Trip (`ObstacleBase` + `OBS-01..06`):**
   - Added strict static validators (`_has_only_known_keys`, `_read_strict_float`, `_read_strict_int`, `_read_strict_string`, `_read_strict_vec3`) that reject unknown keys, invalid types (`String`, `bool`, non-integer floats for `int` fields), `NaN`/`INF`, and out-of-range values before mutating any state.
   - Added full round-trip support for `platform_size` (`OBS-03`), `push_strength` (`OBS-04`), and `knockback_speed` (`OBS-05`), and updated `_rebuild_obstacle()` in all 6 obstacles to reposition `EntryAnchor`, `ExitAnchor`, `EntryTrigger`, `ExitTrigger`, and `HazardZone`.

5. **Dynamic Obstacle Simulation Lifecycle & StartGate Integrity:**
   - Added `start_simulation()` and `stop_simulation()` on `ObstacleBase` and `StageDemoArena`.
   - Dynamic obstacles remain stationary at their initial phase in `READY`, animate in `RUNNING`, freeze at current phase in `PAUSED`, freeze at final phase in `FINISHED`/`FAILED`/`TIMEOUT`, and reset to initial phase on `RETRY`.
   - `MovingPlatform` synchronizes `PhysicsServer3D.body_set_state(..., BODY_STATE_TRANSFORM, ...)` on reset and `LOOP` wraparound to prevent discontinuous velocity impulses.
   - Only `StartGate` starts a run in `Stage01Demo`; falling while in `READY` safely respawns the player to `SpawnPoint` in `READY` state.

---

## 3. Verification Commands & Actual Results

| Command | Exit Code | Status | Evidence |
|---|---|---|---|
| `Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --quit` | `0` | **PASS** | All global classes and scenes scanned and loaded with zero parse/import errors. |
| `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m0.gd` | `0` | **PASS** | `SMOKE_TEST_M0: PASS` |
| `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m1a.gd` | `0` | **PASS** | `SMOKE_TEST_M1A: PASS` |
| `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m1a_stabilization.gd` | `0` | **PASS** | `SMOKE_TEST_M1A_STABILIZATION: PASS (200 checks passed)` across Groups A–F. |

---

## 4. Remaining Limitations

- **Human Interactive GUI Golden-Path Playthrough:** **NOT RUN** in this automated CLI environment. The 12-step manual validation checklist is documented in `docs/TEST_PLAN.md`.
- **Performance Benchmark:** **NOT MEASURED** (`PERFORMANCE_NOT_VERIFIED_ON_TARGET_HARDWARE`).
