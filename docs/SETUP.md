# SETUP — Ninja Warrior Content Simulator (M0–M1a)

## 1. Prasyarat
- **Engine:** Godot **4.7.2 stable** (Standard GDScript edition, Windows 64-bit).
- **OS:** Windows 10/11 64-bit dengan dukungan OpenGL 3.3 (Renderer `gl_compatibility`).
- **Koneksi Internet:** Tidak diperlukan (100% offline).

## 2. Membuka dan Menjalankan Proyek di Godot Editor
1. Buka **Godot 4.7.2**.
2. Klik **Import** pada Project Manager, arahkan ke file `project.godot` di root repository ini, lalu klik **Import & Edit**.
3. Tekan **F5** (atau tombol **Run Project**) untuk menjalankan `res://scenes/app/main.tscn` yang memuat lintasan kompetisi **Stage 01 — Ninja Course Demo** (`res://scenes/arenas/stage_01_demo.tscn`).
4. Scene prototipe awal M0 (`res://scenes/gameplay/prototype_arena.tscn`) tetap tersedia untuk uji regresi.

## 3. Menjalankan lewat Command Line (CLI)
```powershell
# Menjalankan game secara langsung
Godot_v4.7.2-stable_win64_console.exe --path .

# Pemeriksaan headless import & parse GDScript
Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --quit

# Menjalankan automated smoke test M0
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m0.gd

# Menjalankan automated smoke & physics test M1a
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m1a.gd
```

## 4. Shortcut Keyboard & Mouse (M0–M1a)

| Input | Action Name | Fungsi |
|---|---|---|
| `W / A / S / D` | `move_forward`, `move_left`, `move_backward`, `move_right` | Pergerakan karakter relatif arah kamera |
| `Mouse Move` | *(Mouse Motion)* | Orbit kamera horizontal & vertikal |
| `Space` | `jump` | Melompat (hanya saat berada di permukaan lantai/platform) |
| `Left Shift` | `sprint` | Berlari cepat (sprint) |
| `R` | `restart` | Retry / Reset seluruh sesi kompetisi, timer, rintangan, dan karakter ke `READY` |
| `H` | `toggle_hud` | Clean Feed: sembunyikan/tampilkan seluruh HUD, timer, dan panel hasil tanpa mengubah state kompetisi |
| `Esc` | `pause` | Membuka/menutup Pause Menu dan melepas/menangkap kursor mouse |

## 5. Alur Kompetisi M1a
1. Karakter spawn di `StartPlatform` dalam state `READY` (`TIME: 00:00.000`).
2. Melewati `StartGate` memulai state `RUNNING` dan menjalankan timer kompetisi.
3. Melewati keenam rintangan berurutan (`Stepping Pads` → `Balance Beam` → `Moving Platform` → `Rotating Sweeper` → `Swinging Pendulum` → `Warped Wall`) hingga masuk ke `FinishZone` memicu `FINISHED` (`STAGE CLEAR`).
4. Jatuh ke area hazard (`FailZone` / `HazardZone`) memicu `FAILED` tanpa langsung me-respawn karakter; menekan `R` atau tombol **Retry (R)** pada layar hasil mengembalikan seluruh lintasan ke `READY`.
