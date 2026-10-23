# TEST PLAN — Ninja Warrior Content Simulator (M0–M1a)

## 1. Pemeriksaan Otomatis (Headless CLI)

Dijalankan menggunakan binary resmi `Godot_v4.7.2-stable_win64_console.exe`:

1. **Editor Import & Parse Check:**
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --quit
   ```
   - **Status Eksekusi:** **PASS** (Exit code `0`, seluruh class global dan scene terdaftar tanpa parse error).

2. **Automated Smoke Test M0 (`tests/smoke_test_m0.gd`):**
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m0.gd
   ```
   - **Status Eksekusi:** **PASS** (`SMOKE_TEST_M0: PASS`, exit code `0`).

3. **Automated Smoke & Physics Test M1a (`tests/smoke_test_m1a.gd`):**
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m1a.gd
   ```
   - **Status Eksekusi:** **PASS** (`SMOKE_TEST_M1A: PASS`, exit code `0`).
   - **Cakupan Terverifikasi (15 kategori):**
     1. `main.tscn` dan `StageDemoArena` dimuat dengan benar.
     2. Keenam prefab rintangan (`obs_01` s/d `obs_06`) dapat diinstansiasi secara independen.
     3. Seluruh rintangan memiliki `obstacle_id`, `obstacle_type`, `EntryAnchor`, dan `ExitAnchor` valid.
     4. State `READY` menginisialisasi timer `00:00.000` dan `run_id` unik.
     5. State `RUNNING` menjalankan timer sesuai delta fisika.
     6. Timer berhenti bertambah saat `is_paused == true`.
     7. State `FAILED` menolak transisi ke `FINISHED` dan tidak me-respawn karakter secara instan.
     8. State `FINISHED` menolak transisi ke `FAILED`.
     9. State `TIMEOUT` terpicu tepat satu kali saat melewati `time_limit_sec`.
     10. Retry mengembalikan state ke `READY` dengan `run_id` baru dan menyembunyikan layar hasil.
     11. Retry me-reset state dinamis `MovingPlatform`, `RotatingSweeper`, dan `SwingingPendulum`.
     12. Pemicu `FinishZone` ganda tidak menimbulkan sinyal selesai ganda.
     13. Parameter konfigurasi rintangan yang invalid ditolak dengan aman (`apply_parameters` mengembalikan `false`).
     14. Fitur M0 (clean feed `H`, pause menu, `prototype_arena.tscn`) tetap utuh.
     15. Simulasi fisika multi-frame: `MovingPlatform` membawa player yang berdiri di atasnya, `RotatingSweeper` dan `SwingingPendulum` mendorong player saat terjadi kontak, dan player berhasil menaiki `WarpedWall` (sprint + jump) hingga ke `TopDeck` (`y >= 3.1m`).

## 2. Prosedur Pengujian Manual Golden Path (M1a)

| ID | Target Uji | Langkah Uji Manual | Hasil yang Diharapkan |
|---|---|---|---|
| M1A-01 | StartGate & Timer | Jalankan game (F5), maju keluar dari `StartPlatform` melewati pilar hijau `StartGate` | Status berubah `READY` -> `RUNNING`, timer mulai berjalan. |
| M1A-02 | OBS-01 Stepping Pads | Lompati 4 pad biru secara berurutan menuju Deck 01 | HUD menampilkan `OBSTACLE: Stepping Pads (1/6)`; lompatan mendarat stabil di tiap pad. |
| M1A-03 | OBS-02 Balance Beam | Berjalan/sprint lurus di atas balok kuning sempit menuju Deck 02 | HUD menampilkan `OBSTACLE: Balance Beam (2/6)`; collider balok stabil. |
| M1A-04 | OBS-03 Moving Platform | Tunggu platform hijau mendekat, lompat ke atasnya, biarkan terbawa ke Deck 03 | HUD menampilkan `OBSTACLE: Moving Platform (3/6)`; karakter ikut bergerak bersama platform tanpa selip. |
| M1A-05 | OBS-04 Rotating Sweeper | Maju ke dek sweeper, lompati palang merah yang berputar (`Space`) menuju Deck 04 | HUD menampilkan `OBSTACLE: Rotating Sweeper (4/6)`; palang mendorong karakter jika tertabrak dan dapat dilompati. |
| M1A-06 | OBS-05 Swinging Pendulum | Amati ayunan bandul oranye, lewati jembatan saat bandul mengayun ke samping menuju Deck 05 | HUD menampilkan `OBSTACLE: Swinging Pendulum (5/6)`; bandul menggeser karakter jika bersentuhan. |
| M1A-07 | OBS-06 Warped Wall | Tahan `Left Shift + W` di landasan pacu biru, tekan `Space` saat menaiki kurva atas untuk mendarat di dek puncak emas | HUD menampilkan `OBSTACLE: Warped Wall (6/6)`; karakter berhasil naik ke `TopDeck` (`y = 3.2m`). |
| M1A-08 | Finish Volume | Masuk ke antara dua pilar emas di `FinishPlatform` | Status berubah ke `FINISHED`, timer berhenti, muncul panel `STAGE CLEAR` beserta waktu tempuh dan tombol `Retry (R)`. |
| M1A-09 | Fall Failure & Retry | Sengaja jatuh dari rintangan mana pun ke area bawah, lalu tekan `R` atau klik `Retry (R)` | Saat jatuh: muncul panel `FAILED` beserta alasan dan karakter tidak langsung respawn. Saat `R` ditekan: seluruh rintangan, timer, dan karakter kembali ke `READY` di `StartPlatform`. |
| M1A-10 | Clean Feed (`H`) | Tekan `H` saat `RUNNING` maupun saat layar hasil tampil | Seluruh elemen HUD dan overlay hasil disembunyikan/ditampilkan kembali tanpa mengubah state kompetisi. |
