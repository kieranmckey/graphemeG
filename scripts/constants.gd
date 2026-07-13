## constants.gd
## Globally registered type. Use Constants.SOME_CONST anywhere without importing.
## Translated from AMGConstants.h and AMGCharacter.h enums.
class_name Constants

# --- Numeric constants ---
const START_LEVEL: int = 7
const MAX_LEVELS: int = 10
const BORDER_SIZE: float = 25.0
const LEVEL_MAP_SIZE: int = 7
const WORLD_TILE_SIZE: float = 80.0
const LETTER_TILE_SIZE: float = 72.0
const LETTER_OFFSET: float = WORLD_TILE_SIZE * 0.1        # 8.0
const MAP_SIZE: float = LEVEL_MAP_SIZE * WORLD_TILE_SIZE  # 560.0
const PLAY_AREA_Y: float = 0.35  # fraction of viewport height where sliders begin (from bottom)
const START_LIVES: int = 3
const START_TIMER_SECONDS: int = 150  # 2 min 30 sec
const DISABLED_ALPHA: float = 0.15
const DISABLED_FADE_DURATION: float = 3.0
const SWIPE_MIN_DISTANCE: float = 40.0  # pixels required to trigger a page swipe

# --- Asset paths ---
const TILE_ATLAS_DIR: String = "res://assets/tiles/"
const LETTERS_BIG_PATH: String = "res://assets/letters_big.png"
const LETTERS_UI_PATH: String = "res://assets/letters_ui.png"
const BACKGROUND_PATH: String = "res://assets/background.png"
const WORDS_LIST_PATH: String = "res://data/words7.txt"
const GRAPHEME_FREQ_PATH: String = "res://data/grapheme_frequencies.json"
const TILE_MAPS_PATH: String = "res://data/tile_maps.json"
const LEVEL_DATA_PATH: String = "res://data/level_data.json"

# --- Enums (translated from AMGCharacter.h typedefs) ---

enum TileState {
    IDLE = 0,
    SELECTED,
    FILLED,
    VALIDATED,
    INVALID,
    DISABLED,
    INVALID_DISABLED
}

enum GraphemeType {
    VOWEL = 0,
    CONSONANT,
    MORPHEME
}

enum GraphemeDirection {
    HORIZONTAL_RIGHT = 0,
    VERTICAL_DOWN,
    HORIZONTAL_LEFT,
    VERTICAL_UP
}

enum GraphemeState {
    IDLE = 0,
    PANNED,
    PLACED,
    SELECTED,
    INVALID,
    VALID,
    DISABLED
}

enum TileType {
    DEFAULT = 0,   # isolated / single
    HORIZONTAL,    # only connects left/right
    VERTICAL,      # only connects up/down
    CROSS          # connects in both axes
}

enum WorldLayer {
    BOTTOM = 0,
    GRID = 1,
    GRAPHEME = 2,
    PANELS = 3,
    TOP = 4
}

enum LevelCriteriaType {
    NUMBER_OF_WORDS = 0,
    PLAYER_SCORE,
    TILES_FILLED
}

enum WinOrLose {
    WIN = 0,
    LOSE
}
