# GraphemeX — Godot 4 Port

## Background
This project is a port of an iOS SpriteKit game originally written in Objective-C and Swift (Xcode project at `c:\Games\graphemeX`). The original used SpriteKit, UIGestureRecognizer, and UIKit. Everything has been re-implemented in Godot 4 (GDScript).

## What the game is
A crossword-style word puzzle game. Players drag letter pieces called **graphemes** from three horizontal trays onto a 7×7 tile grid to form valid English words horizontally and vertically — like a real-time Scrabble on a fixed board. A 2:30 countdown timer adds pressure. Words are scored by letter rarity; tiles shared between two crossing words get a 2× score bonus.

## Core concepts

**Grapheme types** (one tray each):
- `VOWEL` — single vowel letters (a, e, i, o, u)
- `CONSONANT` — single consonant letters
- `MORPHEME` — multi-letter chunks (e.g. "ing", "ed", "tion")

**Grid** — 7×7 tiles loaded from `data/tile_maps.json` (10 level layouts decoded from the original PNG map files). Tiles are classified as `HORIZONTAL`, `VERTICAL`, or `CROSS` based on neighbours. A grapheme auto-rotates when dragged over the grid to match the tile orientation.

**Word checking** — scans every row and column for consecutive `FILLED` tiles, concatenates the letters, validates against `data/words7.txt` (O(1) Dictionary lookup). Valid words lock their tiles (`VALIDATED`); invalid sequences are marked `INVALID`.

**Level progression** — 10 levels defined in `data/level_data.json`. Each level specifies grapheme counts, duplicate caps, and win criteria (words made / score / tiles filled).

## File map

| File | Purpose | Original class |
|---|---|---|
| `scripts/constants.gd` | All enums and numeric constants (`class_name Constants`) | `AMGConstants.h`, `AMGCharacter.h` |
| `scripts/game_stats.gd` | Autoload — persistent score/best-word via `ConfigFile` | `AMGGameStats` |
| `scripts/leveller.gd` | Autoload — level config + word-list Dictionary | `AMGLeveller` |
| `scripts/grapheme_ai.gd` | Random grapheme generator weighted by frequency | `AMGArtificialIntelligence` |
| `scripts/word_data.gd` | Tracks a word being formed; bonus-tile logic | `AMGWord.swift` |
| `scripts/tile.gd` | Single grid cell; visual state machine | `AMGTile` |
| `scripts/grapheme.gd` | Draggable letter piece; builds sprite visuals from atlas | `AMGGrapheme` |
| `scripts/grapheme_slider.gd` | Horizontal tray with swipeable pages | `AMGGraphemeSlider` |
| `scripts/grid.gd` | Grid build, snap-to-tile, rotate, word-check | `AMGGrid` |
| `scripts/timer_bar.gd` | Countdown `TextureProgressBar` | `AMGTimerBar` |
| `scripts/hud.gd` | `CanvasLayer` HUD — score, lives, buttons | HUD in `AMGGraphemeLevelScene` |
| `scripts/game_level.gd` | Main game scene — input, level lifecycle | `AMGGraphemeLevelScene` |
| `scripts/main_menu.gd` | Main menu | `AMGMainMenuScene` |

## Key coordinate note
SpriteKit uses Y-up; Godot 2D uses Y-down. The grid origin is compensated in `game_level.gd`:
```gdscript
const GRID_ORIGIN := Vector2(
    Constants.BORDER_SIZE + Constants.WORLD_TILE_SIZE * 0.5,
    Constants.BORDER_SIZE + Constants.WORLD_TILE_SIZE * 0.5)
```
Slider Y positions mirror the original `kplayAreaY = 0.35` fraction, inverted.

## Asset requirements
Textures must be copied from the original Xcode project before the game can render:

| Destination | Source (original project) |
|---|---|
| `assets/tiles/tile_0002.png` (+ other tile states) | `graphemes/Tiles.atlas/` |
| `assets/tiles/tile_gray.png` | `graphemes/Tiles.atlas/` |
| `assets/letters_big.png` | `graphemes/lettersBIG.png` |
| `assets/background.png` | `graphemes/images/.../background*.png` |

Tile texture names expected by `tile.gd`: `tile_0002.png`, `tile_white.png`, `tile_filled.png`, `tile_validated.png`, `tile_invalid.png`, `tile_disabled.png`, `tile_invalid_disabled.png`, `tile_gray.png`.

## Conventions
- `Constants.*` enums are used everywhere — do not use raw integers for states.
- Autoloads `GameStats` and `Leveller` are always available globally.
- `class_name` scripts (`Tile`, `Grapheme`, `GraphemeSlider`, `Grid`, `WordData`, `GraphemeAI`, `TimerBar`, `HUD`) are globally registered — no preload needed.
- Scenes instantiate child nodes dynamically (tiles, graphemes) — the `.tscn` files are minimal skeletons; runtime structure is built in `_ready()` / `build()`.
- Touch input is handled in `game_level.gd` via `_input()`. Mouse-button events are translated to `InputEventScreenTouch` equivalents for desktop testing (`pointing/emulate_touch_from_mouse=true` is set in `project.godot`).
