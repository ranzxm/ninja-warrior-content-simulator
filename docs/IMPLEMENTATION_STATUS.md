# IMPLEMENTATION STATUS — Ninja Warrior Content Simulator

> **Milestone Aktif:** M0 — Playable Foundation  
> **Pembaruan Terakhir:** 24 Oktober 2026

## 1. Status Milestone

| Milestone | Status | Catatan |
|---|---|---|
| **M0 — Playable Foundation** | **DONE (Code & Scenes Complete; Runtime Verification Pending Godot Binary)** | Seluruh konfigurasi, scene, script, dokumentasi, dan smoke test M0 telah diimplementasikan. |
| **M1a — Core Competition & Obstacles** | Planned | Belum dimulai sesuai instruksi batasan scope M0. |
| **M1b — Arena Editor & Persistence** | Planned | Belum dimulai. |
| **M2a — Modular Character Catalog & AI** | Planned | Belum dimulai. |
| **M2b — Replay & Camera Creator** | Planned | Belum dimulai. |
| **M3 — Content Production Pipeline** | Planned | Belum dimulai. |
| **M4 — Character Anatomy Expansion** | Planned | Belum dimulai. |

## 2. Daftar Fitur M0

| Fitur | Status | Lokasi File |
|---|---|---|
| Konfigurasi `project.godot` (Godot 4.7, Compatibility, 1280×720, Input Map, Physics Layers) | Done | `project.godot` |
| Main scene & session coordinator (spawn, respawn, pause, restart) | Done | `scenes/app/main.tscn`, `scripts/core/main.gd` |
| Player controller (`CharacterBody3D`, 6 locomotion states, sprint, jump, gravity, camera-relative move, smooth rotation) | Done | `scenes/gameplay/player.tscn`, `scripts/gameplay/player_controller.gd` |
| Third-person camera rig terpisah (orbit, pitch clamp, smoothing, `SpringArm3D` collision, mouse capture/release) | Done | `scripts/gameplay/third_person_camera.gd`, `scenes/gameplay/player.tscn` |
| Prototype greybox arena (ground, start platform, stepped platforms, jump gap, fail zone, directional light, environment) | Done | `scenes/gameplay/prototype_arena.tscn`, `scripts/gameplay/prototype_arena.gd` |
| Gameplay HUD (`PLAY`/`PAUSED` status, locomotion state, key hints, toggle clean feed `H`) | Done | `scenes/ui/gameplay_hud.tscn`, `scripts/ui/gameplay_hud.gd` |
| Pause Menu (`Resume`, `Restart`, `Quit` dengan dukungan mouse saat paused) | Done | `scenes/ui/pause_menu.tscn`, `scripts/ui/pause_menu.gd` |
| Headless automated smoke test M0 | Done | `tests/smoke_test_m0.gd` |
| Dokumentasi (`SETUP.md`, `ARCHITECTURE.md`, `TEST_PLAN.md`, `IMPLEMENTATION_STATUS.md`) | Done | `docs/` |

## 3. Blocker & Keterbatasan Saat Ini
- **Lingkungan Eksekusi Lokal:** Binary executable Godot 4.7.2 tidak terpasang pada mesin runner saat ini, sehingga pemeriksaan headless CLI (`godot --headless`) dan pengujian gameplay interaktif berstatus `NOT RUN`.
- **Performa Hardware Target:** `PERFORMANCE_NOT_VERIFIED_ON_TARGET_HARDWARE` — belum diklaim mencapai 30/60 FPS sebelum diukur langsung pada perangkat target.
