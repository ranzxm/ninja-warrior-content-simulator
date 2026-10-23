# TEST PLAN — Ninja Warrior Content Simulator (M0)

## 1. Pemeriksaan Otomatis (Headless CLI)

Jalankan perintah berikut pada mesin yang memiliki binary Godot 4.7.2:

1. **Parse & Import Check:**
   ```powershell
   godot --headless --editor --path . --quit
   ```
   - **Kriteria Lulus:** Exit code `0`, tidak ada parse error GDScript atau resource `.tscn` yang gagal dimuat.

2. **Automated Smoke Test (`tests/smoke_test_m0.gd`):**
   ```powershell
   godot --headless --path . -s res://tests/smoke_test_m0.gd
   ```
   - **Kriteria Lulus:** Mencetak `SMOKE_TEST_M0: PASS` dan keluar dengan exit code `0`. Memverifikasi instansiasi `main.tscn`, posisi spawn player, clamp pitch kamera, vektor arah gerak relatif kamera, alur pause/resume, deteksi area jatuh, dan reset posisi/kecepatan saat restart.

## 2. Prosedur Pengujian Interaktif Manual (M0)

| ID | Pengujian | Langkah Uji | Ekspektasi Hasil |
|---|---|---|---|
| T-01 | Project & Main Scene Boot | Buka proyek di Godot 4.7.2 dan tekan F5 | Scene `main.tscn` terbuka pada 1280×720, player muncul di atas platform hijau (`StartPlatform`). |
| T-02 | Pergerakan WASD & Rotasi | Tekan `W`, `A`, `S`, `D` | Karakter bergerak sesuai orientasi kamera, model visual berputar halus menghadap arah gerak, state HUD berubah ke `WALKING` lalu kembali `IDLE` saat berhenti. |
| T-03 | Sprint | Tahan `Left Shift` sambil menekan `W` | Kecepatan meningkat dari 5.0 m/s ke 8.5 m/s, state HUD berubah ke `RUNNING`. |
| T-04 | Jump, Fall, Landing & Anti-Infinite Jump | Tekan `Space` berulang kali saat di udara | Karakter hanya melompat sekali dari lantai (`JUMPING` -> `FALLING` -> `LANDING` -> `IDLE`). Tidak bisa double/infinite jump di udara. |
| T-05 | Camera Orbit & Collision | Gerakkan mouse ke segala arah dan arahkan kamera ke bawah lantai/platform | Kamera berputar halus, rotasi vertikal tertahan pada batas `[-65°, 35°]`, dan `SpringArm3D` mencegah kamera menembus lantai. |
| T-06 | Arena Traversal & Fall Recovery | Lompati celah antar platform; coba sengaja jatuh ke bawah platform | Saat melewati batas bawah (`FailZone`), player otomatis kembali ke `SpawnPoint` dengan kecepatan nol. |
| T-07 | Restart (`R`) | Bergerak ke platform lain lalu tekan `R` | Player dan kamera di-reset ke `SpawnPoint` dalam kondisi `IDLE`. |
| T-08 | Pause Menu (`Esc`) & UI | Tekan `Esc`, uji tombol `Resume`, `Restart`, dan `Quit` dengan mouse | Saat pause: game berhenti, mouse dilepas, mode HUD menjadi `PAUSED`. Tombol `Resume` melanjutkan permainan dan menangkap mouse kembali. |
| T-09 | Clean Feed (`H`) | Tekan `H` saat bermain | HUD disembunyikan/ditampilkan kembali tanpa mengganggu kontrol karakter. |
