## word_data.gd
## Tracks a word being formed from consecutive grid tiles.
## Translated from AMGWord.swift.
class_name WordData

var graphemes: Array = []    # Grapheme nodes contributing to this word
var tiles: Array = []        # Tile nodes (unique set)
var word_string: String = "" # Concatenated letter string
var direction: Constants.GraphemeDirection = Constants.GraphemeDirection.HORIZONTAL_RIGHT
var length: int = 0          # Number of individual letters placed
var start_row: int = 0
var start_col: int = 0
var start_offset: int = 0    # Letter index within first grapheme

var score: int:
    get:
        var total := 0
        for g in graphemes:
            total += g.score
        return total

# ── Building ──────────────────────────────────────────────────────────────────

func add_grapheme(grapheme, dir: Constants.GraphemeDirection, tile) -> void:
    direction = dir

    if not tiles.has(tile):
        tiles.append(tile)

    if length == 0:
        start_offset = tile.letter_index
        if dir == Constants.GraphemeDirection.HORIZONTAL_RIGHT:
            start_col = grapheme.start_tile_col + tile.letter_index
            start_row = grapheme.start_tile_row
        else:
            start_col = grapheme.start_tile_col
            start_row = grapheme.start_tile_row + tile.letter_index

    if not graphemes.has(grapheme):
        graphemes.append(grapheme)
        word_string += grapheme.text

    length += 1

func reset() -> void:
    graphemes.clear()
    tiles.clear()
    word_string = ""
    length = 0
    start_offset = 0

# ── Bonus ─────────────────────────────────────────────────────────────────────

## Tiles shared between two or more valid words are intersection squares.
## They receive a 2× score bonus (matching the original checkBonusTiles logic).
static func check_bonus_tiles(valid_word_list: Array) -> void:
    var bonus_tiles: Array = []
    for i in range(valid_word_list.size()):
        for j in range(valid_word_list.size()):
            if i == j:
                continue
            for tile in valid_word_list[i].tiles:
                if valid_word_list[j].tiles.has(tile) and not bonus_tiles.has(tile):
                    bonus_tiles.append(tile)
    for tile in bonus_tiles:
        tile.apply_bonus()
        if tile.grapheme != null:
            tile.grapheme.score *= 2
