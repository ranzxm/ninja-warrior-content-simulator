# ARCHITECTURE — Ninja Warrior Content Simulator (M0–M1b)

## Task 005 stability update

`ArenaEditor` coordinates existing arena/persistence APIs; `EditorLayout` composes native Control sections; `ParameterInspector` owns stable descriptor-driven inputs and staged values. Ordinary edits never rebuild the emitting controls. Enter/focus exit commits deferred; spinner values coalesce for 300ms and wait for release. Selection/save/mode/history boundaries flush pending values. Transform drag preview does not serialize; release records one of 25 snapshots. Undo/redo resolves selection by stable instance ID and compares content with the save point.

Geometry resources are instance-local, reused across dimensions. Pads/slabs persist; excess pads detach disabled and queue deletion. `apply_parameters()` remains synchronous for safe callers; physics query callbacks use `request_apply_parameters()` deferred. No-op changes skip rebuild/reset. Geometry revision/signal refresh cached mesh-inclusive bounds and selection. Editor pick bodies may remain disabled during PLAY after an EDIT visit; this replaces the previous removal policy.

Selection uses line edges; palette is single-shot PLACE, not immediate creation. Spawn/Finish are separate inspector states. Toolbar metadata lives in Settings. Save verifies exact temporary bytes, checks backup/replacement failures; Windows engine rename is **not guaranteed crash-atomic**. Backup recovery remains required. Details: `M1B_EDITOR_STABILITY_REPORT.md`. No competition or M2a redesign.

## 1. Struktur Direktori
```text
res://
├── project.godot
├── PRD.md
├── AGENT_PROMPT.md
├── scenes/
│   ├── app/main.tscn
│   ├── arenas/stage_01_demo.tscn
│   ├── editor/
│   │   ├── arena_editor_ui.tscn
│   │   └── editor_camera.tscn
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
│   ├── arena/
│   │   ├── stage_demo_arena.gd
│   │   ├── obstacle_factory.gd
│   │   ├── arena_validator.gd
│   │   ├── arena_serializer.gd
│   │   └── arena_repository.gd
│   ├── editor/
│   │   ├── arena_editor.gd
│   │   └── editor_camera.gd
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
│   ├── smoke_test_m1a_stabilization.gd
│   └── smoke_test_m1b.gd
└── docs/
    ├── SETUP.md
    ├── ARCHITECTURE.md
    ├── TEST_PLAN.md
    ├── IMPLEMENTATION_STATUS.md
    ├── M1A_STABILIZATION_REPORT.md
    ├── ARENA_EDITOR_GUIDE.md
    ├── ARENA_JSON_SCHEMA.md
    └── M1B_IMPLEMENTATION_REPORT.md
```

## 2. Mode Aplikasi (`PLAY` vs `EDIT`) & Siklus Pause

- **`MainApp` (`scripts/core/main.gd`):** Mengelola transisi antara `AppMode.PLAY` dan `AppMode.EDIT` (`F2` atau tombol UI).
  - Saat berpindah dari `PLAY` ke `EDIT` ketika `RunSession.state == RUNNING`, sistem meminta konfirmasi pengguna sebelum menghentikan run.
  - Saat berpindah dari `EDIT` ke `PLAY` (`Test Play`), arena divalidasi terlebih dahulu oleh `ArenaValidator.validate_arena()`, rute berurutan dikirim ke `RunSession.configure_route()`, rintangan dinamis di-reset ke fase awal, dan player di-spawn pada `SpawnPoint` hasil edit tanpa menghilangkan status `is_dirty`.
- **Pause-Aware Dynamic Lifecycle:** `StageDemoArena` dan `ObstacleBase` menggunakan `PROCESS_MODE_PAUSABLE` serta flag eksplisit `simulation_paused`. Saat permainan di-pause pada mode `RUNNING`, timer `RunSession` dan seluruh rintangan dinamis (`MovingPlatform`, `RotatingSweeper`, `SwingingPendulum`) berhenti tepat pada fase dan transform saat itu, lalu melanjutkan gerakan tanpa loncatan fase saat `Resume`.

## 3. Kontrak Identitas Rintangan (`obstacle_type` vs `instance_id`)

- **`obstacle_type`:** Kategori rintangan (`stepping_pads`, `balance_beam`, `moving_platform`, `rotating_sweeper`, `swinging_pendulum`, `warped_wall`) yang dipetakan oleh whitelist `ObstacleFactory`.
- **`instance_id`:** Identitas unik per objek yang ditempatkan di arena (`ob_000001`, `ob_000002`, ...), dialokasikan secara monotonik oleh `ObstacleBase.allocate_unique_instance_id()`. Properti `obstacle_id` dipertahankan sebagai alias yang disinkronkan dengan `instance_id`.
- Beberapa instance dari tipe rintangan yang sama dapat ditempatkan dalam satu arena, disimpan ke JSON, dan dilacak progres penyelesaiannya secara independen oleh `RunSession`.

## 4. Subsistem Arena Editor & Persistensi (`M1b`)

| Komponen | Lokasi | Tanggung Jawab |
|---|---|---|
| `ObstacleFactory` | `scripts/arena/obstacle_factory.gd` | Whitelist `obstacle_type -> PackedScene` dan tabel deskriptor parameter untuk pembangkitan inspector dinamis. |
| `ArenaValidator` | `scripts/arena/arena_validator.gd` | Validasi struktur, batas dunia, keunikan `instance_id`, parameter rintangan, dan urutan `route` (memisahkan `errors` dari `warnings` geometris). |
| `ArenaSerializer` | `scripts/arena/arena_serializer.gd` | Konversi `StageDemoArena` <-> `Dictionary` / JSON (`schema_version = 1`) dengan staging atomik saat load. |
| `ArenaRepository` | `scripts/arena/arena_repository.gd` | Penyimpanan file `user://arenas/*.json` dengan proteksi path traversal, tulis-verifikasi `.tmp`, dan rotasi backup `.bak`. |
| `EditorCamera` | `scripts/editor/editor_camera.gd` | Kamera orbital/pan/zoom khusus mode `EDIT` yang terpisah dari `ThirdPersonCamera`. |
| `ArenaEditor` | `scripts/editor/arena_editor.gd` | UI & kontroler editor in-game: palet 6 rintangan, ghost preview, pemilihan raycast (`EDITOR_PICK`), transformasi XZ/rotasi Y, grid snapping, inspector parameter, duplikat/hapus, editor Spawn/Finish, pengurutan rute, serta undo/redo 25 langkah. |

## 5. Konfigurasi Collision Layer & Mask

| Layer Bit | Nilai Mask | Nama Layer | Penggunaan |
|---|---|---|---|
| Layer 1 | `1` | `WORLD` | Lantai, platform statis, dan dek penghubung arena |
| Layer 2 | `2` | `PLAYER` | `PlayerController` (`CharacterBody3D`) |
| Layer 3 | `4` | `OBSTACLE` | Geometri kolisi rintangan modular |
| Layer 4 | `8` | `TRIGGER` | `StartGate`, `FinishZone`, `FailZone`, `EntryTrigger`, `ExitTrigger`, `HazardZone` (`Area3D`) |
| Layer 5 | `16` | `EDITOR_PICK` | `_EditorPickBody` pada `ObstacleBase` (aktif hanya saat mode `EDIT` untuk raycast seleksi mouse) |
