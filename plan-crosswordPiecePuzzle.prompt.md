# Plan: Full Game Redesign — Crossword Piece Puzzle

**TL;DR**: Replace the existing game with a puzzle where the player reconstructs a pre-computed crossword by placing and rotating Tetris-like letter pieces onto a shaped grid. The grid IS the level number — a "1"-shaped column, "2"-shaped tiles, etc. Remove all health, timer, and scoring entirely.

---

## Key Decisions
- **Grid shapes**: Digit/symbol silhouettes — level 1 = 6×1 column ("1"), level 2 = "2" shape, level 3 = "3", then L and + shapes
- **Puzzle content**: Pre-computed fills in `data/puzzle_bank.json`; random unused puzzle selected each play
- **Piece splitting**: The filled grid is randomly partitioned into library shapes at game start; that split becomes the "model solution"
- **Rotation**: Tap a piece (in tray or on grid) to cycle 90° CW
- **Check trigger**: Immediate VALIDATED glow when a piece matches its model-solution position; full word validation auto-runs when all pieces are placed
- **Tray**: Single horizontal scrollable row; left/right arrows when pieces overflow
- **Out of scope**: The offline tool to generate `puzzle_bank.json` (separate deliverable)

---

## Phase 0 — Delete Dead Code *(no dependencies, do first)*

Delete: `timer_bar.gd` + scene, `game_stats.gd`, `grapheme_ai.gd`, `grapheme_slider.gd` + scene, `word_data.gd`. Remove their references from `game_level.gd`, `hud.gd`, `constants.gd`, and `project.godot`.

---

## Phase 1 — New Data Schemas *(prerequisite for everything else)*

Four new/redesigned JSON files:

**`data/grid_shapes.json`** — one entry per shape name, listing which `[row, col]` cells exist. Every consecutive run of cells in any row or column must be ≥ 3 long (crossword minimum). **Digit shapes are a critical authoring deliverable** — each must be designed to satisfy this constraint (some digits like "2" need stylising).

**`data/puzzle_bank.json`** — pre-computed crossword fills keyed by shape name. Each entry: a 2D letter grid + word list with position/direction. Target ≥ 30 puzzles per shape.

**`data/piece_library.json`** — starter library of shapes (dot, domino, tromino-I, tetromino-I, L, J, T, S, Z) stored as 4×4 bitmaps per rotation.

**`data/level_data.json`** — redesigned: each level maps to a `grid_shape` name, min/max piece count, and allowed piece IDs.

---

## Phase 2 — Core Data Classes *(depends on Phase 1)*

**`scripts/piece_shape.gd`** (new, `class_name PieceShape`) — parses a library entry into `get_cells(rotation) → Array[Vector2i]` and `rotation_count()`. Static `load_library()`.

**`scripts/piece_splitter.gd`** (new, `class_name PieceSplitter`) — greedy reading-order algorithm: for each uncovered grid cell, shuffle library shapes and pick first fitting shape+rotation; fallback to dot. Returns array of `{shape, rotation, origin, cells, letters}` = the model solution.

**`scripts/leveller.gd`** (simplified) — remove old grapheme-count/criteria methods. Keep `is_word_valid()`. Add `load_level()`, `get_puzzle(shape_name)` (tracks used IDs to avoid repeats), `load_grid_shape()`.

---

## Phase 3 — Grid Redesign *(depends on Phase 2)*

**`scripts/grid.gd`** — remove `tile_maps.json` loading, scoring signals, bonus logic, `word_data.gd` usage. New `build(shape_data, fill_data, origin)` creates only the cells in the shape and classifies each tile as HORIZONTAL/VERTICAL/CROSS by scanning same-row/col neighbours. New `check_piece_vs_solution(piece, model) → bool` for immediate feedback. `check_for_valid_words()` simplified — emits `words_validated(all_valid, invalid_pieces)`.

**`scripts/tile.gd`** — remove `apply_bonus()` only; all states (IDLE, FILLED, VALIDATED, INVALID) remain.

---

## Phase 4 — Piece (Grapheme) Redesign *(depends on Phase 2; parallel with Phase 3)*

**`scripts/grapheme.gd`** — remove linear-only assumption, `grapheme_type`, `score`. Add `cells: Array[Vector2i]` (relative offsets for current rotation), `letters: Array[String]` (one per cell), `rotation_index: int`. New `setup(shape, initial_rotation, letters)`. New `tap_rotate()` — increments rotation, rebuilds cells + visual sprites. `build_visuals()` places a LetterCell at each cell offset × `WORLD_TILE_SIZE`. `get_bounding_rect()` now spans 2D cell extents.

**`scenes/components/grapheme.tscn`** — remove ScoreLabel.

---

## Phase 5 — Piece Tray *(depends on Phase 4; parallel with Phase 3)*

**`scripts/piece_tray.gd`** (new, replaces grapheme_slider) — `load_pieces(pieces)` lays out left-to-right; if total width > viewport, enables scroll arrows. `detach_piece()`, `return_piece()`, `mark_placed()` match the current GraphemeSlider API so `game_level.gd` stays compatible.

**`scenes/components/piece_tray.tscn`** — new minimal scene.

---

## Phase 6 — Game Level Flow *(depends on Phases 2–5)*

**`scripts/game_level.gd`** — strip sliders (×3), lives, timer. New `_start_level()`: load level config → pick puzzle → split into pieces → build grid → randomise piece rotations → populate PieceTray. Input: tap-without-drag → `piece.tap_rotate()`; drag → existing snap logic. After snap: `check_piece_vs_solution()` → VALIDATED immediately if match. When `piece_tray.all_placed()` → auto-run `check_for_valid_words()` → show level-end panel.

---

## Phase 7 — HUD & Menu Cleanup *(parallel with any phase)*

**`hud.gd` + `hud.tscn`** — remove score/lives/timer/best-word nodes and methods. Keep CheckButton (repurpose as "Hint"), level-end panel + Next/Redo/Quit.

**`main_menu.gd`** — remove HiScoreLabel and best-word display.

**`constants.gd`** — remove `START_LIVES`, `START_TIMER_SECONDS`, `LevelCriteriaType`, `WinOrLose`, `GraphemeType` (vowel/consonant/morpheme no longer needed).

---

## File Map

| File | Action |
|---|---|
| `scripts/timer_bar.gd` + scene | DELETE |
| `scripts/game_stats.gd` | DELETE |
| `scripts/grapheme_ai.gd` | DELETE |
| `scripts/grapheme_slider.gd` + scene | DELETE → replaced by piece_tray |
| `scripts/word_data.gd` | DELETE → inline word scan in grid.gd |
| `scripts/constants.gd` | TRIM (remove timer/lives/scoring constants + enums) |
| `scripts/grapheme.gd` | MAJOR REDESIGN (2D shapes + tap rotate) |
| `scripts/grid.gd` | MAJOR REDESIGN (arbitrary shapes, solution check) |
| `scripts/game_level.gd` | MAJOR REDESIGN (new level flow) |
| `scripts/leveller.gd` | SIMPLIFY + EXTEND (puzzle bank loading) |
| `scripts/hud.gd` | TRIM (remove score/lives/timer nodes) |
| `scripts/main_menu.gd` | TRIM (remove hi-score) |
| `scripts/tile.gd` | MINOR (remove apply_bonus) |
| `scripts/piece_shape.gd` | NEW |
| `scripts/piece_splitter.gd` | NEW |
| `scripts/piece_tray.gd` | NEW |
| `data/level_data.json` | REDESIGN |
| `data/grid_shapes.json` | NEW |
| `data/puzzle_bank.json` | NEW (30+ puzzles per shape, authoring tool TBD) |
| `data/piece_library.json` | NEW |
| `scenes/components/piece_tray.tscn` | NEW |
| `project.godot` | Remove GameStats autoload |

---

## Verification

1. Godot opens with zero parser errors after Phase 0 deletions
2. JSON schemas load without errors in a test script
3. Tile classification correct for digit_1 shape (all VERTICAL)
4. Tap a piece → rotation cycles correctly; bounding rect matches 2D shape
5. Tray with 4 pieces: all visible; with 10 pieces: scroll arrows appear
6. Full level 1 play-through: place piece → instant VALIDATED glow → complete grid → level-end panel
7. Alternative valid crossword solution also accepted on grid-complete

---

## Open Questions

1. **Digit shape authoring**: Digits "2", "3", "8", "9" need stylising so every run of cells ≥ 3 long. Levels 6–10 shapes are TBD — extend the digit theme (4, 5, 6, 7, 8, 9, 0) or mix in other symbols?

2. **Puzzle bank generation**: A separate Python/GDScript backtracking solver must generate `puzzle_bank.json`. Should this be in scope?

3. **Piece splitting fairness**: The greedy random splitter can produce very different difficulty each run (all dots = trivial; all L-shapes = hard). Should `level_data.json` constrain min/max piece size per level?
