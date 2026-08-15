## piece_tray.gd
## Single horizontal tray displaying all puzzle pieces.
## Scrolls left/right when pieces don't fit in one viewport width.
class_name PieceTray
extends Node2D

var _pieces: Array = []
var _placed: Array = []
var _piece_slots: Dictionary = {}   # Grapheme → local Vector2 in container

var _viewport_width: float = 1080.0
var _total_width: float = 0.0
var _scroll_offset: float = 0.0

const PIECE_PADDING: float = 30.0

@onready var _container: Node2D = $PiecesContainer

# ── Initialization ────────────────────────────────────────────────────────────

func initialize(pos: Vector2, viewport_width: float) -> void:
	position        = pos
	_viewport_width = viewport_width

func load_pieces(pieces: Array) -> void:
	_pieces = pieces.duplicate()
	var x := PIECE_PADDING
	var y := 0.0
	var row_h := 0.0

	for piece in pieces:
		var rect: Rect2 = piece.get_bounding_rect()
		# Wrap to next row when piece doesn't fit remaining width
		if x > PIECE_PADDING and x + rect.size.x + PIECE_PADDING > _viewport_width:
			y += row_h + PIECE_PADDING
			x = PIECE_PADDING
			row_h = 0.0
		var slot := Vector2(x - rect.position.x, y - rect.position.y)
		_piece_slots[piece] = slot
		x += rect.size.x + PIECE_PADDING
		row_h = max(row_h, rect.size.y)
		if piece.get_parent():
			piece.get_parent().remove_child(piece)
		_container.add_child(piece)
		piece.position = slot

	_total_width = x

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
	g.position = _piece_slots.get(g, Vector2.ZERO)

func mark_placed(g: Grapheme) -> void:
	if not _placed.has(g):
		_placed.append(g)

func all_placed() -> bool:
	return _placed.size() >= _pieces.size()

# ── Scroll ────────────────────────────────────────────────────────────────────

func scroll_by(_delta_x: float) -> void:
	pass  # Wrap layout — no horizontal scrolling
