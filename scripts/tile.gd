## tile.gd
## A single grid cell — translated from AMGTile.h/.m
## Scene: res://scenes/components/tile.tscn
class_name Tile
extends Node2D

signal state_changed(new_state: Constants.TileState)

# ── State ─────────────────────────────────────────────────────────────────────

var tile_state: Constants.TileState = Constants.TileState.IDLE:
    set(value):
        if tile_state == value:
            return
        tile_state = value
        _apply_visual_state()
        state_changed.emit(tile_state)

var tile_type: Constants.TileType = Constants.TileType.DEFAULT
var grapheme = null      # Grapheme occupying this tile (or null)
var letter_index: int = 0  # Which character of the grapheme sits here
var row: int = 0
var col: int = 0
var _bonus_applied: bool = false

# ── Node refs ─────────────────────────────────────────────────────────────────

@onready var _sprite: Sprite2D = $TileSprite

# Texture names per state — copied from the original Tiles.atlas filenames
const _TEXTURE_MAP := {
    Constants.TileState.IDLE:             "tile_0002.png",
    Constants.TileState.SELECTED:         "tile_white.png",
    Constants.TileState.FILLED:           "tile_filled.png",
    Constants.TileState.VALIDATED:        "tile_validated.png",
    Constants.TileState.INVALID:          "tile_invalid.png",
    Constants.TileState.DISABLED:         "tile_disabled.png",
    Constants.TileState.INVALID_DISABLED: "tile_invalid_disabled.png",
}

func _ready() -> void:
    z_index = Constants.WorldLayer.GRID
    _apply_visual_state()

# ── Public API ────────────────────────────────────────────────────────────────

func set_state(new_state: Constants.TileState) -> void:
    tile_state = new_state

func apply_bonus() -> void:
    if _bonus_applied:
        return
    _bonus_applied = true
    if _sprite:
        var tw := create_tween()
        tw.tween_property(_sprite, "modulate", Color.GOLD, 0.25)
        tw.tween_property(_sprite, "modulate", Color.WHITE, 0.25)

# ── Visuals ───────────────────────────────────────────────────────────────────

func _apply_visual_state() -> void:
    _update_texture()
    _update_alpha()

func _update_texture() -> void:
    if not _sprite:
        return
    var name: String = _TEXTURE_MAP.get(tile_state, "tile_0002.png")
    var path := Constants.TILE_ATLAS_DIR + name
    if ResourceLoader.exists(path):
        _sprite.texture = load(path)

func _update_alpha() -> void:
    match tile_state:
        Constants.TileState.DISABLED, Constants.TileState.INVALID_DISABLED:
            var tw := create_tween()
            tw.tween_property(self, "modulate:a",
                Constants.DISABLED_ALPHA, Constants.DISABLED_FADE_DURATION)
        _:
            modulate.a = 1.0
