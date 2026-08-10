## grapheme.gd
## A draggable letter-tile piece — translated from AMGGrapheme.h/.m
## Scene: res://scenes/components/grapheme.tscn
class_name Grapheme
extends Node2D

# ── Data ──────────────────────────────────────────────────────────────────────

var grapheme_type: Constants.GraphemeType = Constants.GraphemeType.VOWEL
var grapheme_dir: Constants.GraphemeDirection = Constants.GraphemeDirection.HORIZONTAL_RIGHT
var grapheme_state: Constants.GraphemeState = Constants.GraphemeState.IDLE
var text: String = ""       # e.g. "ing", "b", "e"
var score: int = 0
var length: int = 0         # number of letters = tiles needed
var is_placed: bool = false
var is_selectable: bool = true
var is_selected: bool = false
var pre_move_position: Vector2 = Vector2.ZERO
var start_tile_row: int = 0   # grid row of first letter when placed
var start_tile_col: int = 0   # grid col of first letter when placed

# ── Node refs ─────────────────────────────────────────────────────────────────

@onready var _letters_root: Node2D = $LetterSprites
@onready var _score_label: Label   = $ScoreLabel

# ── Setup ─────────────────────────────────────────────────────────────────────

## Called once after instantiation to configure the grapheme.
func setup(morpheme_text: String, type: Constants.GraphemeType, ai: GraphemeAI) -> void:
    text          = morpheme_text.to_lower()
    length        = text.length()
    grapheme_type = type
    score         = ai.get_morpheme_score(text)
    # Visuals are built in _ready() once @onready vars are available
    pass

func _ready() -> void:
    if not text.is_empty():
        _build_visuals()

func _build_visuals() -> void:
    if not _letters_root:
        return
    for child in _letters_root.get_children():
        child.queue_free()

    for i in range(length):
        var ch := text[i].to_lower()
        var path := Constants.LETTERS_DIR + ch + ".png"
        var sprite := Sprite2D.new()
        if ResourceLoader.exists(path):
            sprite.texture = load(path)
        sprite.scale = Vector2(Constants.LETTER_SCALE, Constants.LETTER_SCALE)
        sprite.position = Vector2(i * Constants.WORLD_TILE_SIZE, 0.0)
        _letters_root.add_child(sprite)

    if _score_label:
        _score_label.text = str(score)
        _score_label.position = Vector2(
            length * Constants.WORLD_TILE_SIZE - Constants.WORLD_TILE_SIZE,
            -(Constants.WORLD_TILE_SIZE * 0.5))

# ── Direction / Rotation ──────────────────────────────────────────────────────

func set_direction(dir: Constants.GraphemeDirection) -> void:
    if grapheme_dir == dir:
        return
    grapheme_dir = dir
    _apply_rotation()

func _apply_rotation() -> void:
    if not _letters_root:
        return
    match grapheme_dir:
        Constants.GraphemeDirection.HORIZONTAL_RIGHT: _letters_root.rotation = 0.0
        Constants.GraphemeDirection.VERTICAL_DOWN:    _letters_root.rotation = PI / 2.0
        Constants.GraphemeDirection.HORIZONTAL_LEFT:  _letters_root.rotation = PI
        Constants.GraphemeDirection.VERTICAL_UP:      _letters_root.rotation = -PI / 2.0

## Axis-aligned bounding rect (local space) for overlap tests.
func get_bounding_rect() -> Rect2:
    var hw := Constants.WORLD_TILE_SIZE / 2.0
    if grapheme_dir == Constants.GraphemeDirection.HORIZONTAL_RIGHT:
        return Rect2(-hw, -hw,
            length * Constants.WORLD_TILE_SIZE,
            Constants.WORLD_TILE_SIZE)
    else:
        return Rect2(-hw, -hw,
            Constants.WORLD_TILE_SIZE,
            length * Constants.WORLD_TILE_SIZE)

# ── Selection ─────────────────────────────────────────────────────────────────

func set_selected(selected: bool) -> void:
    is_selected = selected
    if selected:
        grapheme_state = Constants.GraphemeState.SELECTED
        z_index = Constants.WorldLayer.PANELS
    else:
        grapheme_state = Constants.GraphemeState.IDLE
        z_index = Constants.WorldLayer.GRAPHEME

func update_score_display() -> void:
    if _score_label:
        _score_label.text = str(score)
