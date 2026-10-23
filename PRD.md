# PRD — Ninja Warrior Content Simulator

> **Jenis:** Product Requirements Document (PRD)  
> **Status:** Rancangan implementasi v1.0  
> **Tanggal:** 23 Oktober 2026  
> **Target platform:** PC Windows 64-bit, penggunaan pribadi secara offline  
> **Engine:** Godot **4.7.2 stable** (versi acuan; upgrade hanya setelah regression test)  
> **Bahasa:** GDScript bertipe statis (typed GDScript)  
> **Prioritas utama:** alat produksi konten, fleksibilitas kustomisasi, performa low–medium

---

## 1. Ringkasan produk

**Ninja Warrior Content Simulator** adalah aplikasi game/sandbox 3D untuk membuat konten video kompetisi lintasan rintangan ala *obstacle-course television show*. Pengguna dapat merakit arena dari modul rintangan, memilih atau mengganti karakter, menjalankan percobaan secara manual atau melalui AI, melihat hasil kompetisi, mengulang simulasi dengan kamera berbeda, dan membuat materi video untuk YouTube, TikTok, Facebook Reels, atau Shorts.

Ini **bukan game multiplayer komersial**. Produk ditujukan untuk satu kreator yang membutuhkan alur produksi konten yang konsisten, cepat, mudah dimodifikasi, dan hemat sumber daya PC. Nama proyek adalah nama kerja: branding final, logo, nama rintangan, dan aset visual harus orisinal serta tidak menyiratkan afiliasi dengan program TV tertentu.

### 1.1 Masalah yang diselesaikan

Membuat konten balapan rintangan 3D secara manual mengharuskan kreator mengulang pekerjaan yang sama: mengatur arena, menyiapkan tokoh, melakukan take berulang, menempatkan kamera, serta menyusun skor/waktu. Aplikasi ini mengubah pekerjaan tersebut menjadi **pipeline berbasis preset**: buat arena satu kali, jalankan berbagai tokoh, simpan hasil, lalu rekam dari banyak sudut.

### 1.2 Visi

> Satu perangkat lunak desktop ringan untuk membuat banyak variasi video kompetisi rintangan 3D dari arena, karakter, dan preset simulasi yang dapat digunakan ulang.

### 1.3 Pengguna utama dan use case

- **Pengguna primer:** kreator tunggal yang memproduksi video pendek dan panjang.
- **Use case A:** satu arena, 10 karakter humanoid dengan tampilan berbeda; perlombaan menggunakan seed yang sama.
- **Use case B:** variasi arena dan tingkat kesulitan untuk serial video episodik.
- **Use case C:** rerender momen gagal/menang dalam rasio 16:9 dan 9:16 menggunakan replay yang sama.
- **Use case D:** mengganti model karakter dengan asset `.glb` yang kompatibel tanpa menulis ulang controller.
- **Use case E, fase lanjutan:** kompetisi karakter quadruped, robot, atau monster non-humanoid dengan profil kontrol/animasi khusus.

---

## 2. Sasaran, non-sasaran, dan prinsip desain

### 2.1 Sasaran terukur

| ID | Sasaran | Ukuran keberhasilan | Tahap |
|---|---|---|---|
| G-01 | Arena mudah dipakai ulang | Bisa menyimpan, menutup aplikasi, dan memuat arena tanpa kehilangan posisi/konfigurasi | MVP |
| G-02 | Kompetisi dapat dimainkan | Karakter menyelesaikan lintasan contoh atau dieliminasi melalui aturan jelas | MVP |
| G-03 | Konten dapat direkam | Tampilan kamera bersih dan HUD dapat disembunyikan untuk perekaman OBS | MVP |
| G-04 | AI bisa membuat take | AI menyelesaikan *golden path* lintasan referensi dengan cara yang dapat diuji | V1 |
| G-05 | Hasil bisa diambil ulang | Replay posisi/animasi dasar + event dapat dikaji ulang tanpa melakukan lomba kembali | V1 |
| G-06 | Output multi-format | Layout komposisi kamera 16:9 dan 9:16 tidak memangkas subjek secara fatal | V1 |
| G-07 | Ringan | Profil PC low memenuhi **target** 30 FPS pada 720p, 1 karakter, arena referensi | V1 |
| G-08 | Karakter modular | Mengganti 3 model humanoid yang memenuhi spesifikasi rig tanpa mengubah gameplay | V1 |

### 2.2 Non-sasaran

- Tidak ada multiplayer online, akun cloud, matchmaking, pembayaran, atau in-app store.
- Tidak mereplikasi nama, logo, musik, set panggung, atau karakter berhak cipta milik pihak ketiga.
- Tidak membutuhkan ray tracing, global illumination berat, simulasi kain/rambut realistis, atau *ragdoll* kompleks untuk MVP.
- Tidak menjamin satu rig animasi dapat digunakan identik pada semua hewan atau monster.
- Tidak menjanjikan runtime importer universal untuk semua jenis berkas model.
- Tidak menjanjikan ekspor MP4/H.264 langsung dari Godot tanpa pipeline encoder tambahan.
- Tidak menargetkan video live streaming dan puluhan karakter berfisika aktif sekaligus pada perangkat low-end.

### 2.3 Prinsip rancangan

1. **Creator-first:** menu dan workflow menyederhanakan proses produksi video, bukan menambah kompleksitas game.
2. **Offline-first:** save/preset lokal; tidak ada layanan eksternal wajib.
3. **Modular:** karakter, rintangan, AI, replay, dan kamera dihubungkan melalui interface dan sinyal, bukan saling bergantung langsung.
4. **Progressive fidelity:** prototipe greybox harus bekerja sebelum investasi aset visual.
5. **Compatibility-first:** semua efek wajib punya jalur visual sederhana yang bekerja pada renderer Compatibility.
6. **Reproducible runs:** simpan seed, konfigurasi, dan hasil run; replay berbasis transform agar tidak mengandalkan determinisme fisika absolut.
7. **One playable slice at a time:** dilarang memperluas fitur sampai alur inti terverifikasi.

---

## 3. Lingkungan teknis dan target performa

### 3.1 Stack wajib

| Lapisan | Pilihan | Ketentuan |
|---|---|---|
| Engine | Godot 4.7.2 stable | Proyek native `.godot`; tidak menggunakan Unity/Unreal |
| Script | GDScript, tipe eksplisit untuk API publik | Tidak mengharuskan C#/.NET |
| Render utama | Compatibility (OpenGL) | Baseline visual dan pengujian |
| Render opsional | Mobile renderer | Hanya setelah diuji; bukan syarat fungsi |
| Asset 3D | `.glb`/glTF 2.0 | File impor disertai metadata rig, skala, lisensi |
| UI | Godot Control/theme | Navigasi keyboard + mouse |
| Physics | Godot Physics 3D | Fixed physics ticks; collision layer terdokumentasi |
| Penyimpanan | `user://` JSON ber-schema | Path sanitization, validasi, backup save |
| Capture MVP | OBS eksternal / perekaman layar | Clean feed + preset rasio |
| Capture lanjutan | Godot Movie Maker + FFmpeg opsional | Output OGV atau PNG sequence/WAV, encode MP4 secara eksternal |
| Version control | Git | `.gitignore` Godot; semua aset berlisensi |

**Catatan renderer:** compatibility dipilih karena cakupan perangkat lebih luas, bukan karena otomatis tercepat untuk semua adegan. Efek atau fitur shader yang bergantung pada Forward+ dilarang di jalur utama.

### 3.2 Profil perangkat referensi (asumsi pengujian, bukan batas minimum resmi Godot)

| Profil | Contoh perangkat uji | Target permainan |
|---|---|---|
| Low | CPU setara Intel Core i5 gen-8 / Ryzen 3; iGPU kelas UHD 620; RAM 8 GB; penyimpanan SSD | 1280×720, low, 1 karakter aktif, target **≥30 FPS** |
| Medium | CPU setara Core i5 / Ryzen 5; GPU GTX 1050/RX 560 atau lebih baik; RAM 16 GB | 1920×1080, medium, 1–4 karakter sesuai profil, target **≥60 FPS** |

Target tersebut **harus diukur** pada adegan benchmark dan bisa direvisi setelah profiling. Tetapkan target latency input yang tidak terasa mengganggu; jangan mengklaim angka milidetik tanpa pengukuran.

### 3.3 Anggaran produksi scene (baseline, bukan batas keras)

- **MVP:** 1 karakter humanoid aktif, 6 rintangan, kamera tunggal, 1 directional light, mayoritas material opaque.
- Tekstur kebanyakan 512–1024 px; hindari tekstur 4K untuk objek kecil.
- Hindari volumetric fog, real-time GI, kompleksitas transparansi, dan bayangan dinamis berlapis.
- Pengunjung latar menggunakan geometri sederhana/instancing; nonaktifkan physics, AI, dan animasi mahal pada penonton.
- Bentuk collision sederhana; *concave trimesh* hanya untuk geometri statis yang benar-benar memerlukannya.
- Catat **median, 1% low, draw calls, objek aktif, RAM dan VRAM jika tersedia**, pada benchmark yang sama.
- Pisahkan target **playback interaktif** dari **render offline**: rekaman berkualitas tinggi boleh berjalan lebih lambat dari realtime.

---

## 4. Cakupan rilis dan prioritas

| Rilis | Hasil yang wajib terlihat | Tidak wajib saat itu |
|---|---|---|
| **M0 — Technical foundation** | Godot project dapat dibuka, scene utama, kontrol pemain, kamera, platform uji, CI/tes dasar | Editor arena |
| **M1 — Playable prototype / MVP** | 6 rintangan, timer, eliminasi, finish, satu arena referensi, scene editor minimal, save/load, manual mode, clean feed | AI kompetitif penuh, replay |
| **M2 — Creator V1** | 3 model humanoid, katalog karakter, AI traversal rintangan referensi, run history, replay dasar, camera presets 16:9/9:16 | Hewan non-humanoid, turnamen besar |
| **M3 — Creator V1.5** | Multi-run tournament sequential, batch seeds, intro/outro, subtitle skor, pipeline Movie Maker/FFmpeg terdokumentasi | AI universal |
| **M4 — Expansion** | Rig quadruped dan non-humanoid terpilih, obstacle interactions lanjutan, cinematic editor, multi-participant advanced | Tidak ada kewajiban deadline MVP |

### 4.1 Definisi MVP yang tidak boleh melebar

MVP dinyatakan selesai ketika pengguna dapat: **(a)** membuat/memodifikasi arena dari katalog 6 objek, **(b)** menjalankan percobaan manual, **(c)** melihat finish/fail dan waktu, **(d)** save/load arena, **(e)** menampilkan kamera tanpa UI untuk OBS. AI dan replay adalah pekerjaan sesudah MVP.

---

## 5. Perjalanan pengguna (user journey)

1. **Launch:** aplikasi langsung membuka *Home*; preset demo dapat dipilih tanpa setup tambahan.
2. **Pilih karakter:** pilih satu karakter default; tahap berikutnya bisa ganti skin/model.
3. **Arena Editor:** muat arena, tambah rintangan, snap, geser, putar, atur parameter, preview lintasan.
4. **Validate:** tombol Validate memeriksa spawn, checkpoint, finish, urutan route nodes, dan collision yang mencurigakan; tidak menjamin level pasti bisa diselesaikan.
5. **Play/Simulate:** pilih manual atau AI, seed, batas waktu, dan preset kamera.
6. **Result:** waktu, obstacle terakhir, status finish/fail, seed, dan ID percobaan tersimpan.
7. **Replay (V1):** pilih percobaan, scrubbing/playback, pilih sudut kamera, hide UI.
8. **Capture:** MVP menggunakan OBS; V1.5 menyediakan profil rendering offline lewat Godot Movie Maker dan encoding eksternal.
9. **Reuse:** duplikat arena atau karakter dan ekspor ulang materi dengan komposisi berbeda.

### 5.1 Screen map

```
Home
├── Quick Play
├── Character Library
├── Arena Library
│   └── Arena Editor
│       ├── Obstacle Palette
│       ├── Transform/Parameters
│       ├── Validate
│       └── Save As / Load
├── Simulate
│   ├── Manual / AI
│   ├── Seed / Difficulty / Time Limit
│   └── Result
├── Run History / Replay [V1]
├── Capture / Aspect Ratio Presets [MVP/V1]
└── Settings (Graphics, Audio, Controls, Storage)
```

---

## 6. Kebutuhan fungsional

**Kelas prioritas:** P0 = wajib MVP, P1 = wajib V1, P2 = setelah V1.

### 6.1 Core gameplay, movement, dan hasil

| ID | Prioritas | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-001 | P0 | `CharacterBody3D` controller manual | WASD bergerak relatif kamera, Space lompat, Shift sprint, mouse orbit; kontrol tidak hilang setelah respawn |
| FR-002 | P0 | State locomotion | Minimal idle/run/jump/fall/land; transisi tidak menggandakan event dan tetap bekerja dengan model placeholder |
| FR-003 | P0 | Physics interaction | Player dapat berdiri di platform bergerak dan dipengaruhi sweeper; tidak menembus collider pada kecepatan rujukan |
| FR-004 | P0 | Spawn & respawn | Karakter berada pada titik mulai yang ditetapkan arena; tombol retry mengembalikan timer, posisi, dan state |
| FR-005 | P0 | Failure detection | Jatuh melewati fail plane atau masuk fail volume menampilkan status FAIL hanya sekali |
| FR-006 | P0 | Finish detection | Masuk finish volume setelah start menampilkan FINISH, waktu, dan menghentikan run |
| FR-007 | P0 | Timer & time limit | Waktu meningkat saat RUNNING; batas waktu memicu TIMEOUT; pause tidak menambah waktu |
| FR-008 | P0 | Game HUD | Timer, status, dan stage terlihat di game mode; satu tombol menyembunyikan HUD untuk capture |
| FR-009 | P0 | Input remapping dasar | Setidaknya mapping default terdokumentasi dan mouse sensitivity tersedia dalam Settings |
| FR-010 | P1 | Grab/hang traversal | Hanya obstacle ber-tag `grabbable`; tangkap/lepas dengan input yang jelas, cooldown, dan stamina opsional |
| FR-011 | P2 | Ragdoll/gaya jatuh lanjut | Opsional per rig, memiliki fallback animasi jatuh; tidak menjadi dependensi core gameplay |

**Aturan hasil:** state tunggal `READY → RUNNING → FINISHED | FAILED | TIMEOUT`. State terminal tidak boleh mengeksekusi event finish/fail ganda. Reset bisa memulai percobaan baru dengan `run_id` berbeda.

### 6.2 Katalog rintangan

Semua rintangan mewarisi kontrak konseptual `ObstacleBase`, tetapi implementasi node mengikuti kebutuhan physics. Setiap obstacle memiliki: `obstacle_id`, `obstacle_type`, `transform`, `parameters`, `entry_anchor`, `exit_anchor`, `bounds`, `is_enabled`, dan `editor_metadata`.

| ID | Prioritas | Rintangan | Interaksi minimum |
|---|---|---|---|
| OBS-01 | P0 | Gap / stepping pads | Jarak lompatan dapat diubah, jatuh memicu fail jika menyentuh fail volume |
| OBS-02 | P0 | Balance beam | Lebar dan panjang dapat diubah, collision stabil |
| OBS-03 | P0 | Moving platform | Bergerak antara anchor A/B, kecepatan terkonfigurasi, physics sync |
| OBS-04 | P0 | Rotating sweeper | Rotasi pada pivot, kecepatan/arah dapat diatur, collision mendorong/mengganggu pemain |
| OBS-05 | P0 | Swinging pendulum | Ayunan periodik, amplitude dan period terkonfigurasi, collision aktif |
| OBS-06 | P0 | Warped wall | Tinggi/kurva modular, interaksi lari-lompat; konfigurasi demo wajib dapat dilalui manual |
| OBS-07 | P1 | Hanging bars / rings | Grip points, grab/release, traversing, route AI khusus |
| OBS-08 | P2 | Rope swing / rolling log | Mekanik lanjutan bergantung physics/animation tuning |

Setiap implementasi **wajib** menyediakan *preview state*, *reset state*, dan penamaan titik masuk/keluar untuk jalur AI. Hindari menulis collision logic yang hanya bekerja pada satu ukuran objek.

### 6.3 Arena editor in-game

| ID | Prioritas | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-020 | P0 | Obstacle palette | Minimal 6 tipe; klik untuk menambah di grid/posisi target |
| FR-021 | P0 | Select & transform | Pilih objek menggunakan mouse; pindahkan di bidang XZ; rotasi Y; reset transform |
| FR-022 | P0 | Parameter inspector | Mengedit parameter relevan dengan validasi min/max; preview langsung |
| FR-023 | P0 | Duplicate/delete | Duplikat dengan ID baru; hapus tanpa merusak objek lain |
| FR-024 | P0 | Grid snapping | Bisa diaktifkan/nonaktifkan; ukuran grid default 0.5 m |
| FR-025 | P0 | Save/load/Save As | File JSON berversi tersimpan di `user://arenas/`; restart aplikasi tetap menghasilkan arena identik |
| FR-026 | P0 | Spawn/finish editor | Titik spawn dan finish bisa dipindahkan dan divalidasi |
| FR-027 | P0 | Validation report | Daftar error/warning untuk ID duplikat, parameter invalid, spawn/finish hilang, anchor terputus |
| FR-028 | P1 | Undo/redo | Minimal 20 aksi edit terbaru; perintah edit/transform bisa dibatalkan |
| FR-029 | P1 | Preset layout / themes | Preset arena dan warna dapat dipakai ulang, tanpa ketergantungan pada asset premium |
| FR-030 | P2 | Multi-select/grouping | Mengatur beberapa obstacle sekaligus; tidak memblokir rilis V1 |

**Pemisahan scene:** Arena Editor **bukan** Godot Editor plugin. Editor harus dapat digunakan oleh kreator saat game `.exe` dijalankan. Godot Editor plugin boleh digunakan **sebagai alat pengembang**, tetapi bukan pengganti in-game editor.

### 6.4 Karakter, aset, dan animasi

| ID | Prioritas | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-040 | P0 | Model placeholder | Character controller bekerja menggunakan kapsul/mesh sederhana tanpa asset berlisensi |
| FR-041 | P1 | Character catalog | Pilih minimal tiga karakter humanoid dummy/orisinal dengan profil collider yang sesuai |
| FR-042 | P1 | CharacterDefinition | Definisi ID, display name, rig type, model path, animation mapping, collider, scale, movement profile, license metadata |
| FR-043 | P1 | Swap runtime (paket internal) | Ganti antara model yang sudah diimpor ke proyek tanpa merusak kontrol, timer, kamera |
| FR-044 | P1 | Import via workflow editor Godot | Dokumentasi cara memasukkan `.glb`, rig mapping, animasi, dan menghasilkan CharacterDefinition |
| FR-045 | P2 | Runtime custom `.glb` import | Dilakukan hanya setelah studi API import runtime, validasi aset, dan sandbox path; bukan P0/P1 |
| FR-046 | P2 | Quadruped controller | Profil gerak & animation set mandiri; tidak memakai humanoid rig secara paksa |
| FR-047 | P2 | Unusual body types | API adapter untuk slime, naga, robot unik, karakter berkaki >4 |

**Kontrak rig:** kategori `HUMANOID`, `QUADRUPED`, `CUSTOM`. Untuk humanoid, mapping minimal idle/run/jump/fall/land, kemudian grab/hang saat mekanik tersedia. Setiap model punya collision profile dan offset pivot terkalibrasi; ukuran fisik tidak boleh diturunkan tanpa validasi dari ukuran visual semata.

### 6.5 AI competitor & simulasi

| ID | Prioritas | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-050 | P1 | AI mode | Kompetitor dapat berjalan dari spawn menuju finish tanpa input manual pada arena referensi |
| FR-051 | P1 | Obstacle route graph | Arena memiliki node/edge entry/exit; AI memperoleh daftar target dan gerakan per obstacle |
| FR-052 | P1 | Traversal strategy | Setiap obstacle P0 mempunyai strategy khusus (approach, align, act, recover, fail) |
| FR-053 | P1 | Controlled variation | Seed memengaruhi timing/toleransi/keputusan AI yang **dirancang**, bukan mengacak physics secara tak terkendali |
| FR-054 | P1 | Difficulty profiles | EASY/NORMAL/HARD memodifikasi timing/precision/risk berdasarkan parameter terdokumentasi |
| FR-055 | P1 | Failure/recovery | AI mendeteksi tidak bergerak (*stuck*), retry terbatas atau fail yang tercatat; tidak loop tanpa batas |
| FR-056 | P1 | Instrumentation | Log node route, state AI, kegagalan, elapsed, seed, dan obstacle ID |
| FR-057 | P2 | Tournament manager | Banyak peserta dapat mengikuti arena secara **berurutan**; ranking time-to-finish, DNF terakhir |
| FR-058 | P2 | Multi-agent concurrency | Kompetisi simultan hanya setelah profiling CPU/physics |

**Batas penting:** `NavigationAgent3D` membantu permukaan yang bisa dinavigasi, tetapi tidak menyelesaikan sendiri lompatan, ayunan, berpegangan, atau dinding melengkung. Untuk itu diperlukan **waypoint/action graph + traversal strategy**. AI harus bisa gagal secara masuk akal; *fail chance* arbitrer tanpa korelasi tindakan hanya opsi simulasi artistik yang eksplisit.

### 6.6 Run data, replay, dan kamera

| ID | Prioritas | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-060 | P0 | Run session ID | Setiap run memiliki UUID/ID unik, arena ID, karakter ID, seed, dan status |
| FR-061 | P1 | Run history | Minimal 20 hasil run terakhir tampil dalam UI; delete dan detail tersedia |
| FR-062 | P1 | Recorded replay | Simpan transform root karakter dan state animasi dalam sample interval tetap + event timeline |
| FR-063 | P1 | Replay player | Play/pause, scrub, speed 0.5×/1×/2×, seek awal/akhir tanpa menyimulasikan ulang physics |
| FR-064 | P1 | Camera presets | Follow, side, wide, front, finish-line, fixed angle |
| FR-065 | P1 | Camera director | Fokus ke subjek; hindari clipping kamera melalui ray cast; transisi angle halus |
| FR-066 | P1 | Aspect ratio modes | Preview framing 16:9 dan 9:16 memakai safe area/komposisi, bukan crop sembarang |
| FR-067 | P1 | Hide overlays | HUD, debug, editor gizmos, dan overlay dapat dimatikan dari capture output |
| FR-068 | P2 | Event-based highlights | Tandai loncatan, collision, fail, finish untuk akses cepat dan penamaan klip |
| FR-069 | P2 | Camera keyframe editor | Timeline keyframe posisi/rotasi/FOV dan camera cuts |

**Implementasi replay V1:** sampel `root transform`, `visual transform/animation state`, event, dan state obstacle yang **mempengaruhi tampilan** pada tick/sampling rate tetap. Saat replay, dunia menjadi *playback-only*, collision fisika tidak dijalankan sebagai sumber kebenaran. Pengulangan run dengan seed sama tidak dijanjikan pixel-perfect karena physics dapat berbeda antar versi/platform.

**Retensi replay:** batas ukuran/lamanya replay dikonfigurasi (misalnya 3–5 menit per take); data dapat dipangkas/downsample. Hindari menyimpan ribuan pose tulang tiap frame untuk MVP.

### 6.7 Perekaman dan output video

| ID | Prioritas | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-070 | P0 | Clean capture feed | Ada mode bersih tanpa pointer/gizmo/HUD; dapat ditangkap OBS |
| FR-071 | P1 | Video aspect templates | Preset kamera & viewport untuk 1920×1080 (16:9) dan 1080×1920 (9:16) |
| FR-072 | P1 | Audio/music toggles | Volume SFX/musik terpisah; hanya asset dengan hak pakai yang jelas |
| FR-073 | P2 | Movie Maker export workflow | Scene replay dapat dijalankan via Godot Movie Maker untuk OGV atau PNG sequence/WAV |
| FR-074 | P2 | FFmpeg conversion helper | Script lokal mengonversi hasil ke MP4 H.264 + AAC bila tersedia; tampilkan error jika FFmpeg tidak terpasang |
| FR-075 | P2 | Batch render | Renders beberapa shot/rasio dari replay yang sama dengan manifest output |

**Tidak menipu pengguna:** OBS merekam layar secara realtime. Godot Movie Maker adalah mode render/perekaman terpisah, bukan otomatis MP4. Jika mode output tertentu tidak tersedia di build yang dipakai, tampilkan keterbatasannya dan berikan workflow manual yang benar.

---

## 7. Interaksi, kontrol, dan UX

### 7.1 Default keyboard dan mouse

| Konteks | Input | Aksi |
|---|---|---|
| Gameplay | WASD | Move relatif arah kamera |
| Gameplay | Mouse | Orbit/aim camera |
| Gameplay | Space | Jump |
| Gameplay | Left Shift | Sprint |
| Gameplay | E | Grab/release (saat mekanik tersedia) |
| Gameplay | Esc | Pause/menu, melepas mouse |
| Gameplay | R | Retry |
| Gameplay/Capture | H | Toggle clean feed/HUD |
| Editor | LMB | Select/place obstacle |
| Editor | RMB drag | Orbit camera |
| Editor | Mouse wheel | Zoom camera |
| Editor | Q/E | Rotate selected object (editor mode; tidak konflik dengan gameplay) |
| Editor | Delete | Delete selection |
| Editor | Ctrl+D | Duplicate selection |
| Editor | Ctrl+S | Save arena |

### 7.2 UX rules

- Selalu tampilkan mode saat ini (`EDIT`, `PLAY`, `REPLAY`).
- Saat keluar dari editor dengan perubahan belum disimpan, munculkan konfirmasi.
- Kesalahan save/load muncul sebagai pesan yang bisa ditindaklanjuti, bukan crash.
- Pengaturan rendering low dibuat default; kualitas medium dapat dipilih manual.
- Layout harus tetap dapat dipakai pada 1280×720.
- Konfigurasi karakter yang tidak kompatibel menampilkan penyebab dan fallback placeholder.
- Hindari *modal dialog* berantai saat menjalankan banyak simulasi.

---

## 8. Arsitektur sistem

### 8.1 Komponen inti

```
AppRoot
├─ AppState / ScreenRouter
├─ ContentCatalog
│  ├─ ObstacleDefinitions
│  ├─ CharacterDefinitions
│  └─ PresetDefinitions
├─ ArenaService
│  ├─ ArenaRuntime
│  ├─ ArenaEditor
│  ├─ ArenaValidator
│  └─ ArenaSerializer
├─ CompetitionService
│  ├─ RunSession / Timer / Rules
│  ├─ PlayerController
│  ├─ AIController / ActionGraph [V1]
│  └─ ResultRepository
├─ ReplayService [V1]
│  ├─ ReplayRecorder
│  └─ ReplayPlayer
├─ CameraService
│  ├─ CameraRig
│  └─ ShotPresets
├─ CaptureService
└─ SettingsService
```

### 8.2 Struktur folder yang direkomendasikan

```
res://
├── project.godot
├── scenes/
│   ├── app/main.tscn
│   ├── gameplay/arena_runtime.tscn
│   ├── gameplay/player.tscn
│   ├── editor/arena_editor.tscn
│   ├── ui/home.tscn
│   ├── ui/result.tscn
│   └── replay/replay_viewer.tscn
├── scripts/
│   ├── core/
│   ├── gameplay/
│   ├── obstacles/
│   ├── arena/
│   ├── characters/
│   ├── ai/
│   ├── replay/
│   ├── camera/
│   ├── capture/
│   └── ui/
├── resources/
│   ├── characters/
│   ├── obstacles/
│   └── presets/
├── assets/
│   ├── models/
│   ├── textures/
│   ├── audio/
│   └── fonts/
├── tests/
├── tools/
└── docs/
    ├── SETUP.md
    ├── ARCHITECTURE.md
    ├── ASSET_PIPELINE.md
    └── TEST_PLAN.md

user://
├── arenas/
├── runs/
├── replays/
├── exports/
├── logs/
└── settings.json
```

### 8.3 Komunikasi komponen

- Gunakan **signals** untuk `run_started`, `obstacle_entered`, `obstacle_completed`, `run_failed`, `run_finished`, `replay_ready`.
- Gunakan `Resource` atau `RefCounted` terstruktur untuk definisi runtime; serialisasi JSON hanya memakai primitif whitelist, bukan `ResourceLoader` dari jalur tidak tepercaya.
- Arena menyimpan `obstacle_type` dan parameter; tipe konkret dicari melalui *factory* registri.
- AI tidak mengontrol scene tree langsung; gunakan interface abstraksi `MovementIntent` / `TraversalAction`.
- Kamera membaca *subject target* dan event kompetisi; kamera tidak memodifikasi status pertandingan.
- Replay mencatat state tanpa memutasi jalannya run; tidak ada referensi node hidup di file replay.

### 8.4 Contoh schema arena JSON (konseptual)

```json
{
  "schema_version": 1,
  "arena_id": "demo_arena_001",
  "name": "Demo Course",
  "theme_id": "default",
  "time_limit_sec": 120,
  "spawn": {"position": [0, 1, 0], "rotation_y_deg": 0},
  "finish": {"position": [0, 1, 40], "size": [3, 3, 2]},
  "obstacles": [
    {
      "id": "obs_001",
      "type": "moving_platform",
      "position": [0, 1, 10],
      "rotation_y_deg": 0,
      "scale": [1, 1, 1],
      "params": {"speed": 1.5, "distance": 3.0}
    }
  ],
  "route": [
    {"id": "node_start", "position": [0, 1, 0], "action": "run"},
    {"id": "node_platform", "obstacle_id": "obs_001", "action": "moving_platform"},
    {"id": "node_finish", "position": [0, 1, 40], "action": "run"}
  ]
}
```

**Validasi:** `schema_version` diketahui; `arena_id` aman untuk filename; setiap ID unik; tipe rintangan dikenali; jumlah maksimum objek dibatasi; parameter numerik finite, tidak negatif bila tidak bermakna; transform dan ukuran dibatasi; nilai eksternal tidak pernah dijalankan sebagai ekspresi/script.

### 8.5 Contoh schema run dan replay

```json
{
  "schema_version": 1,
  "run_id": "run_20261023_001",
  "arena_id": "demo_arena_001",
  "arena_revision": "sha256-or-content-hash",
  "character_id": "humanoid_default",
  "controller": "ai",
  "seed": 12345,
  "physics_ticks_per_second": 60,
  "duration_ms": 57320,
  "result": "FINISHED",
  "obstacle_events": [
    {"time_ms": 8300, "obstacle_id": "obs_001", "event": "entered"},
    {"time_ms": 12100, "obstacle_id": "obs_001", "event": "completed"}
  ],
  "replay_path": "replays/run_20261023_001.json"
}
```

Replay sebenarnya dapat memakai format biner terkompresi di masa depan; prototipe boleh memakai JSON sederhana selama ada versi schema, validasi, dan pembatasan ukuran. `arena_revision` penting agar replay tidak salah digunakan pada arena yang sudah diubah.

---

## 9. Alur AI dan replay secara teknis

### 9.1 State machine AI

```
SPAWN → ACQUIRE_ROUTE → APPROACH → ALIGN → EXECUTE
                                       │         │
                                       │         ├── SUCCESS → NEXT_NODE
                                       │         ├── RECOVER → APPROACH
                                       │         └── FAILED
                                       └── STUCK → RECOVER / FAILED
```

- Setiap *action strategy* menerima entry point, exit point, kecepatan rintangan, collider subjek, serta timeout.
- Keluaran tiap strategi: `RUNNING`, `SUCCEEDED`, `FAILED`, atau `UNSUPPORTED`.
- Wajib memisahkan *target movement* dari physics apply untuk debugging.
- Setiap langkah berpotensi fail; failure *decision* direkam dan ditautkan ke seed.
- Golden-path test menggunakan arena referensi yang sengaja didesain agar strategi dasar bisa menyelesaikannya.

### 9.2 Determinisme dan reproducibility

- Seed dipakai untuk variasi parameter AI dan event yang diatur eksplisit.
- Pengendali dan obstacle melakukan update fisika dalam `_physics_process` bila cocok.
- Replay tidak mengulang fisika; ia memainkan kembali sampel transform/state.
- Jika video perlu objek bergerak sinkron, rekam state objek relevan atau kendalikan obstacle visual dari timestamp replay.
- Penggantian versi engine atau profil physics **mungkin** menyebabkan variasi run baru; replay tersimpan tetap menjadi sumber kebenaran shot lama.

---

## 10. Nonfunctional requirements

| ID | Topik | Requirement | Metode verifikasi |
|---|---|---|---|
| NFR-01 | Offline | Main game/editor tanpa internet | Putus internet lalu jalankan suite dasar |
| NFR-02 | Stabilitas | Save/load invalid tidak crash | Input JSON rusak, path invalid, data di luar rentang |
| NFR-03 | Performa | Penuhi target di perangkat referensi atau catat gap terukur | Benchmark scripted ≥3 menit / profil |
| NFR-04 | Startup | Home dapat dibuka tanpa memuat semua aset opsional | Startup smoke test |
| NFR-05 | Visual portability | Jalur utama tampil wajar di Compatibility | Test pada mesin OpenGL kompatibel |
| NFR-06 | Maintainability | Satu modul per domain, typed GDScript, sinyal terdokumentasi | Code review & lint/manual audit |
| NFR-07 | Data integrity | Save atomik (temp file, validate, replace) dan backup penting | Simulasi file corrupt/interrupted |
| NFR-08 | Storage control | Data replay/export memiliki batas, bisa dihapus dan lokasi diketahui | Disk usage test |
| NFR-09 | Asset licensing | Semua aset pihak ketiga memiliki sumber/lisensi dan batas publikasi | Periksa `ASSET_LICENSES.md` |
| NFR-10 | Accessibility dasar | Teks dapat dibaca di 720p, kontrol tidak terkunci pada key tunggal | UX smoke test |
| NFR-11 | Debuggability | Log error berisi fase, run ID, arena ID, obstacle ID | Uji fail AI/import/save |
| NFR-12 | Security | File konfigurasi dibaca sebagai data, bukan kode; tidak menjalankan executable sembarang | Validasi import dan code review |

---

## 11. Rencana tes dan acceptance scenarios

### 11.1 Skenario P0 (wajib lolos sebelum menyebut MVP selesai)

1. **Boot:** buka proyek lewat Godot 4.7.2; scene utama berjalan tanpa parse error.
2. **Controls:** player dapat bergerak, berlari, melompat, orbit kamera, pause, retry.
3. **Finish/fail:** satu run masing-masing memicu tepat satu terminal event; timer berhenti.
4. **Six obstacles:** keenam tipe dapat ditempatkan, diedit parameternya, dan disentuh/dilewati dalam mode manual.
5. **Arena editor:** tambah, pilih, pindah, putar, duplikat, hapus rintangan; kamera editor tidak memicu gerak player.
6. **Save/reload:** arena berisi 6 rintangan disimpan, aplikasi ditutup, dibuka kembali, lalu semua tipe/transform/parameter cocok.
7. **Fault handling:** JSON malformed ditolak dengan pesan jelas, tanpa aplikasi crash dan tanpa menghapus save valid.
8. **720p UI:** HUD, editor inspector, dan tombol utama bisa digunakan pada 1280×720.
9. **Clean capture:** tombol H menghapus seluruh gizmo/editor overlay/HUD dari layar gameplay.
10. **Compatibility:** tidak ada efek yang secara wajib mengharuskan Forward+.

### 11.2 Skenario P1 (wajib lolos Creator V1)

1. Tiga model humanoid dapat mengganti representasi visual tanpa mengubah timer dan kamera.
2. AI menyelesaikan golden-path arena referensi **minimal 8 dari 10 run** dengan profil EASY dan seed uji terdokumentasi; nilai ini threshold untuk *arena referensi saja*, bukan seluruh arena kustom.
3. AI yang stuck berhenti atau recovery dalam timeout dan menulis alasan kegagalan.
4. Run history menyimpan arena, karakter, seed, status, durasi, dan event.
5. Replay dapat diputar 0.5×/1×/2× tanpa menjalankan physics simulasi ulang.
6. Kamera 16:9 dan 9:16 menjaga karakter berada dalam safe frame pada golden-path test.
7. Restart aplikasi tidak merusak hasil run/replay yang telah disimpan.

### 11.3 Pengujian performa

- Arena referensi dengan 6 objek, 1 peserta, HUD standar, resolusi 720p low.
- Jalankan profil yang sama selama minimal 3 menit, **3 kali**; catat median FPS, 1% low, resolusi, renderer, detail CPU/GPU/RAM/driver.
- Jalankan medium profile pada 1080p dan 1–4 peserta bila sudah didukung.
- Tidak ada klaim target FPS sebelum benchmark perangkat asli. Jika gagal, buka isu optimasi, sertakan profiler capture dan selisih target.

---

## 12. Milestone, backlog, dan dependensi

### M0 — Foundation

**Deliverables:** `project.godot`, scene `main`, reusable player, camera, pause/restart, sample platform, typed script conventions, `SETUP.md`, minimal tests.  
**Exit:** dapat di-*play* dan 1 smoke test berjalan tanpa error.

### M1a — Gameplay course

**Deliverables:** terminal states, timer, fail/finish volumes, 6 obstacle prefabs, course demo dengan *manual golden path*.  
**Exit:** seluruh obstacle dapat diselesaikan atau gagal secara konsisten; UI hasil akurat.

### M1b — Arena editor & persistence

**Deliverables:** palette, placement, transform, inspector, duplicate/delete, grid, validate, JSON save/load, clean feed.  
**Exit:** seluruh acceptance P0 hijau; hasil capture manual bisa direkam OBS.

### M2a — Characters & AI

**Deliverables:** CharacterDefinition, catalog, 3 rig/model humanoid, action graph, 6 AI strategies, seed/instrumentation.  
**Exit:** golden-path benchmark AI ≥8/10 EASY, failure state jelas.

### M2b — Replay & camera

**Deliverables:** run history, recorded transforms/events, replay timeline, shot presets, 16:9/9:16 framing.  
**Exit:** dua sudut kamera dari replay yang sama menghasilkan shot konsisten.

### M3 — Production pipeline

**Deliverables:** sequential tournament, configurable intro/outro, Movie Maker workflow, FFmpeg converter, export manifests, batch processing.  
**Exit:** contoh video horizontal dan vertikal dihasilkan dari replay yang sama dengan proses terdokumentasi.

### M4 — Special character expansion

**Deliverables:** quadruped prototype, adapter movement, animation mapping khusus, validasi collision dan kompatibilitas obstacle.  
**Exit:** satu hewan quadruped memenuhi subset obstacle yang **secara eksplisit** mendukungnya; rintangan yang tidak kompatibel dilabeli.

---

## 13. Risiko dan mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| AI tampak bodoh atau macet | Konten repetitif dan lambat dibuat | Strategy per obstacle, route graph, debug state, timeout/recovery |
| Perbedaan rig karakter | Model terlihat rusak, animasi gagal | Rig profiles, adapter, golden humanoid rig, validasi dan fallback |
| Physics tidak deterministik | Take tidak identik saat diulang | Rekam transform+event sebagai replay; simpan seed dan versi |
| In-game editor terlalu besar | MVP tak kunjung selesai | Minimal palette/transform/save dahulu; undo/multi-select belakangan |
| Renderer Compatibility terbatas | Visual efek tidak portabel | Lighting sederhana, fallback material, tidak wajib post-processing advanced |
| Capture real-time menurunkan FPS | Video patah-patah | Offline render di tahap lanjutan, OBS hanya untuk MVP |
| File replay terlalu besar | Penyimpanan penuh | Batas durasi, sampling rate, penghapusan dan kompresi |
| Asset publikasi tidak berlisensi | Claim/takedown video | Original assets atau lisensi jelas, arsip sumber, hindari IP bermerek |
| Pengaturan hardware belum diketahui | Estimasi FPS meleset | Benchmark pada perangkat pengguna; sesuaikan budget sesudah data tersedia |
| Runtime impor model arbitrer | Rig/security/kompatibilitas tidak stabil | Import via Godot Editor pada V1, runtime import dijadwalkan P2 |

---

## 14. Definition of Done (DoD)

Sebuah fitur selesai hanya jika seluruh syarat ini dipenuhi:

- [ ] Dapat dipakai lewat UI nyata (bukan sekadar script tanpa scene).
- [ ] Tidak menghasilkan parse error atau runtime error pada jalur pengujian.
- [ ] Tidak merusak kontrak data/sinyal modul lain.
- [ ] Memiliki smoke test atau langkah uji manual yang dapat diulang.
- [ ] Handling minimal untuk input invalid, missing file, dan state reset tersedia.
- [ ] Visual tetap terbaca dengan Compatibility renderer.
- [ ] Perubahan signifikan didokumentasikan pada `CHANGELOG.md` / milestone log.
- [ ] Tidak memuat aset pihak ketiga tanpa asal/lisensi yang terdokumentasi.
- [ ] Pengujian yang tidak dapat dijalankan dilaporkan sebagai **belum diuji**, bukan **lolos**.

**Rilis MVP:** semua P0 selesai, scenario P0 lulus, *build* Windows 64-bit bisa dijalankan, dan alur demo menghasilkan footage melalui capture eksternal.  
**Rilis V1:** P1 selesai, scenario P1 lulus, dan replay/camera pipeline dapat digunakan dalam produksi.

---

## 15. Keputusan awal & asumsi terbuka

### Keputusan yang dibekukan untuk M0–M1

- 3D stylized/low-poly, offline single-user, Windows utama.
- Godot 4.7.2 stable, GDScript, Compatibility default.
- In-game arena editor sederhana (bukan editor plugin saja).
- Satu peserta aktif untuk MVP.
- `.glb` pipeline impor melalui proyek Godot terlebih dahulu.
- Manual play → editor → AI → replay → batch render sebagai urutan pekerjaan.

### Asumsi yang perlu divalidasi setelah prototipe

- Spesifikasi riil PC kreator dan target resolusi default untuk proses capture.
- Tipe animasi dan bentuk karakter prioritas pertama setelah humanoid.
- Durasi video rata-rata, jumlah peserta tiap episode, dan ukuran storage yang tersedia.
- Apakah karakter harus *menang berdasarkan skill* atau boleh diberi scripted drama/failure untuk kebutuhan produksi.
- Perlu/tidaknya fitur voiceover, overlay skor, dan export metadata edit untuk aplikasi video editor.

Asumsi di atas **tidak menghalangi pengerjaan M0–M1**.

---

## 16. Referensi teknis resmi

Referensi teknis berikut adalah rujukan implementasi, bukan pengganti pengujian versi engine aktual:

- Godot 4.7.2 stable: https://godotengine.org/download/windows/
- Godot renderer overview: https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html
- Format impor 3D: https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
- `AnimatableBody3D`: https://docs.godotengine.org/en/4.7/classes/class_animatablebody3d.html
- Godot Movie Maker: https://docs.godotengine.org/en/4.7/tutorials/animation/creating_movies.html
- Static typing GDScript: https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/static_typing.html

---

## 17. Final product acceptance statement

Produk dianggap memenuhi visi awal ketika seorang kreator, tanpa menulis kode, dapat membuka aplikasi, memilih model karakter yang telah terdaftar, menyusun arena, menyimpan preset, menjalankan simulasi, memilih kamera, dan menghasilkan footage kompetisi yang siap diproses untuk media sosial. Pengembangan harus membuktikan alur tersebut melalui milestone bertingkat, bukan dengan menjanjikan semua fiturnya sekaligus.
