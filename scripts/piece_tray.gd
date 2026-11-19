## piece_tray.gd
## Single horizontal tray displaying all puzzle pieces.
## Scrolls left/right when pieces don't fit in one viewport width.
class_name PieceTray
extends Node2D

var _pieces: Array = []
var _placed: Array = []
var _piece_slots: Dictionary = {}   # Grapheme → local Vector2 in container
var _piece_slot_sizes: Dictionary = {} # Grapheme → reserved size for any rotation

var _viewport_width: float = 1080.0
var _scroll_offset: float = 0.0

const PIECE_PADDING: float = 30.0

@onready var _container: Node2D = $PiecesContainer

# ── Initialization ────────────────────────────────────────────────────────────

func initialize(pos: Vector2, viewport_width: float) -> void:
	position        = pos
	_viewport_width = viewport_width

func load_pieces(pieces: Array) -> void:
	_pieces = pieces.duplicate()
	_piece_slots.clear()
	_piece_slot_sizes.clear()
	var x := PIECE_PADDING
	var row_h := 0.0
	var current_row: Array = []
	var rows: Array = []

	for piece in pieces:
		var slot_size := _get_rotation_envelope(piece)
		# Wrap to next row when piece doesn't fit remaining width
		if not current_row.is_empty() and x + slot_size.x + PIECE_PADDING > _viewport_width:
			rows.append({"pieces": current_row, "height": row_h})
			current_row = []
			x = PIECE_PADDING
			row_h = 0.0
		current_row.append({"piece": piece, "position": Vector2(x, 0.0), "size": slot_size})
		x += slot_size.x + PIECE_PADDING
		row_h = max(row_h, slot_size.y)

	if not current_row.is_empty():
		rows.append({"pieces": current_row, "height": row_h})

	var y := 0.0
	for row in rows:
		for slot in row["pieces"]:
			var piece: Grapheme = slot["piece"]
			var slot_position: Vector2 = slot["position"]
			var slot_size: Vector2 = slot["size"]
			_piece_slots[piece] = Vector2(slot_position.x, y)
			_piece_slot_sizes[piece] = Vector2(slot_size.x, row["height"])
		y += row["height"] + PIECE_PADDING

	for piece in pieces:
		if piece.get_parent():
			piece.get_parent().remove_child(piece)
		_container.add_child(piece)
		_position_piece_in_slot(piece)

func _get_rotation_envelope(piece: Grapheme) -> Vector2:
	var max_width := 1
	var max_height := 1
	for rotation in piece.piece_shape.rotation_count():
		var cells: Array = piece.piece_shape.get_cells(rotation)
		var max_row := 0
		var max_col := 0
		for cell in cells:
			var offset := cell as Vector2i
			max_row = maxi(max_row, offset.x)
			max_col = maxi(max_col, offset.y)
		max_height = maxi(max_height, max_row + 1)
		max_width = maxi(max_width, max_col + 1)
	return Vector2(max_width, max_height) * Constants.WORLD_TILE_SIZE

func _position_piece_in_slot(piece: Grapheme) -> void:
	var rect := piece.get_bounding_rect()
	var slot_position: Vector2 = _piece_slots.get(piece, Vector2.ZERO)
	var slot_size: Vector2 = _piece_slot_sizes.get(piece, Vector2.ZERO)
	piece.position = slot_position + slot_size * 0.5 - rect.get_center()

# ── Public API ────────────────────────────────────────────────────────────────

func get_available_pieces() -> Array:
	return _pieces.filter(func(p): return not _placed.has(p))

func detach_piece(g: Grapheme) -> void:
	if g.get_parent() == _container:
		_container.remove_child(g)

func return_piece(g: Grapheme) -> void:
	_placed.erase(g)
	if g.get_parent() != _container:
		if g.get_parent():
			g.get_parent().remove_child(g)
		_container.add_child(g)
	_position_piece_in_slot(g)

func reposition_piece(g: Grapheme) -> void:
	if g.get_parent() == _container:
		_position_piece_in_slot(g)

func mark_placed(g: Grapheme) -> void:
	if not _placed.has(g):
		_placed.append(g)

func all_placed() -> bool:
	return _placed.size() >= _pieces.size()

# ── Scroll ────────────────────────────────────────────────────────────────────

func scroll_by(_delta_x: float) -> void:
	pass  # Wrap layout — no horizontal scrolling
