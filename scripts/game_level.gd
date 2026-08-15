## game_level.gd
## Main game scene -- loads puzzle, splits into pieces, handles drag/tap/snap.
## Scene: res://scenes/game_level.tscn
extends Node2D

# -- State -----------------------------------------------------------------

var _model_solution: Array = []           # Array of placement dicts from PieceSplitter
var _piece_to_solution: Dictionary = {}   # Grapheme -> solution dict
var _piece_tray: PieceTray = null
var _level_over: bool = false

var _touched_piece: Grapheme = null       # piece under current touch (before tap vs drag)
var _selected_piece: Grapheme = null      # piece being actively dragged
var _touch_start_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false

var _tray_swipe_start: Vector2 = Vector2.ZERO
var _is_tray_swiping: bool = false

# -- Node refs -------------------------------------------------------------

@onready var _grid:      Grid     = $Grid
@onready var _hud:       HUD      = $HUD
@onready var _tray_root: Node2D   = $TrayRoot

# -- Lifecycle -------------------------------------------------------------

func _ready() -> void:
	_start_level()

func _start_level() -> void:
	var cfg: Dictionary      = Leveller.get_level_config()
	var shape_name: String = cfg.get("grid_shape", "digit_1")
	var shape_data: Dictionary = Leveller.load_grid_shape(shape_name)
	var puzzle: Dictionary     = Leveller.get_puzzle(shape_name)

	# Centre grid horizontally, top-pad vertically
	var vp      := get_viewport_rect().size
	var g_cols: int = shape_data.get("cols", 1)
	var g_rows: int = shape_data.get("rows", 1)
	var origin  := Vector2(
		(vp.x - g_cols * Constants.WORLD_TILE_SIZE) * 0.5 + Constants.WORLD_TILE_SIZE * 0.5,
		Constants.BORDER_SIZE + Constants.WORLD_TILE_SIZE * 0.5)

	_grid.build(shape_data, origin)

	_hud.next_level_pressed.connect(_go_to_next_level)
	_hud.redo_level_pressed.connect(_redo_level)
	_hud.quit_pressed.connect(_quit_to_menu)
	_grid.words_validated.connect(_on_words_validated)

	# Split puzzle into pieces
	var library     := PieceShape.load_library()
	var rng         := RandomNumberGenerator.new()
	rng.randomize()
	var allowed: Array = cfg.get("allowed_piece_ids", [])
	_model_solution = PieceSplitter.split(
		shape_data.get("cells", []),
		puzzle.get("fill", []),
		library, rng, allowed)

	# Instantiate piece nodes (setup before add_child so _ready builds visuals)
	var piece_scene := load("res://scenes/components/grapheme.tscn") as PackedScene
	var pieces: Array = []
	for i in range(_model_solution.size()):
		var sol: Dictionary = _model_solution[i]
		var piece: Grapheme = piece_scene.instantiate()
		var rand_rot: int = rng.randi_range(0, (sol["shape"] as PieceShape).rotation_count() - 1)
		piece.setup(sol["shape"], rand_rot, sol["letters"])
		add_child(piece)
		_piece_to_solution[piece] = sol
		pieces.append(piece)

	# Create tray below grid
	var tray_scene := load("res://scenes/components/piece_tray.tscn") as PackedScene
	_piece_tray = tray_scene.instantiate()
	_tray_root.add_child(_piece_tray)
	var tray_y := origin.y + g_rows * Constants.WORLD_TILE_SIZE + Constants.BORDER_SIZE * 2.0
	_piece_tray.initialize(Vector2(0.0, tray_y), vp.x)
	_piece_tray.load_pieces(pieces)

# -- Input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _level_over:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag((event as InputEventScreenDrag).position,
					 (event as InputEventScreenDrag).relative)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_start_pos  = event.position
		_is_dragging      = false
		_is_tray_swiping  = false
		_touched_piece    = _piece_at(event.position)
		_selected_piece   = null
		if not _touched_piece:
			_tray_swipe_start = event.position
			_is_tray_swiping  = true
	else:
		if _selected_piece and _is_dragging:
			_end_drag()
		elif _touched_piece and not _is_dragging:
			_tap_piece(_touched_piece)
		elif _is_tray_swiping:
			var dx := event.position.x - _tray_swipe_start.x
			if abs(dx) >= Constants.SWIPE_MIN_DISTANCE and _piece_tray:
				_piece_tray.scroll_by(dx)
		_touched_piece   = null
		_selected_piece  = null
		_is_dragging     = false
		_is_tray_swiping = false

func _handle_drag(pos: Vector2, delta: Vector2) -> void:
	# Promote touch to drag once the finger moves enough
	if _touched_piece and not _is_dragging:
		if pos.distance_to(_touch_start_pos) >= Constants.TAP_MAX_DISTANCE:
			_is_dragging     = true
			_is_tray_swiping = false
			_begin_drag(_touched_piece, pos)
		return

	if not _selected_piece:
		return
	_selected_piece.global_position += delta
	if _grid.is_point_in_grid(_selected_piece.global_position, _selected_piece):
		_grid.highlight_tile(_selected_piece.global_position, _selected_piece)
	else:
		_grid.clear_highlights()

# -- Tap -------------------------------------------------------------------

func _tap_piece(g: Grapheme) -> void:
	var was_placed: bool = g.is_placed
	var old_row: int     = g.start_tile_row
	var old_col: int     = g.start_tile_col

	if was_placed:
		_grid.remove_from_grid(g)

	g.tap_rotate()

	if was_placed:
		var anchor: Tile = _grid.get_tile(old_row, old_col)
		if anchor:
			g.global_position  = anchor.global_position
			g.start_tile_row   = old_row
			g.start_tile_col   = old_col
			if _grid.snap_to_tile(g):
				_check_piece_vs_solution(g)
				if _grid.all_pieces_placed():
					_grid.check_for_valid_words()
				return
		_return_to_tray(g)

# -- Drag ------------------------------------------------------------------

func _piece_at(screen_pos: Vector2) -> Grapheme:
	if _piece_tray:
		for piece in _piece_tray.get_available_pieces():
			if piece.is_selectable and \
			   piece.get_bounding_rect().has_point(piece.to_local(screen_pos)):
				return piece
	for t in _grid.tiles:
		if t.grapheme == null:
			continue
		var g: Grapheme = t.grapheme
		if g.grapheme_state == Constants.GraphemeState.DISABLED:
			continue
		if g.get_bounding_rect().has_point(g.to_local(screen_pos)):
			return g
	return null

func _begin_drag(g: Grapheme, pos: Vector2) -> void:
	_selected_piece     = g
	g.pre_move_position = g.global_position
	g.set_selected(true)
	# Reparent to scene root for top-layer rendering
	if g.get_parent() != self:
		if g.get_parent():
			g.get_parent().remove_child(g)
		add_child(g)
	if g.is_placed:
		_grid.remove_from_grid(g)
	else:
		_piece_tray.detach_piece(g)
	g.global_position = pos

func _end_drag() -> void:
	var g: Grapheme = _selected_piece
	_selected_piece = null
	if not is_instance_valid(g):
		return

	var placed := false
	if _grid.is_point_in_grid(g.global_position, g):
		placed = _grid.snap_to_tile(g)
		if placed:
			_piece_tray.mark_placed(g)
			_check_piece_vs_solution(g)
			if _grid.all_pieces_placed():
				_grid.check_for_valid_words()

	if not placed:
		_return_to_tray(g)

	g.set_selected(false)

func _return_to_tray(g: Grapheme) -> void:
	if g.get_parent() and g.get_parent() != _piece_tray:
		g.get_parent().remove_child(g)
	g.is_placed      = false
	g.grapheme_state = Constants.GraphemeState.IDLE
	g.z_index        = Constants.WorldLayer.GRAPHEME
	g.is_selectable  = true
	_piece_tray.return_piece(g)

# -- Solution check --------------------------------------------------------

## Immediately mark tiles VALIDATED when the piece matches the model solution.
func _check_piece_vs_solution(g: Grapheme) -> void:
	if not _piece_to_solution.has(g):
		return
	var sol: Dictionary = _piece_to_solution[g]
	if _grid.check_piece_vs_solution(g, sol):
		for off in g.cells:
			var t: Tile = _grid.get_tile(g.start_tile_row + (off as Vector2i).x,
										 g.start_tile_col + (off as Vector2i).y)
			if t:
				t.set_state(Constants.TileState.VALIDATED)

# -- Grid signal -----------------------------------------------------------

func _on_words_validated(all_valid: bool, _invalid_cells: Array) -> void:
	_level_over = all_valid
	_hud.show_level_end(all_valid)

# -- Navigation ------------------------------------------------------------

func _go_to_next_level() -> void:
	Leveller.level = (Leveller.level + 1) % Constants.MAX_LEVELS
	get_tree().reload_current_scene()

func _redo_level() -> void:
	get_tree().reload_current_scene()

func _quit_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
