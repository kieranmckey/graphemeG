## main_menu.gd
## Main menu scene.
extends Node2D

@onready var _play_btn: Button = $UI/PlayButton

var _level_select: OptionButton

func _ready() -> void:
	_play_btn.pressed.connect(_start_game)
	_build_level_select()

# Debug: jump straight to any level.
func _build_level_select() -> void:
	var label := Label.new()
	label.text = "LEVEL"
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.56
	label.anchor_bottom = 0.56
	label.offset_left = -180.0
	label.offset_bottom = 40.0
	$UI.add_child(label)

	_level_select = OptionButton.new()
	_level_select.add_theme_font_size_override("font_size", 28)
	_level_select.anchor_left = 0.5
	_level_select.anchor_right = 0.5
	_level_select.anchor_top = 0.56
	_level_select.anchor_bottom = 0.56
	_level_select.offset_left = 20.0
	_level_select.offset_right = 320.0
	_level_select.offset_bottom = 48.0
	for i in Leveller.get_level_count():
		_level_select.add_item("%d  %s" % [i, Leveller.get_level_shape(i)], i)
	_level_select.select(clampi(Leveller.level, 0, maxi(Leveller.get_level_count() - 1, 0)))
	$UI.add_child(_level_select)

func _start_game() -> void:
	Leveller.level = _level_select.get_selected_id()
	get_tree().change_scene_to_file("res://scenes/game_level.tscn")
