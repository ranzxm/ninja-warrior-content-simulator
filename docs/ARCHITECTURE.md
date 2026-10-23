# ARCHITECTURE — Ninja Warrior Content Simulator (M0)

## 1. Struktur Direktori
```text
res://
├── project.godot
├── PRD.md
├── AGENT_PROMPT.md
├── scenes/
│   ├── app/main.tscn
│   ├── gameplay/player.tscn
│   ├── gameplay/prototype_arena.tscn
│   └── ui/
│       ├── gameplay_hud.tscn
│       └── pause_menu.tscn
├── scripts/
│   ├── core/main.gd
│   ├── gameplay/
│   │   ├── player_controller.gd
│   │   ├── third_person_camera.gd
│   │   └── prototype_arena.gd
│   └── ui/
│       ├── gameplay_hud.gd
│       └── pause_menu.gd
├── assets/
│   ├── models/
│   ├── textures/
│   └── audio/
├── resources/
├── tests/
│   └── smoke_test_m0.gd
└── docs/
    ├── SETUP.md
    ├── ARCHITECTURE.md
    ├── TEST_PLAN.md
    └── IMPLEMENTATION_STATUS.md
```

## 2. Tanggung Jawab Komponen

| Komponen | Script / Scene | Tanggung Jawab |
|---|---|---|
| `MainApp` | `scripts/core/main.gd` (`scenes/app/main.tscn`) | Koordinasi sesi bermain: spawn awal, menangkap sinyal jatuh dari arena, toggle pause (`Esc`), restart (`R`), clean feed (`H`), serta sinkronisasi HUD dan PauseMenu. |
| `PlayerController` | `scripts/gameplay/player_controller.gd` (`scenes/gameplay/player.tscn`) | Fisika karakter `CharacterBody3D`, state machine lokomosi (`IDLE`, `WALKING`, `RUNNING`, `JUMPING`, `FALLING`, `LANDING`), pergerakan relatif kamera, rotasi halus visual karakter, dan reset state. |
| `ThirdPersonCamera` | `scripts/gameplay/third_person_camera.gd` | Rig kamera orbital terpisah dari logika pergerakan player (`top_level = true`). Mengelola mouse capture, orbit yaw/pitch, clamp vertikal, interpolasi posisi halus, dan pencegahan clipping via `SpringArm3D`. Siap dipakai ulang oleh sistem replay/kamera sinematik pada M2b. |
| `PrototypeArena` | `scripts/gameplay/prototype_arena.gd` (`scenes/gameplay/prototype_arena.tscn`) | Menyediakan `SpawnPoint`, platform bertingkat dengan celah lompatan (jump gap), pencahayaan ringan, dan deteksi jatuh melalui `FailZone` (`Area3D`) serta batas ketinggian. |
| `GameplayHud` | `scripts/ui/gameplay_hud.gd` (`scenes/ui/gameplay_hud.tscn`) | Menampilkan judul aplikasi, status mode (`PLAY` / `PAUSED`), state lokomosi player, dan petunjuk kontrol tanpa menghalangi input mouse (`MOUSE_FILTER_IGNORE`). |
| `PauseMenu` | `scripts/ui/pause_menu.gd` (`scenes/ui/pause_menu.tscn`) | Panel pause interaktif (`PROCESS_MODE_ALWAYS`) dengan tombol `Resume`, `Restart`, dan `Quit` yang berkomunikasi melalui signal. |

## 3. Konfigurasi Collision Layer & Mask

| Layer Bit | Nilai Mask | Nama Layer | Penggunaan |
|---|---|---|---|
| Layer 1 | `1` | `WORLD` | Lantai dasar dan platform statis arena (`StaticBody3D`) |
| Layer 2 | `2` | `PLAYER` | Karakter `PlayerController` (`CharacterBody3D`) |
| Layer 3 | `4` | `OBSTACLE` | Rintangan modular (disiapkan untuk M1a) |
| Layer 4 | `8` | `TRIGGER` | Volume pemicu seperti `FailZone` (`Area3D`) |
| Layer 5 | `16` | `EDITOR_PICK` | Raycast pemilihan objek in-game editor (disiapkan untuk M1b) |

- **`Player` (`CharacterBody3D`):** `collision_layer = 2` (`PLAYER`), `collision_mask = 5` (`WORLD | OBSTACLE`).
- **`CameraRig/SpringArm3D`:** `collision_mask = 5` (`WORLD | OBSTACLE`) agar kamera tidak menembus lantai/platform namun mengabaikan collider kapsul player sendiri.
- **`FailZone` (`Area3D`):** `collision_layer = 8` (`TRIGGER`), `collision_mask = 2` (`PLAYER`).
