# TEST PLAN — Ninja Warrior Content Simulator (M0–M1a Stabilized)

## 1. Pemeriksaan Otomatis (Headless CLI)

Dijalankan menggunakan binary resmi `Godot_v4.7.2-stable_win64_console.exe`:

1. **Editor Import & Parse Check:**
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --quit
   ```
   - **Hasil:** **PASS** (Exit code `0`).

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

4. **Stabilization & Regression Suite (`tests/smoke_test_m1a_stabilization.gd`):**
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test_m1a_stabilization.gd
   ```
   - **Hasil:** **PASS** (`SMOKE_TEST_M1A_STABILIZATION: PASS (200 checks passed)`, exit code `0`).
   - **Cakupan Grup A–F (44 Kasus Uji):**
     - **Group A (1–8):** Siklus `READY`, `StartGate` tunggal, pemulihan jatuh saat `READY`, timer saat `RUNNING`/`PAUSED`/terminal, penolakan transisi invalid, dan retry dengan `run_id` baru.
     - **Group B (9–16):** Pemisahan `ENTERED` (`[IN PROGRESS]`) vs `COMPLETED` (`[CLEARED]`), penolakan exit tanpa entry, penolakan duplikasi exit/re-entry, penolakan urutan loncat rintangan, penolakan `FinishZone` dini, penolakan finish jika rintangan wajib dinonaktifkan, dan penyelesaian penuh 6 rintangan berurutan.
     - **Group C (17–21):** Penonaktifan (`is_enabled = false`) mematikan visual, simulasi, trigger `Area3D`, dan kolisi fisik (terverifikasi lewat `PhysicsDirectSpaceState3D.intersect_ray`), serta pemulihan penuh setelah siklus enable/disable berulang.
     - **Group D (22–28):** Round-trip JSON (`get_parameters() -> JSON -> apply_parameters()`) untuk keenam tipe rintangan, penolakan tipe salah, nilai di luar batas, `NaN`, key tidak dikenal, jaminan pembaruan atomik tanpa mutasi parsial, serta konsistensi ukuran mesh, collider, dan anchor.
     - **Group E (29–36):** Simulasi fisika multi-frame (`MovingPlatform` membawa player, `RotatingSweeper` dan `SwingingPendulum` mendorong player, `WarpedWall` dapat dinaiki ke `TopDeck`), pembekuan rintangan dinamis di `READY`/terminal, dan determinisme fase setelah reset.
     - **Group F (37–44):** Regresi M0 (WASD relatif kamera, sprint, jump, clamp kamera, pause/resume, restart, clean feed `H`, dan ketersediaan `prototype_arena.tscn`).

## 2. Checklist Validasi Manual Golden Path (12 Skenario Wajib)

Status eksekusi GUI oleh manusia saat ini: **NOT RUN** (wajib dijalankan secara interaktif di jendela Godot 4.7.2).

1. **Skenario 1 — Full Course Completion:** Mulai dari `SpawnPoint` -> lewati `StartGate` -> selesaikan `Stepping Pads` (1/6) -> `Balance Beam` (2/6) -> `Moving Platform` (3/6) -> `Rotating Sweeper` (4/6) -> `Swinging Pendulum` (5/6) -> `Warped Wall` (6/6) -> masuk `FinishZone` -> pastikan muncul `STAGE CLEAR` dan `COMPLETED: 6/6`.
2. **Skenario 2 — Fail on Stepping Pads:** Lompat meleset di antara pad biru -> pastikan status berubah ke `FAILED` (`Fell at Stepping Pads`) dan karakter tidak langsung di-respawn.
3. **Skenario 3 — Fail on Balance Beam:** Jatuh dari samping balok keseimbangan -> pastikan status berubah ke `FAILED` (`Fell at Balance Beam`).
4. **Skenario 4 — Dynamic Obstacle Displacement:** Berdiri diam di jalur `Rotating Sweeper` dan `Swinging Pendulum` saat `RUNNING` -> pastikan karakter terdorong oleh lengan sweeper / bandul.
5. **Skenario 5 — Warped Wall Summit:** Tahan `Left Shift + W` pada landasan Warped Wall dan lompat (`Space`) di kurva atas -> pastikan mendarat di `TopDeck` emas dan HUD menampilkan `OBSTACLE: Warped Wall [CLEARED]` (`COMPLETED: 6/6`).
6. **Skenario 6 — Retry After Failure:** Setelah `FAILED`, tekan `R` atau klik tombol `Retry (R)` -> pastikan state kembali ke `READY`, timer `00:00.000`, `COMPLETED: 0/6`, dan posisi rintangan dinamis ter-reset.
7. **Skenario 7 — Retry After Victory:** Setelah `STAGE CLEAR`, tekan `R` atau klik `Retry (R)` -> pastikan kembali ke `READY` dengan `run_id` baru.
8. **Skenario 8 — Early FinishZone Rejection:** Lompati/lewati rintangan tanpa menyentuh `ExitTrigger` semua 6 rintangan lalu masuk `FinishZone` -> pastikan `STAGE CLEAR` ditolak karena `COMPLETED < 6/6`.
9. **Skenario 9 — Pause During Moving Obstacle:** Tekan `Esc` saat `Moving Platform`, `Sweeper`, atau `Pendulum` bergerak -> pastikan seluruh rintangan dan timer berhenti tepat di posisinya.
10. **Skenario 10 — Resume Without Phase Discontinuity:** Klik `Resume` atau tekan `Esc` kembali -> pastikan rintangan melanjutkan gerakan dari posisi terakhir tanpa loncatan fase.
11. **Skenario 11 — Clean Feed (`H`):** Tekan `H` saat bermain maupun saat panel hasil tampil -> pastikan HUD/overlay tersembunyi tanpa mengubah timer atau state kompetisi.
12. **Skenario 12 — Timer & Completion Count Accuracy:** Pastikan memasuki rintangan hanya menampilkan `[IN PROGRESS]` tanpa menambah angka `COMPLETED`, dan melewati ujung keluar rintangan mengubahnya menjadi `[CLEARED]` serta menambah `COMPLETED` tepat +1.
