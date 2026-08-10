## grid.gd
## The 7×7 gameplay grid — translated from AMGGrid.h/.m
## Builds tiles from tile_maps.json, handles snap/rotate/word-check logic.
## Scene: res://scenes/components/grid.tscn
class_name Grid
extends Node2D

signal words_validated(valid_words: Array)
signal score_updated(delta: int)

# ── State ─────────────────────────────────────────────────────────────────────

## tile_grid[row][col] → Tile or null
var tile_grid: Array = []
## Flat list of all Tile nodes
var tiles: Array = []

var score: int = 0
var number_of_words: int = 0
var max_word: String = ""

var _valid_words: Array = []
var _invalid_words: Array = []
var _all_words: Array = []
var _tile_maps: Dictionary = {}

# ── Initialization ────────────────────────────────────────────────────────────

func _ready() -> void:
    _load_tile_maps()

func _load_tile_maps() -> void:
    var file := FileAccess.open(Constants.TILE_MAPS_PATH, FileAccess.READ)
    if file:
        var parsed = JSON.parse_string(file.get_as_text())
        if parsed is Dictionary:
            _tile_maps = parsed
        file.close()

## Build the grid at world-space origin.
## Call this from the parent scene after the node is in the tree.
func build(grid_origin: Vector2) -> void:
    # Reset
    for t in tiles:
        if is_instance_valid(t):
            t.queue_free()
    tiles.clear()
    tile_grid.clear()

    for row in range(Constants.LEVEL_MAP_SIZE):
        tile_grid.append([])
        for _col in range(Constants.LEVEL_MAP_SIZE):
            tile_grid[row].append(null)

    var map_name := Leveller.tile_map_name()
    if not _tile_maps.has(map_name):
        push_error("Grid: tile map '%s' not found" % map_name)
        return

    var map: Array = _tile_maps[map_name]
    var tile_scene := load("res://scenes/components/tile.tscn") as PackedScene

    for row in range(Constants.LEVEL_MAP_SIZE):
        for col in range(Constants.LEVEL_MAP_SIZE):
            if row >= map.size() or col >= (map[row] as Array).size():
                continue
            if (map[row] as Array)[col] == 0:
                continue

            var tile: Tile = tile_scene.instantiate()
            tile.position = Vector2(
                grid_origin.x + col * Constants.WORLD_TILE_SIZE,
                grid_origin.y + row * Constants.WORLD_TILE_SIZE)
            tile.row = row
            tile.col = col
            tile.z_index = Constants.WorldLayer.GRID
            add_child(tile)
            tile_grid[row][col] = tile
            tiles.append(tile)

    _classify_tiles()

## Classify each tile as H-only, V-only, or cross, based on neighbours.
## Matches addTileData in AMGGrid.m
func _classify_tiles() -> void:
    for t in tiles:
        var has_h := false
        var has_v := false
        for t2 in tiles:
            if t.row == t2.row and abs(t.col - t2.col) == 1:
                has_h = true
            if t.col == t2.col and abs(t.row - t2.row) == 1:
                has_v = true
        if has_h and has_v:
            t.tile_type = Constants.TileType.CROSS
        elif has_h:
            t.tile_type = Constants.TileType.HORIZONTAL
        elif has_v:
            t.tile_type = Constants.TileType.VERTICAL
        else:
            t.tile_type = Constants.TileType.DEFAULT

# ── Tile queries ──────────────────────────────────────────────────────────────

func get_tile(row: int, col: int):
    if row < 0 or row >= Constants.LEVEL_MAP_SIZE or \
       col < 0 or col >= Constants.LEVEL_MAP_SIZE:
        return null
    return tile_grid[row][col]

## Nearest tile to a world-space point (within one tile width).
func nearest_tile(world_pos: Vector2):
    var best = null
    var best_d := Constants.WORLD_TILE_SIZE
    for t in tiles:
        var d := world_pos.distance_to(t.global_position)
        if d < best_d:
            best_d = d
            best = t
    return best

## True if the grapheme's bounding rect overlaps any tile region.
func is_point_in_grid(world_pos: Vector2, grapheme: Grapheme) -> bool:
    var g_rect := _world_rect(world_pos, grapheme)
    for t in tiles:
        if _tile_rect(t).intersects(g_rect):
            return true
    return false

func _tile_rect(t: Tile) -> Rect2:
    var hw := Constants.WORLD_TILE_SIZE / 2.0
    return Rect2(t.global_position - Vector2(hw, hw),
                 Vector2(Constants.WORLD_TILE_SIZE, Constants.WORLD_TILE_SIZE))

func _world_rect(world_pos: Vector2, grapheme: Grapheme) -> Rect2:
    var local_r := grapheme.get_bounding_rect()
    return Rect2(world_pos + local_r.position, local_r.size)

# ── Highlight & Rotate ────────────────────────────────────────────────────────

## Show which tiles would be occupied and auto-rotate the grapheme.
## Called every frame while dragging over the grid.
func highlight_tile(world_pos: Vector2, grapheme: Grapheme) -> void:
    # Clear previous highlights
    for t in tiles:
        if t.tile_state == Constants.TileState.SELECTED:
            t.set_state(Constants.TileState.IDLE)

    var occupied := _candidate_tiles(world_pos, grapheme)
    for t in occupied:
        if t.tile_state == Constants.TileState.IDLE:
            t.set_state(Constants.TileState.SELECTED)

## Auto-rotate + highlight — called while dragging inside the grid.
## Mirrors rotateGraphemeInGrid:withTarget:withGrapheme: in AMGGrid.m
func rotate_grapheme_in_grid(_delta: Vector2, target_pos: Vector2, grapheme: Grapheme) -> void:
    var anchor = nearest_tile(target_pos)
    if anchor:
        match anchor.tile_type:
            Constants.TileType.HORIZONTAL:
                grapheme.set_direction(Constants.GraphemeDirection.HORIZONTAL_RIGHT)
            Constants.TileType.VERTICAL:
                grapheme.set_direction(Constants.GraphemeDirection.VERTICAL_DOWN)
            # CROSS: preserve current direction
    highlight_tile(target_pos, grapheme)

# ── Snap to tile ──────────────────────────────────────────────────────────────

## Try to place grapheme on the grid. Returns true on success.
## Mirrors snapToTile: in AMGGrid.m
func snap_to_tile(grapheme: Grapheme) -> bool:
    var candidates := _candidate_tiles(grapheme.global_position, grapheme)
    if candidates.size() != grapheme.length:
        return false

    var anchor: Tile = candidates[0]

    # Direction must be compatible with tile type
    match anchor.tile_type:
        Constants.TileType.HORIZONTAL:
            if grapheme.grapheme_dir != Constants.GraphemeDirection.HORIZONTAL_RIGHT:
                return false
        Constants.TileType.VERTICAL:
            if grapheme.grapheme_dir != Constants.GraphemeDirection.VERTICAL_DOWN:
                return false

    # Snap position to anchor tile
    grapheme.global_position = anchor.global_position
    grapheme.start_tile_row  = anchor.row
    grapheme.start_tile_col  = anchor.col

    # Assign tiles
    for i in range(candidates.size()):
        var t: Tile = candidates[i]
        t.grapheme     = grapheme
        t.letter_index = i
        t.set_state(Constants.TileState.FILLED)

    grapheme.is_placed      = true
    grapheme.grapheme_state = Constants.GraphemeState.PLACED
    grapheme.z_index        = Constants.WorldLayer.GRID + 1
    return true

## Compute the sequence of tiles that would be occupied by grapheme at world_pos.
func _candidate_tiles(world_pos: Vector2, grapheme: Grapheme) -> Array:
    var anchor = nearest_tile(world_pos)
    if not anchor:
        return []

    var result: Array = []
    for i in range(grapheme.length):
        var r: int = anchor.row
        var c: int = anchor.col
        if grapheme.grapheme_dir == Constants.GraphemeDirection.HORIZONTAL_RIGHT:
            c += i
        else:
            r += i
        var t = get_tile(r, c)
        if t == null:
            return []
        # Tile must be free (or already owned by this grapheme)
        if t.tile_state != Constants.TileState.IDLE and \
           t.tile_state != Constants.TileState.SELECTED and \
           t.grapheme != grapheme:
            return []
        result.append(t)
    return result

# ── Remove from grid ──────────────────────────────────────────────────────────

func remove_from_grid(grapheme: Grapheme) -> void:
    for t in tiles:
        if t.grapheme == grapheme and t.tile_state != Constants.TileState.VALIDATED:
            t.grapheme     = null
            t.letter_index = 0
            t.set_state(Constants.TileState.IDLE)
    grapheme.is_placed      = false
    grapheme.grapheme_state = Constants.GraphemeState.IDLE

## Restore FILLED state for tiles marked INVALID that belong to grapheme.
func reset_invalid_tiles(grapheme: Grapheme) -> void:
    for t in tiles:
        if t.grapheme == grapheme and t.tile_state == Constants.TileState.INVALID:
            t.set_state(Constants.TileState.FILLED)

# ── Word checking ─────────────────────────────────────────────────────────────

## Main word-check entry point — mirrors checkForValidWords in AMGGrid.m.
## Returns true if at least one new valid word was found.
func check_for_valid_words() -> bool:
    _valid_words.clear()
    _invalid_words.clear()

    # ── Horizontal: for each row scan columns ──────────────────────────────
    for row in range(Constants.LEVEL_MAP_SIZE):
        var word := WordData.new()
        var last_col := -1
        for col in range(Constants.LEVEL_MAP_SIZE):
            var t: Tile = tile_grid[row][col]
            if t == null:
                _try_add_word(word)
                word = WordData.new()
                last_col = -1
                continue
            if t.tile_state == Constants.TileState.FILLED or \
               t.tile_state == Constants.TileState.INVALID:
                if last_col >= 0 and col - last_col > 1:
                    _try_add_word(word)
                    word = WordData.new()
                word.add_grapheme(t.grapheme, Constants.GraphemeDirection.HORIZONTAL_RIGHT, t)
                last_col = col
            else:
                _try_add_word(word)
                word = WordData.new()
                last_col = -1
        _try_add_word(word)

    # ── Vertical: for each column scan rows ────────────────────────────────
    for col in range(Constants.LEVEL_MAP_SIZE):
        var word := WordData.new()
        var last_row := -1
        for row in range(Constants.LEVEL_MAP_SIZE):
            var t: Tile = tile_grid[row][col]
            if t == null:
                _try_add_word(word)
                word = WordData.new()
                last_row = -1
                continue
            if t.tile_state == Constants.TileState.FILLED or \
               t.tile_state == Constants.TileState.INVALID:
                if last_row >= 0 and row - last_row > 1:
                    _try_add_word(word)
                    word = WordData.new()
                word.add_grapheme(t.grapheme, Constants.GraphemeDirection.VERTICAL_DOWN, t)
                last_row = row
            else:
                _try_add_word(word)
                word = WordData.new()
                last_row = -1
        _try_add_word(word)

    _mark_invalid_words()
    _validate_tiles()
    _disable_isolated_tiles()
    _update_stats()

    number_of_words += _valid_words.size()
    _all_words.append_array(_valid_words)

    if not _valid_words.is_empty():
        var total_score := 0
        for w in _valid_words:
            total_score += w.score
        score += total_score
        score_updated.emit(total_score)
        words_validated.emit(_valid_words.duplicate())
        return true

    return false

func _try_add_word(word: WordData) -> void:
    if word.length < 2:
        return
    # Clone so the iterating WordData can be reused
    var copy := WordData.new()
    copy.graphemes   = word.graphemes.duplicate()
    copy.tiles       = word.tiles.duplicate()
    copy.word_string = word.word_string
    copy.direction   = word.direction
    copy.length      = word.length
    copy.start_row   = word.start_row
    copy.start_col   = word.start_col

    if Leveller.is_word_valid(word.word_string):
        _valid_words.append(copy)
    else:
        _invalid_words.append(copy)

func _mark_invalid_words() -> void:
    for word in _invalid_words:
        for t in word.tiles:
            if t.tile_state != Constants.TileState.VALIDATED:
                t.set_state(Constants.TileState.INVALID)

func _validate_tiles() -> void:
    for word in _valid_words:
        for t in word.tiles:
            t.set_state(Constants.TileState.VALIDATED)
            if t.grapheme:
                t.grapheme.grapheme_state = Constants.GraphemeState.DISABLED
    WordData.check_bonus_tiles(_valid_words)

func _disable_isolated_tiles() -> void:
    # Tiles disabled by a validated grapheme but marked INVALID
    for t in tiles:
        if t.grapheme and t.grapheme.grapheme_state == Constants.GraphemeState.DISABLED:
            if t.tile_state == Constants.TileState.INVALID:
                t.set_state(Constants.TileState.INVALID_DISABLED)

func _update_stats() -> void:
    for word in _valid_words:
        if word.score > GameStats.best_word_score:
            GameStats.best_word_score = word.score
            GameStats.best_word       = word.word_string
            GameStats.new_best_word   = true

# ── Level checks ──────────────────────────────────────────────────────────────

func tile_count() -> int:
    return tiles.size()

func tiles_used_count() -> int:
    var n := 0
    for t in tiles:
        if t.tile_state == Constants.TileState.FILLED or \
           t.tile_state == Constants.TileState.VALIDATED:
            n += 1
    return n

func all_tiles_validated() -> bool:
    for t in tiles:
        if t.tile_state != Constants.TileState.VALIDATED and \
           t.tile_state != Constants.TileState.DISABLED:
            return false
    return true
