## letter_cell.gd
## One letter tile — Kenney square background + Label overlay centred in _ready().
class_name LetterCell
extends Node2D

var _label: Label

func setup(ch: String, tile_tex: Texture2D, font: Font, font_size: int) -> void:
	var bg := Sprite2D.new()
	bg.texture = tile_tex
	bg.scale = Vector2(Constants.LETTER_SCALE, Constants.LETTER_SCALE)
	add_child(bg)

	_label = Label.new()
	_label.text = ch
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)

func _ready() -> void:
	# Size and position the label after entering the tree; add offset to nudge baseline down.
	if _label:
		var hw := Constants.WORLD_TILE_SIZE * 0.5
		_label.position = Vector2(-hw, -hw + Constants.LETTER_Y_OFFSET)
		_label.size = Vector2(Constants.WORLD_TILE_SIZE, Constants.WORLD_TILE_SIZE)
