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
	var x_cursor := PIECE_PADDING

	for piece in pieces:
		var rect: Rect2 = piece.get_bounding_rect()
		# Align left edge at x_cursor, centre vertically
		var slot := Vector2(
			x_cursor - rect.position.x,
			-(rect.position.y + rect.size.y * 0.5))
		_piece_slots[piece] = slot
		x_cursor += rect.size.x + PIECE_PADDING

		# Reparent from scene root into container
		if piece.get_parent():
			piece.get_parent().remove_child(piece)
		_container.add_child(piece)
		piece.position = slot

	_total_width = x_cursor

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

func scroll_by(delta_x: float) -> void:
	_scroll_offset = clamp(
		_scroll_offset - delta_x,
		0.0,
		max(0.0, _total_width - _viewport_width))
	_container.position.x = -_scroll_offset
