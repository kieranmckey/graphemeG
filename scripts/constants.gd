## constants.gd
## Globally registered type. Use Constants.SOME_CONST anywhere without importing.
class_name Constants

# --- Layout ---
const START_LEVEL: int = 0
const MAX_LEVELS: int = 10
const BORDER_SIZE: float = 25.0
const WORLD_TILE_SIZE: float = 120.0
const LETTER_SCALE: float = WORLD_TILE_SIZE / 64.0
const DISABLED_ALPHA: float = 0.15
const DISABLED_FADE_DURATION: float = 3.0
const TAP_MAX_DISTANCE: float = 12.0   # px — move threshold separating tap from drag
const SWIPE_MIN_DISTANCE: float = 40.0 # px — tray scroll threshold

# --- Asset paths ---
const LETTERS_DIR: String = "res://assets/letters/"
const FONT_PATH: String = "res://assets/fonts/Kenney Future.ttf"
const UI_BUTTON_PATH: String = "res://assets/ui/button_rectangle_flat.png"
const GRAPHEME_TILES_DIR: String = "res://assets/grapheme_tiles/"
const GRID_TILES_DIR: String = "res://assets/grid_tiles/"
const GRAPHEME_TILE_FONT_SIZE: int = 68
const UI_FONT_SIZE: int = 48
const WORDS_LIST_PATH: String = "res://data/words7.txt"
const LEVEL_DATA_PATH: String = "res://data/level_data.json"
const GRID_SHAPES_PATH: String = "res://data/grid_shapes.json"
const PUZZLE_BANK_PATH: String = "res://data/puzzle_bank.json"
const PIECE_LIBRARY_PATH: String = "res://data/piece_library.json"

# --- Enums ---

enum TileState {
	IDLE = 0,
	SELECTED,
	FILLED,
	VALIDATED,
	INVALID,
	DISABLED,
	INVALID_DISABLED
}

enum GraphemeState {
	IDLE = 0,
	SELECTED,
	PLACED,
	DISABLED
}

enum TileType {
	DEFAULT = 0,
	HORIZONTAL,
	VERTICAL,
	CROSS
}

enum WorldLayer {
	BOTTOM = 0,
	GRID = 1,
	GRAPHEME = 2,
	PANELS = 3,
	TOP = 4
}
