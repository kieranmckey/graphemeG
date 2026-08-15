## grapheme.gd
## A draggable 2-D letter-piece. Shape defined by PieceShape; supports tap-to-rotate.
## Scene: res://scenes/components/grapheme.tscn
class_name Grapheme
extends Node2D

# -- Data ------------------------------------------------------------------

var piece_shape: PieceShape = null
var rotation_index: int = 0
var cells: Array = []          # current rotation's Array[Vector2i] offsets (row, col)
var letters: Array = []        # one String per cell, matching cells order
var is_placed: bool = false
var is_selectable: bool = true
var is_selected: bool = false
var grapheme_state: Constants.GraphemeState = Constants.GraphemeState.IDLE
var pre_move_position: Vector2 = Vector2.ZERO
var start_tile_row: int = 0
var start_tile_col: int = 0

# -- Node refs -------------------------------------------------------------

@onready var _letters_root: Node2D = $LetterSprites

# -- Setup -----------------------------------------------------------------

## Call before add_child so _ready() can build visuals immediately.
func setup(shape: PieceShape, initial_rotation: int, p_letters: Array) -> void:
	piece_shape    = shape
	rotation_index = initial_rotation
	letters        = p_letters
	cells          = shape.get_cells(rotation_index)

func _ready() -> void:
	if piece_shape:
		_build_visuals()

func _build_visuals() -> void:
	for child in _letters_root.get_children():
		child.queue_free()
	var font: Font = load(Constants.FONT_PATH)
	var tile_tex: Texture2D = load(Constants.GRAPHEME_TILES_DIR + "tile_morpheme.png")
	for i in range(cells.size()):
		var off: Vector2i = cells[i]
		var cell_node := LetterCell.new()
		# off.x = row -> Y, off.y = col -> X
		cell_node.position = Vector2(off.y * Constants.WORLD_TILE_SIZE,
									 off.x * Constants.WORLD_TILE_SIZE)
		cell_node.setup(letters[i].to_upper(), tile_tex, font, Constants.GRAPHEME_TILE_FONT_SIZE)
		_letters_root.add_child(cell_node)

# -- Rotation --------------------------------------------------------------

func tap_rotate() -> void:
	if piece_shape == null:
		return
	rotation_index = (rotation_index + 1) % piece_shape.rotation_count()
	cells = piece_shape.get_cells(rotation_index)
	_build_visuals()

# -- Bounding rect (local space) -------------------------------------------

func get_bounding_rect() -> Rect2:
	var hw := Constants.WORLD_TILE_SIZE / 2.0
	if cells.is_empty():
		return Rect2(-hw, -hw, Constants.WORLD_TILE_SIZE, Constants.WORLD_TILE_SIZE)
	var min_r: int = (cells[0] as Vector2i).x
	var max_r: int = min_r
	var min_c: int = (cells[0] as Vector2i).y
	var max_c: int = min_c
	for off in cells:
		var v := off as Vector2i
		min_r = min(min_r, v.x); max_r = max(max_r, v.x)
		min_c = min(min_c, v.y); max_c = max(max_c, v.y)
	return Rect2(
		min_c * Constants.WORLD_TILE_SIZE - hw,
		min_r * Constants.WORLD_TILE_SIZE - hw,
		(max_c - min_c + 1) * Constants.WORLD_TILE_SIZE,
		(max_r - min_r + 1) * Constants.WORLD_TILE_SIZE)

# -- Selection -------------------------------------------------------------

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected:
		grapheme_state = Constants.GraphemeState.SELECTED
		z_index = Constants.WorldLayer.PANELS
	else:
		grapheme_state = Constants.GraphemeState.IDLE
		z_index = Constants.WorldLayer.GRAPHEME
