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
var pivot_letter_index: int = 0
var is_placed: bool = false
var is_selectable: bool = true
var is_locked: bool = false
var is_selected: bool = false
var grapheme_state: Constants.GraphemeState = Constants.GraphemeState.IDLE
var pre_move_position: Vector2 = Vector2.ZERO
var start_tile_row: int = 0
var start_tile_col: int = 0
var drag_anchor: Vector2i = Vector2i.ZERO  # piece cell beneath the finger during drag

# -- Node refs -------------------------------------------------------------

@onready var _letters_root: Node2D = $LetterSprites

# -- Setup -----------------------------------------------------------------

## Call before add_child so _ready() can build visuals immediately.
func setup(shape: PieceShape, initial_rotation: int, p_letters: Array,
		source_rotation: int = 0) -> void:
	piece_shape    = shape
	rotation_index = initial_rotation
	letters        = shape.remap_letters(p_letters, source_rotation, initial_rotation)
	cells          = shape.get_cells(rotation_index)
	pivot_letter_index = cells.find(shape.remap_cell(
		shape.get_pivot_cell(source_rotation), source_rotation, initial_rotation))
	if pivot_letter_index < 0:
		pivot_letter_index = 0
	drag_anchor = cells[pivot_letter_index] if not cells.is_empty() else Vector2i.ZERO

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
		cell_node.setup(letters[i].to_lower(), tile_tex, font, Constants.GRAPHEME_TILE_FONT_SIZE)
		_letters_root.add_child(cell_node)
		if is_locked:
			cell_node.show_border(Color(0.2, 0.9, 0.3))

## Correctly placed piece: green border, no further interaction.
func lock() -> void:
	is_locked = true
	is_selectable = false
	grapheme_state = Constants.GraphemeState.DISABLED
	for cell_node in _letters_root.get_children():
		if cell_node is LetterCell:
			(cell_node as LetterCell).show_border(Color(0.2, 0.9, 0.3))

# -- Rotation --------------------------------------------------------------

func tap_rotate() -> void:
	if piece_shape == null:
		return
	var next_rotation := (rotation_index + 1) % piece_shape.rotation_count()
	var old_pivot: Vector2i = cells[pivot_letter_index] if not cells.is_empty() else Vector2i.ZERO
	var new_pivot: Vector2i = piece_shape.remap_cell(old_pivot, rotation_index, next_rotation)
	var old_center := _cells_center(cells)
	letters = piece_shape.remap_letters(letters, rotation_index, next_rotation)
	rotation_index = next_rotation
	cells = piece_shape.get_cells(rotation_index)
	pivot_letter_index = cells.find(new_pivot)
	if pivot_letter_index < 0:
		pivot_letter_index = 0
	global_position += old_center - _cells_center(cells)
	drag_anchor = cells[pivot_letter_index] if not cells.is_empty() else Vector2i.ZERO
	_build_visuals()

# Centre of the cells' bounding box in local pixels.
func _cells_center(p_cells: Array) -> Vector2:
	if p_cells.is_empty():
		return Vector2.ZERO
	var lo := Vector2i(p_cells[0])
	var hi := lo
	for c in p_cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Vector2(lo.y + hi.y, lo.x + hi.x) * 0.5 * Constants.WORLD_TILE_SIZE

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
