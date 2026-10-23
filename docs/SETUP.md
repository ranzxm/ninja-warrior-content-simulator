# SETUP — Ninja Warrior Content Simulator (M0)

## 1. Prasyarat
- **Engine:** Godot **4.7.2 stable** (Standard GDScript edition, Windows 64-bit).
- **OS:** Windows 10/11 64-bit dengan dukungan OpenGL 3.3 (Renderer `gl_compatibility`).
- **Koneksi Internet:** Tidak diperlukan (100% offline).

## 2. Membuka dan Menjalankan Proyek di Godot Editor
1. Buka **Godot 4.7.2**.
2. Klik **Import** pada Project Manager, arahkan ke file `project.godot` di root repository ini, lalu klik **Import & Edit**.
3. Tekan **F5** (atau tombol **Run Project** di kanan atas) untuk menjalankan `res://scenes/app/main.tscn`.

## 3. Menjalankan lewat Command Line (CLI)
```powershell
# Menjalankan game secara langsung
godot --path .

# Pemeriksaan headless import & parse GDScript
godot --headless --editor --path . --quit

# Menjalankan automated smoke test M0
godot --headless --path . -s res://tests/smoke_test_m0.gd
```

## 4. Shortcut Keyboard & Mouse (M0)

| Input | Action Name | Fungsi |
|---|---|---|
| `W / A / S / D` | `move_forward`, `move_left`, `move_backward`, `move_right` | Pergerakan karakter relatif arah kamera |
| `Mouse Move` | *(Mouse Motion)* | Orbit kamera horizontal & vertikal |
| `Space` | `jump` | Melompat (hanya saat berada di permukaan lantai/platform) |
| `Left Shift` | `sprint` | Berlari cepat (sprint) |
| `R` | `restart` | Reset posisi dan state karakter ke SpawnPoint |
| `H` | `toggle_hud` | Sembunyikan/tampilkan HUD untuk tangkapan layar bersih (OBS) |
| `Esc` | `pause` | Membuka/menutup Pause Menu dan melepas/menangkap kursor mouse |

## 5. Asumsi Teknis M0
- Karakter menggunakan mesh primitif bawaan Godot (`CapsuleMesh`, `SphereMesh`, `BoxMesh`) tanpa ketergantungan aset `.glb` eksternal.
- Resolusi default diatur ke `1280×720` (`canvas_items`, `expand`) dan renderer `gl_compatibility` untuk menjaga kompatibilitas perangkat low–medium.
- Fizika berjalan pada `60` ticks per detik dengan deteksi jatuh ganda (`Area3D` `FailZone` + pemeriksaan bidang vertikal `fail_plane_y = -3.0`).
