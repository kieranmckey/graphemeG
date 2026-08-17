## grid.gd
## Gameplay grid for arbitrary shapes loaded from grid_shapes.json.
class_name Grid
extends Node2D

signal words_validated(all_valid: bool, invalid_cells: Array)

var tile_grid: Dictionary = {}   # Vector2i(row, col) -> Tile
var tiles: Array = []

# -- Build -----------------------------------------------------------------

func build(shape_data: Dictionary, origin: Vector2) -> void:
	for t in tiles:
		if is_instance_valid(t):
			t.queue_free()
	tiles.clear()
	tile_grid.clear()

	var tile_scene := load("res://scenes/components/tile.tscn") as PackedScene
	for cell in shape_data.get("cells", []):
		var row: int = cell[0]
		var col: int = cell[1]
		var tile: Tile = tile_scene.instantiate()
		tile.position = Vector2(
			origin.x + col * Constants.WORLD_TILE_SIZE,
			origin.y + row * Constants.WORLD_TILE_SIZE)
		tile.row = row
		tile.col = col
		add_child(tile)
		tile_grid[Vector2i(row, col)] = tile
		tiles.append(tile)

	_classify_tiles()

func _classify_tiles() -> void:
	for t in tiles:
		var has_h := tile_grid.has(Vector2i(t.row, t.col - 1)) or \
					 tile_grid.has(Vector2i(t.row, t.col + 1))
		var has_v := tile_grid.has(Vector2i(t.row - 1, t.col)) or \
					 tile_grid.has(Vector2i(t.row + 1, t.col))
		if has_h and has_v:
			t.tile_type = Constants.TileType.CROSS
		elif has_h:
			t.tile_type = Constants.TileType.HORIZONTAL
		elif has_v:
			t.tile_type = Constants.TileType.VERTICAL
		else:
			t.tile_type = Constants.TileType.DEFAULT

# -- Tile queries ----------------------------------------------------------

func get_tile(row: int, col: int) -> Tile:
	return tile_grid.get(Vector2i(row, col), null)

func nearest_tile(world_pos: Vector2) -> Tile:
	var best: Tile = null
	var best_d := Constants.WORLD_TILE_SIZE
	for t in tiles:
		var d := world_pos.distance_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best

func is_point_in_grid(world_pos: Vector2, grapheme: Grapheme) -> bool:
	var r := grapheme.get_bounding_rect()
	var g_rect := Rect2(world_pos + r.position, r.size)
	for t in tiles:
		var hw := Constants.WORLD_TILE_SIZE / 2.0
		if Rect2(t.global_position - Vector2(hw, hw),
				 Vector2(Constants.WORLD_TILE_SIZE, Constants.WORLD_TILE_SIZE)).intersects(g_rect):
			return true
	return false

func all_pieces_placed() -> bool:
	for t in tiles:
		if t.tile_state == Constants.TileState.IDLE or \
		   t.tile_state == Constants.TileState.SELECTED:
			return false
	return true

# -- Highlight -------------------------------------------------------------

func highlight_tile(world_pos: Vector2, grapheme: Grapheme) -> void:
	clear_highlights()
	for t in _candidate_tiles(world_pos, grapheme):
		if t.tile_state == Constants.TileState.IDLE:
			t.set_state(Constants.TileState.SELECTED)

func clear_highlights() -> void:
	for t in tiles:
		if t.tile_state == Constants.TileState.SELECTED:
			t.set_state(Constants.TileState.IDLE)

# -- Snap / Remove ---------------------------------------------------------

func snap_to_tile(grapheme: Grapheme) -> bool:
	var candidates := _candidate_tiles(grapheme.global_position, grapheme)
	if candidates.size() != grapheme.cells.size():
		return false

	# candidates[0] is the tile for cells[0]; back-compute the piece-local (0,0) origin.
	var first: Vector2i = grapheme.cells[0]
	var anchor: Tile = candidates[0]
	grapheme.global_position = anchor.global_position \
		- Vector2(first.y * Constants.WORLD_TILE_SIZE, first.x * Constants.WORLD_TILE_SIZE)
	grapheme.start_tile_row  = anchor.row - first.x
	grapheme.start_tile_col  = anchor.col - first.y

	for i in range(candidates.size()):
		var t: Tile = candidates[i]
		t.grapheme     = grapheme
		t.letter_index = i
		t.set_state(Constants.TileState.FILLED)

	grapheme.is_placed      = true
	grapheme.grapheme_state = Constants.GraphemeState.PLACED
	grapheme.z_index        = Constants.WorldLayer.GRID + 1
	return true

func remove_from_grid(grapheme: Grapheme) -> void:
	for t in tiles:
		if t.grapheme == grapheme:
			t.grapheme     = null
			t.letter_index = 0
			t.set_state(Constants.TileState.IDLE)
	grapheme.is_placed      = false
	grapheme.grapheme_state = Constants.GraphemeState.IDLE

## Candidates for a 2-D piece: snaps so cells[0] aligns with its nearest grid tile.
func _candidate_tiles(world_pos: Vector2, grapheme: Grapheme) -> Array:
	if grapheme.cells.is_empty():
		return []
	var first: Vector2i = grapheme.cells[0]
	var first_world := world_pos + Vector2(first.y * Constants.WORLD_TILE_SIZE,
										   first.x * Constants.WORLD_TILE_SIZE)
	var anchor: Tile = nearest_tile(first_world)
	if not anchor:
		return []
	var result: Array = []
	for off in grapheme.cells:
		var v := off as Vector2i
		var t: Tile = get_tile(anchor.row + (v.x - first.x), anchor.col + (v.y - first.y))
		if t == null:
			return []
		if t.tile_state != Constants.TileState.IDLE and \
		   t.tile_state != Constants.TileState.SELECTED and \
		   t.grapheme != grapheme:
			return []
		result.append(t)
	return result

# -- Model-solution check --------------------------------------------------

## True if the placed piece's origin and rotation match the stored solution entry.
func check_piece_vs_solution(grapheme: Grapheme, sol: Dictionary) -> bool:
	if not grapheme.is_placed:
		return false
	var origin: Vector2i = sol["origin"]
	return grapheme.rotation_index == sol["rotation"] and \
		   grapheme.start_tile_row  == origin.x and \
		   grapheme.start_tile_col  == origin.y

# -- Word validation -------------------------------------------------------

func check_for_valid_words() -> void:
	for t in tiles:
		if t.tile_state == Constants.TileState.INVALID:
			t.set_state(Constants.TileState.FILLED)

	var invalid_cells: Array = []
	for row in _unique_rows():
		_scan_run(row, _unique_cols(), true, invalid_cells)
	for col in _unique_cols():
		_scan_run(col, _unique_rows(), false, invalid_cells)

	words_validated.emit(invalid_cells.is_empty(), invalid_cells)

func _unique_rows() -> Array:
	var seen: Dictionary = {}
	for t in tiles: seen[t.row] = true
	var arr := seen.keys(); arr.sort(); return arr

func _unique_cols() -> Array:
	var seen: Dictionary = {}
	for t in tiles: seen[t.col] = true
	var arr := seen.keys(); arr.sort(); return arr

func _scan_run(primary: int, secondaries: Array, is_row: bool, invalid_cells: Array) -> void:
	var run_word  := ""
	var run_tiles: Array = []
	for sec in secondaries:
		var t: Tile = get_tile(primary if is_row else sec,
							   sec     if is_row else primary)
		var occupied: bool = t != null and \
			(t.tile_state == Constants.TileState.FILLED or
			 t.tile_state == Constants.TileState.VALIDATED)
		if occupied:
			run_word += t.grapheme.letters[t.letter_index] if t.grapheme else "?"
			run_tiles.append(t)
		else:
			_try_validate_run(run_word, run_tiles, invalid_cells)
			run_word = ""; run_tiles = []
	_try_validate_run(run_word, run_tiles, invalid_cells)

func _try_validate_run(word: String, run_tiles: Array, invalid_cells: Array) -> void:
	if run_tiles.size() < 2:
		return
	if Leveller.is_word_valid(word):
		for t in run_tiles:
			t.set_state(Constants.TileState.VALIDATED)
	else:
		for t in run_tiles:
			if t.tile_state != Constants.TileState.VALIDATED:
				t.set_state(Constants.TileState.INVALID)
				invalid_cells.append(t)
