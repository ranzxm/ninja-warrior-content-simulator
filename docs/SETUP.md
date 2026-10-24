# SETUP — Ninja Warrior Content Simulator (M0–M1b)

## 1. Prasyarat
- **Engine:** Godot **4.7.2 stable** (Standard GDScript edition, Windows 64-bit).
- **OS:** Windows 10/11 64-bit dengan dukungan OpenGL 3.3 (Renderer `gl_compatibility`).
- **Koneksi Internet:** Tidak diperlukan (100% offline).

## 2. Membuka dan Menjalankan Proyek di Godot Editor
1. Buka **Godot 4.7.2**.
2. Klik **Import** pada Project Manager, arahkan ke file `project.godot` di root repository ini, lalu klik **Import & Edit**.
3. Tekan **F5** (atau tombol **Run Project**) untuk menjalankan `res://scenes/app/main.tscn`.
4. Tekan **`F2`** (atau klik **`Edit Arena (F2)`** pada HUD) kapan saja untuk membuka **In-Game Arena Editor**.

## 3. Menjalankan Pemeriksaan & Pengujian lewat Command Line (CLI)
```powershell
# Menjalankan game secara langsung
Godot_v4.7.2-stable_win64_console.exe --path .

# Pemeriksaan headless import & parse GDScript
Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --quit

# Menjalankan automated smoke test M0
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m0.gd

# Menjalankan automated smoke & physics test M1a
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m1a.gd

# Menjalankan suite stabilisasi & regresi M1a (200 checks)
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m1a_stabilization.gd

# Menjalankan suite automated test M1b Arena Editor & Persistence (156 checks)
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m1b.gd
```

## 4. Shortcut Keyboard & Mouse (Mode PLAY & Mode EDIT)

| Konteks | Input | Fungsi |
|---|---|---|
| Global | `F2` | Toggle antara mode `PLAY` dan mode `EDIT` (In-Game Arena Editor) |
| Gameplay (`PLAY`) | `W / A / S / D` | Pergerakan karakter relatif arah kamera |
| Gameplay (`PLAY`) | `Mouse Move` | Orbit kamera third-person |
| Gameplay (`PLAY`) | `Space` | Melompat |
| Gameplay (`PLAY`) | `Left Shift` | Sprint |
| Gameplay (`PLAY`) | `R` | Retry / Reset sesi kompetisi ke `READY` |
| Gameplay (`PLAY`) | `H` | Clean Feed: sembunyikan/tampilkan HUD untuk rekaman OBS |
| Gameplay (`PLAY`) | `Esc` | Buka/tutup Pause Menu |
| Editor (`EDIT`) | `Left Click` | Pilih rintangan di viewport 3D / tempatkan rintangan saat mode placement |
| Editor (`EDIT`) | `Shift + Left Drag` | Geser rintangan terpilih pada bidang XZ |
| Editor (`EDIT`) | `Right Mouse Drag` | Orbit kamera editor |
| Editor (`EDIT`) | `Middle Mouse Drag` | Pan kamera editor |
| Editor (`EDIT`) | `Mouse Wheel` | Zoom kamera editor |
| Editor (`EDIT`) | `F` | Fokuskan kamera editor ke rintangan terpilih |
| Editor (`EDIT`) | `Q / E` | Putar rintangan terpilih `-15°` / `+15°` pada sumbu Y |
| Editor (`EDIT`) | `Ctrl + D` | Duplikat rintangan terpilih dengan `instance_id` baru |
| Editor (`EDIT`) | `Delete` | Hapus rintangan terpilih |
| Editor (`EDIT`) | `Ctrl + S` | Simpan arena ke `user://arenas/<arena_id>.json` |
| Editor (`EDIT`) | `Ctrl + Z / Ctrl + Y` | Undo / Redo (hingga 25 langkah) |
| Editor (`EDIT`) | `Esc` | Batalkan mode placement / tutup dialog file |
