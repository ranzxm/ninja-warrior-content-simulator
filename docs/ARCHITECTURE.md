# ARCHITECTURE — Ninja Warrior Content Simulator (M0–M1a)

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
│   └── smoke_test_m1a.gd
└── docs/
    ├── SETUP.md
    ├── ARCHITECTURE.md
    ├── TEST_PLAN.md
    └── IMPLEMENTATION_STATUS.md
```

## 2. State Machine Kompetisi (`RunSession`)

`scripts/competition/run_session.gd` mengelola state tunggal otoritatif untuk setiap percobaan (`run_id` unik monotonik):

```text
READY ──(StartGate / obstacle entry)──► RUNNING
RUNNING ──(FinishZone)────────────────► FINISHED (STAGE CLEAR)
RUNNING ──(FailZone / HazardZone)─────► FAILED
RUNNING ──(elapsed >= time_limit)─────► TIMEOUT (TIME UP)
FINISHED | FAILED | TIMEOUT ──(Retry)─► READY
```

- State terminal (`FINISHED`, `FAILED`, `TIMEOUT`) mengunci transisi lanjutan sehingga event selesai/gagal tidak pernah dieksekusi ganda.
- `tick(delta, is_paused)` hanya menambah waktu saat `state == RUNNING` dan permainan tidak sedang di-pause.

## 3. Arsitektur Obstacle (`ObstacleBase` & 6 Prefab)

Semua rintangan mewarisi `ObstacleBase` (`scripts/obstacles/obstacle_base.gd`) yang menyediakan kontrak:
- Properti: `obstacle_id`, `obstacle_type`, `display_name`, `is_enabled`, `entry_anchor`, `exit_anchor`.
- Metode wajib: `reset_obstacle()`, `get_entry_position()`, `get_exit_position()`, `validate_configuration()`, `get_obstacle_type()`, `get_parameters()`, `apply_parameters()`.
- Sinyal: `obstacle_entered`, `obstacle_completed`, `obstacle_hazard_hit`.

| ID | Kelas / Scene | Pilihan Physics Body & Perilaku |
|---|---|---|
| `OBS-01` | `ObstacleSteppingPads` (`obs_01_stepping_pads.tscn`) | Membangun deretan `StaticBody3D` dengan `BoxShape3D` berdasarkan `pad_count`, `pad_dimensions`, `gap_distance`, `height_variation`, dan `lateral_offset`. |
| `OBS-02` | `ObstacleBalanceBeam` (`obs_02_balance_beam.tscn`) | `StaticBody3D` dengan `BoxMesh` dan `BoxShape3D` yang di-resize langsung sesuai `beam_length`, `beam_width`, dan `beam_height` agar geometri kolisi tetap presisi. |
| `OBS-03` | `ObstacleMovingPlatform` (`obs_03_moving_platform.tscn`) | `AnimatableBody3D` yang digerakkan pada `_physics_process` dengan mode `PING_PONG`, `LOOP`, atau `ONE_WAY`. Karakter di atasnya terbawa secara fisik oleh kecepatan platform. |
| `OBS-04` | `ObstacleRotatingSweeper` (`obs_04_rotating_sweeper.tscn`) | Deck `StaticBody3D` + lengan pemutar `AnimatableBody3D` (`SweeperPivot`) yang berputar pada tick fisika serta memberikan dorongan tangensial saat mengenai player. |
| `OBS-05` | `ObstacleSwingingPendulum` (`obs_05_swinging_pendulum.tscn`) | Jembatan `StaticBody3D` + bandul `AnimatableBody3D` (`PendulumPivot`) dengan gerak harmonik periodik (`sin`) pada `_physics_process` dan dorongan lateral saat kontak. |
| `OBS-06` | `ObstacleWarpedWall` (`obs_06_warped_wall.tscn`) | Landasan pacu datar + 5 segmen tanjakan lengkung progresif (`StaticBody3D`) + dek puncak (`TopDeck`) pada ketinggian `wall_height` yang dapat dicapai dengan sprint + lompat. |

## 4. Siklus Reset (Retry Lifecycle)

Saat `MainApp.restart_session()` dipanggil (`R`, tombol Retry pada hasil, atau Restart pada Pause Menu):
1. Membatalkan status pause dan menyembunyikan `ResultOverlay`.
2. Memanggil `StageDemoArena.reset_all_obstacles()` untuk mengembalikan fase `MovingPlatform`, sudut `RotatingSweeper`, dan fase `SwingingPendulum` ke nilai awal secara idempoten.
3. Memanggil `RunSession.reset_to_ready()` yang membuat `run_id` baru, mengenolkan timer, dan mengembalikan state ke `READY`.
4. Mengembalikan transform dan kecepatan `PlayerController` ke `SpawnPoint` serta mengorientasikan `ThirdPersonCamera` di belakang karakter.

## 5. Konfigurasi Collision Layer & Mask

| Layer Bit | Nilai Mask | Nama Layer | Penggunaan |
|---|---|---|---|
| Layer 1 | `1` | `WORLD` | Lantai, platform statis, dan dek penghubung arena |
| Layer 2 | `2` | `PLAYER` | `PlayerController` (`CharacterBody3D`) |
| Layer 3 | `4` | `OBSTACLE` | Geometri kolisi rintangan modular |
| Layer 4 | `8` | `TRIGGER` | `StartGate`, `FinishZone`, `FailZone`, `EntryTrigger`, `HazardZone` (`Area3D`) |
| Layer 5 | `16` | `EDITOR_PICK` | Disiapkan untuk pemilihan objek di M1b |
