# ARCHITECTURE — Ninja Warrior Content Simulator (M0–M1a Stabilized)

## 1. Struktur Direktori
```text
res://
├── project.godot
├── PRD.md
├── AGENT_PROMPT.md
├── scenes/
│   ├── app/main.tscn
│   ├── arenas/stage_01_demo.tscn
│   ├── gameplay/
│   │   ├── player.tscn
│   │   └── prototype_arena.tscn
│   ├── obstacles/
│   │   ├── obs_01_stepping_pads.tscn
│   │   ├── obs_02_balance_beam.tscn
│   │   ├── obs_03_moving_platform.tscn
│   │   ├── obs_04_rotating_sweeper.tscn
│   │   ├── obs_05_swinging_pendulum.tscn
│   │   └── obs_06_warped_wall.tscn
│   └── ui/
│       ├── gameplay_hud.tscn
│       └── pause_menu.tscn
├── scripts/
│   ├── core/main.gd
│   ├── competition/run_session.gd
│   ├── arena/stage_demo_arena.gd
│   ├── gameplay/
│   │   ├── player_controller.gd
│   │   ├── third_person_camera.gd
│   │   └── prototype_arena.gd
│   ├── obstacles/
│   │   ├── obstacle_base.gd
│   │   ├── obs_01_stepping_pads.gd
│   │   ├── obs_02_balance_beam.gd
│   │   ├── obs_03_moving_platform.gd
│   │   ├── obs_04_rotating_sweeper.gd
│   │   ├── obs_05_swinging_pendulum.gd
│   │   └── obs_06_warped_wall.gd
│   └── ui/
│       ├── gameplay_hud.gd
│       └── pause_menu.gd
├── tests/
│   ├── smoke_test_m0.gd
│   ├── smoke_test_m1a.gd
│   └── smoke_test_m1a_stabilization.gd
└── docs/
    ├── SETUP.md
    ├── ARCHITECTURE.md
    ├── TEST_PLAN.md
    ├── IMPLEMENTATION_STATUS.md
    └── M1A_STABILIZATION_REPORT.md
```

## 2. State Machine Kompetisi & Validasi Rute (`RunSession`)

`scripts/competition/run_session.gd` mengelola state otoritatif kompetisi dan urutan penyelesaian rintangan (`required_obstacle_ids`):

```text
READY ──(StartGate)─────────────────────────────► RUNNING
RUNNING ──(All required obstacles COMPLETED + FinishZone)──► FINISHED (STAGE CLEAR)
RUNNING ──(FailZone / HazardZone)───────────────► FAILED
RUNNING ──(elapsed >= time_limit)───────────────► TIMEOUT (TIME UP)
FINISHED | FAILED | TIMEOUT ──(Retry)───────────► READY
```

- **State Traversal Rintangan:** Setiap instance rintangan mengikuti transisi `NOT_STARTED → ENTERED → COMPLETED`.
  - Memasuki `EntryTrigger` hanya mengubah status rintangan menjadi `ENTERED` (`[IN PROGRESS]`), belum menambah jumlah rintangan selesai.
  - Menyentuh `ExitTrigger` setelah `ENTERED` pada urutan rintangan yang benar mengubah status menjadi `COMPLETED` (`[CLEARED]`) dan menambah `completed_obstacle_ids`.
- **Pencegahan Course Skipping:** `FinishZone` memanggil `RunSession.finish_run()` yang memvalidasi `can_finish_run()` (seluruh `required_obstacle_ids` harus aktif/enabled dan berstatus `COMPLETED` secara berurutan).
- **Integritas `READY` & `StartGate`:** Hanya `StartGate` yang memulai `RUNNING`. Jika karakter jatuh sebelum melewati `StartGate`, karakter dikembalikan ke `SpawnPoint` dalam state `READY` tanpa memicu percobaan gagal palsu.

## 3. Arsitektur Obstacle (`ObstacleBase` & Lifecycle Dinamis)

Semua rintangan mewarisi `ObstacleBase` (`scripts/obstacles/obstacle_base.gd`):
- **Aktivasi & Kolisi (`is_enabled`):** Saat `is_enabled == false`, `_sync_collision_tree()` menyimpan layer/mask asli pada metadata node lalu menonaktifkan seluruh `StaticBody3D`, `AnimatableBody3D`, `Area3D` (`monitoring = false`), dan `CollisionShape3D` (`disabled = true`), menghentikan simulasi gerak, serta menahan seluruh sinyal trigger/knockback. Saat `is_enabled == true`, konfigurasi kolisi dipulihkan secara utuh.
- **Kontrak Parameter Atomik:** `get_parameters()` menghasilkan `Dictionary` kompatibel JSON, dan `apply_parameters()` memvalidasi whitelist key, tipe data, nilai finite, serta batas rentang sebelum menerapkan perubahan dan membangun ulang mesh, collider, anchor, serta trigger secara atomik.
- **Siklus Simulasi Dinamis (`start_simulation` / `stop_simulation`):**
  - `READY`: Reset ke fase awal dan diam (stationary).
  - `RUNNING`: Bergerak normal pada `_physics_process`.
  - `PAUSED`: Membeku pada fase saat ini.
  - `FINISHED` / `FAILED` / `TIMEOUT`: Membeku pada fase akhir.
  - `RETRY`: Reset kembali ke fase awal di `READY`.

## 4. Konfigurasi Collision Layer & Mask

| Layer Bit | Nilai Mask | Nama Layer | Penggunaan |
|---|---|---|---|
| Layer 1 | `1` | `WORLD` | Lantai, platform statis, dan dek penghubung arena |
| Layer 2 | `2` | `PLAYER` | `PlayerController` (`CharacterBody3D`) |
| Layer 3 | `4` | `OBSTACLE` | Geometri kolisi rintangan modular |
| Layer 4 | `8` | `TRIGGER` | `StartGate`, `FinishZone`, `FailZone`, `EntryTrigger`, `ExitTrigger`, `HazardZone` (`Area3D`) |
| Layer 5 | `16` | `EDITOR_PICK` | Disiapkan untuk pemilihan objek di M1b |
