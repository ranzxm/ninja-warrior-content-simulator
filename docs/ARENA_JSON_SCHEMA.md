# ARENA JSON SCHEMA — Ninja Warrior Content Simulator (M1b)

## 1. Storage Location & File Rules
- Task 005 clarification: temporary bytes and backup/replacement errors are checked. Godot Windows rename is not guaranteed power-loss atomic; `.bak` is retained for recovery. Earlier "atomic replacement" wording describes the intended validated workflow, not an interruption-proof OS guarantee.
- **Directory:** `user://arenas/`
- **Filename Format:** `<arena_id>.json`
- **Backup File:** `<arena_id>.json.bak` (created/rotated automatically before overwriting an existing valid file)
- **Temporary File:** `<arena_id>.json.tmp` (written and verified prior to atomic replacement)
- **Max File Size:** `524,288` bytes (`512 KB`)

## 2. Schema Version 1 Structure
```json
{
  "schema_version": 1,
  "arena_id": "custom_stage_01",
  "name": "Custom Ninja Course",
  "theme_id": "default",
  "time_limit_sec": 120.0,
  "spawn": {
    "position": [0.0, 0.0, 2.4],
    "rotation_y_deg": 0.0
  },
  "finish": {
    "position": [0.0, 3.0, -70.0],
    "rotation_y_deg": 0.0,
    "size": [4.6, 2.8, 3.6]
  },
  "obstacles": [
    {
      "id": "ob_000001",
      "type": "moving_platform",
      "enabled": true,
      "position": [0.0, 0.0, -10.0],
      "rotation_y_deg": 0.0,
      "params": {
        "movement_distance": 4.6,
        "movement_speed": 2.4,
        "travel_mode": "PING_PONG",
        "initial_direction": 1,
        "platform_size": [2.8, 0.4, 2.8]
      }
    },
    {
      "id": "ob_000002",
      "type": "balance_beam",
      "enabled": true,
      "position": [0.0, 0.0, -20.0],
      "rotation_y_deg": 0.0,
      "params": {
        "beam_length": 7.0,
        "beam_width": 0.6,
        "beam_height": 0.4
      }
    }
  ],
  "route": [
    "ob_000001",
    "ob_000002"
  ]
}
```

## 3. Validation Constraints & Security Rules
- **No Code Execution:** JSON files are parsed strictly as data via `JSON.new()`. No `ResourceLoader.load()` or script paths are accepted from user JSON.
- **`schema_version`:** Must be integer `1`.
- **`arena_id` & `obstacles[].id`:** Must match `^[a-zA-Z0-9_-]{1,64}$`. Path traversal sequences (`..`, `/`, `\`, `:`) are rejected. Every obstacle `id` in `obstacles` must be unique.
- **`name`:** Non-empty String, `1..80` characters.
- **`theme_id`:** Non-empty String, `1..32` characters.
- **`time_limit_sec`:** Finite float in `[10.0, 600.0]`.
- **World Coordinates (`position`):** Finite `[x, y, z]` with `X, Z in [-250.0, 250.0]` and `Y in [-10.0, 100.0]`.
- **Rotations (`rotation_y_deg`):** Finite float in `[-360.0, 360.0]`.
- **`finish.size`:** Finite `[w, h, d]` with each component in `[1.0, 20.0]`.
- **`obstacles`:** Array of `0..100` obstacle objects (`MAX_OBSTACLES = 100`, warning above `30`).
- **`obstacles[].type`:** Must be one of the 6 whitelisted types in `ObstacleFactory`: `stepping_pads`, `balance_beam`, `moving_platform`, `rotating_sweeper`, `swinging_pendulum`, `warped_wall`.
- **`obstacles[].params`:** Must pass the obstacle type's atomic parameter validator (no unknown keys, no wrong types, no `NaN`/`INF`, all values within valid bounds).
- **`route`:** Ordered array of unique obstacle `id` strings referencing entries in `obstacles`. For `Test Play`, the route must contain at least one obstacle and all route obstacles must have `enabled == true`.
