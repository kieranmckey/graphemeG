## tile.gd
## A single grid cell.
## Scene: res://scenes/components/tile.tscn
class_name Tile
extends Node2D

signal state_changed(new_state: Constants.TileState)

# -- State -----------------------------------------------------------------

var tile_state: Constants.TileState = Constants.TileState.IDLE:
	set(value):
		if tile_state == value:
			return
		tile_state = value
		_apply_visual_state()
		state_changed.emit(tile_state)

var tile_type: Constants.TileType = Constants.TileType.DEFAULT
var grapheme = null
var letter_index: int = 0
var row: int = 0
var col: int = 0

# -- Node refs -------------------------------------------------------------

@onready var _sprite: Sprite2D = $TileSprite

const _TEXTURE_MAP := {
	Constants.TileState.IDLE:             "grid_idle.png",
	Constants.TileState.SELECTED:         "grid_selected.png",
	Constants.TileState.FILLED:           "grid_filled.png",
	Constants.TileState.VALIDATED:        "grid_validated.png",
	Constants.TileState.INVALID:          "grid_invalid.png",
	Constants.TileState.DISABLED:         "grid_idle.png",
	Constants.TileState.INVALID_DISABLED: "grid_invalid.png",
}

func _ready() -> void:
	z_index = Constants.WorldLayer.GRID
	_apply_visual_state()

# -- Public API ------------------------------------------------------------

func set_state(new_state: Constants.TileState) -> void:
	tile_state = new_state

# -- Visuals ---------------------------------------------------------------

func _apply_visual_state() -> void:
	_update_texture()
	_update_alpha()

func _update_texture() -> void:
	if not _sprite:
		return
	var tex_name: String = _TEXTURE_MAP.get(tile_state, "grid_idle.png")
	var path := Constants.GRID_TILES_DIR + tex_name
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		_sprite.scale = Vector2(Constants.LETTER_SCALE, Constants.LETTER_SCALE)

func _update_alpha() -> void:
	match tile_state:
		Constants.TileState.DISABLED, Constants.TileState.INVALID_DISABLED:
			var tw := create_tween()
			tw.tween_property(self, "modulate:a",
				Constants.DISABLED_ALPHA, Constants.DISABLED_FADE_DURATION)
		_:
			modulate.a = 1.0
