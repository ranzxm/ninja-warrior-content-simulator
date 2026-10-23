# IMPLEMENTATION STATUS — Ninja Warrior Content Simulator

> **Milestone Aktif:** M1a — Core Competition & Modular Obstacles  
> **Pembaruan Terakhir:** 24 Oktober 2026

## 1. Status Milestone

| Milestone | Status | Catatan |
|---|---|---|
| **M0 — Playable Foundation** | **DONE** | Terverifikasi melalui `smoke_test_m0.gd` (`PASS`) dan peluncuran di Godot 4.7.2. |
| **M1a — Core Competition & Obstacles** | **PARTIAL (Code, Scenes & Headless Automated Tests PASS; Full Interactive GUI Golden-Path Pending Manual Play)** | State machine `RunSession`, 6 prefab `ObstacleBase`, arena `stage_01_demo.tscn`, HUD kompetisi, layar hasil, dan `smoke_test_m1a.gd` (`PASS`) selesai. |
| **M1b — Arena Editor & Persistence** | Planned | Belum dimulai sesuai batasan scope M1a. |
| **M2a — Modular Character Catalog & AI** | Planned | Belum dimulai. |
| **M2b — Replay & Camera Creator** | Planned | Belum dimulai. |
| **M3 — Content Production Pipeline** | Planned | Belum dimulai. |
| **M4 — Character Anatomy Expansion** | Planned | Belum dimulai. |

## 2. Daftar Fitur M0 & M1a

| Fitur | Milestone | Status | Lokasi File |
|---|---|---|---|
| Konfigurasi `project.godot`, Input Map, Physics Layers | M0 | Done | `project.godot` |
| `PlayerController` (`CharacterBody3D`, 6 state lokomosi, sprint, jump, camera-relative) | M0/M1a | Done | `scripts/gameplay/player_controller.gd`, `scenes/gameplay/player.tscn` |
| `ThirdPersonCamera` orbital rig (`SpringArm3D`, pitch clamp, smoothing) | M0 | Done | `scripts/gameplay/third_person_camera.gd` |
| `PrototypeArena` greybox regression scene | M0 | Done | `scenes/gameplay/prototype_arena.tscn`, `scripts/gameplay/prototype_arena.gd` |
| `RunSession` state machine (`READY`, `RUNNING`, `FINISHED`, `FAILED`, `TIMEOUT`) & timer | M1a | Done | `scripts/competition/run_session.gd` |
| `ObstacleBase` reusable contract (`reset_obstacle`, anchors, parameter validation) | M1a | Done | `scripts/obstacles/obstacle_base.gd` |
| `OBS-01` Stepping Pads / Jump Gap | M1a | Done | `scenes/obstacles/obs_01_stepping_pads.tscn`, `scripts/obstacles/obs_01_stepping_pads.gd` |
| `OBS-02` Balance Beam | M1a | Done | `scenes/obstacles/obs_02_balance_beam.tscn`, `scripts/obstacles/obs_02_balance_beam.gd` |
| `OBS-03` Moving Platform (`AnimatableBody3D`) | M1a | Done | `scenes/obstacles/obs_03_moving_platform.tscn`, `scripts/obstacles/obs_03_moving_platform.gd` |
| `OBS-04` Rotating Sweeper (`AnimatableBody3D`) | M1a | Done | `scenes/obstacles/obs_04_rotating_sweeper.tscn`, `scripts/obstacles/obs_04_rotating_sweeper.gd` |
| `OBS-05` Swinging Pendulum (`AnimatableBody3D`) | M1a | Done | `scenes/obstacles/obs_05_swinging_pendulum.tscn`, `scripts/obstacles/obs_05_swinging_pendulum.gd` |
| `OBS-06` Warped Wall (segmented curved ramp + summit deck) | M1a | Done | `scenes/obstacles/obs_06_warped_wall.tscn`, `scripts/obstacles/obs_06_warped_wall.gd` |
| Reference Course `stage_01_demo.tscn` (StartGate, 6 obstacles, FailZone, FinishZone) | M1a | Done | `scenes/arenas/stage_01_demo.tscn`, `scripts/arena/stage_demo_arena.gd` |
| Competition HUD & Results Overlay (`STAGE CLEAR`, `FAILED`, `TIME UP`, Clean Feed `H`) | M1a | Done | `scenes/ui/gameplay_hud.tscn`, `scripts/ui/gameplay_hud.gd` |
| Automated Headless Smoke & Physics Tests (`smoke_test_m0.gd`, `smoke_test_m1a.gd`) | M0/M1a | Done (`PASS`) | `tests/smoke_test_m0.gd`, `tests/smoke_test_m1a.gd` |

## 3. Keterbatasan Saat Ini
- **Verifikasi Golden-Path GUI Manual:** Meskipun simulasi fisika headless untuk masing-masing rintangan (`MovingPlatform`, `RotatingSweeper`, `SwingingPendulum`, `WarpedWall`) telah lulus otomatis di Godot 4.7.2, pengujian bermain penuh dari awal hingga garis akhir secara manual oleh manusia di jendela GUI belum dieksekusi dalam sesi otomatis ini.
- **Performa Hardware Target:** `PERFORMANCE_NOT_VERIFIED_ON_TARGET_HARDWARE` — benchmark FPS 3 menit belum diukur.
