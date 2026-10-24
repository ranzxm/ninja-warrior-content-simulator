# TEST PLAN — Ninja Warrior Content Simulator (M0–M1b)

## 1. Pemeriksaan Otomatis (Headless CLI)

Dijalankan menggunakan binary resmi `Godot_v4.7.2-stable_win64_console.exe`:

1. **Editor Import & Parse Check:**
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --quit
   ```
   - **Hasil:** **PASS** (Exit code `0`, zero parse/resource errors).

2. **Automated Smoke Test M0 (`tests/smoke_test_m0.gd`):**
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m0.gd
   ```
   - **Hasil:** **PASS** (`SMOKE_TEST_M0: PASS`, exit code `0`).

3. **Automated Smoke Test M1a (`tests/smoke_test_m1a.gd`):**
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m1a.gd
   ```
   - **Hasil:** **PASS** (`SMOKE_TEST_M1A: PASS`, exit code `0`).

4. **Stabilization & Regression Suite M1a (`tests/smoke_test_m1a_stabilization.gd`):**
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m1a_stabilization.gd
   ```
   - **Hasil:** **PASS** (`SMOKE_TEST_M1A_STABILIZATION: PASS (200 checks passed)`, exit code `0`).

5. **In-Game Arena Editor & Persistence Suite M1b (`tests/smoke_test_m1b.gd`):**
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m1b.gd
   ```
   - **Hasil:** **PASS** (`SMOKE_TEST_M1B: PASS (156 checks passed)`, exit code `0`, zero leaked ObjectDB/RID instances).
   - **Cakupan Grup A–F (60 Kasus Uji):**
     - **Group A (1–8):** Pembekuan rintangan dinamis selama `SceneTree.paused` (diuji selama 15 frame fisika nyata), kelanjutan mulus saat resume tanpa loncatan fase, stabilitas siklus pause/resume berulang, alokasi `instance_id` unik (`ob_XXXXXX`), keunikan ID antar rintangan bertipe sama, pelestarian parameter saat duplikasi, dan regresi `Stage 01`.
     - **Group B (9–16):** Inisialisasi arena baru (`create_new_arena`), penempatan keenam tipe rintangan, validitas geometri/kolisi, keunikan `instance_id`, persistensi perubahan posisi di memori, grid snapping `0.5m`, rotasi Y, dan pembaruan parameter via inspector.
     - **Group C (17–24):** Resolusi `ObstacleBase` dari body anak dan raycast viewport 3D (`select_at_screen_position`), duplikasi independen, penghapusan rintangan, sinkronisasi `route` setelah penghapusan, pengeditan `SpawnPoint` & `FinishZone`, pengubahan urutan `route`, dan penolakan atomik nilai parameter invalid.
     - **Group D (25–37):** Serialisasi JSON valid (`schema_version = 1`), penyimpanan ke `user://`, pemulihan penuh saat load (rintangan, transformasi, seluruh parameter, `is_enabled == false`, `instance_id`, urutan `route`, `SpawnPoint`, `FinishZone`), ketiadaan sinyal ganda setelah load, rotasi backup `.bak` pada penyimpanan kedua, dan kemandirian file `Save As`.
     - **Group E (38–49):** Penolakan aman terhadap JSON rusak, tipe rintangan tak dikenal, duplikasi `instance_id`, versi schema tidak didukung, nilai `NaN`/`INF`, transformasi di luar batas dunia, hilangnya `spawn`/`finish`, referensi `route` palsu/duplikat, ukuran payload `> 512 KB`, pelestarian arena aktif saat gagal load, pelestarian file valid saat gagal save, dan pemblokiran path traversal (`../`).
     - **Group F (50–60):** Transisi arena kustom ke `PLAY` mode (`Test Play`), spawn player di `SpawnPoint` kustom, pengiriman rute kustom ke `RunSession`, pemicu `StartGate`, pelacakan terpisah untuk beberapa instance bertipe sama (`MovingPlatform` A vs C), penolakan finish dini, penyelesaian penuh menuju `STAGE CLEAR`, kegagalan `FAILED`, reset `Retry`, dan pelestarian tata letak/flag `is_dirty` saat kembali ke mode `EDIT`.

## 2. Skenario Validasi Manual GUI (M1b Acceptance Scenarios)

Status eksekusi interaktif oleh operator manusia di GUI: **NOT RUN** (prosedur siap dijalankan di jendela Godot 4.7.2).

- **Scenario 1 — Build:** Buka game -> tekan `F2` (`EDIT`) -> klik `New` -> tempatkan keenam tipe rintangan -> geser dan putar beberapa rintangan -> ubah parameter di Inspector -> duplikat `MovingPlatform` (`Ctrl+D`) -> hapus satu rintangan (`Delete`) -> ubah `SpawnPoint` & `FinishZone` -> ubah urutan rute (`Move Up`/`Move Down`) -> klik `Validate`.
- **Scenario 2 — Save/Load:** Simpan sebagai `custom_stage_01` -> tutup aplikasi -> jalankan ulang -> tekan `F2` -> klik `Open / Save As` -> muat `custom_stage_01` -> pastikan seluruh tipe, posisi, rotasi, parameter, dan urutan rute identik.
- **Scenario 3 — Test Play:** Muat arena kustom -> klik `Test Play (F2)` -> mulai dari `SpawnPoint` -> lewati rintangan -> pastikan timer dan progres bekerja -> picu `STAGE CLEAR` atau `FAILED` -> tekan `R` (`Retry`) -> tekan `F2` untuk kembali ke `EDIT` tanpa kehilangan arena.
- **Scenario 4 — Duplicate Types:** Tambahkan 3 `MovingPlatform` dengan kecepatan berbeda di posisi berbeda -> simpan dan muat ulang -> pastikan ketiganya memiliki `instance_id` berbeda dan melacak progres `1/3`, `2/3`, `3/3` secara terpisah.
- **Scenario 5 — Corrupt Data:** Siapkan file JSON rusak di `user://arenas/` -> coba muat lewat editor -> pastikan pesan error tampil jelas, arena aktif tidak rusak, dan aplikasi tidak crash.
