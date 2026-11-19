## main_menu.gd
## Main menu scene.
extends Node2D

@onready var _play_btn: Button = $UI/PlayButton
@onready var _level_select: OptionButton = $UI/LevelSelect
@onready var _progress_label: Label = $UI/ProgressLabel

func _ready() -> void:
	_play_btn.pressed.connect(_start_game)
	_level_select.item_selected.connect(_on_level_selected)
	_build_level_options()

func _build_level_options() -> void:
	var level_count := Leveller.get_level_count()
	if level_count == 0:
		push_error("MainMenu: no levels are configured")
		_play_btn.disabled = true
		return

	for index in level_count:
		var shape_name := Leveller.get_level_shape(index)
		var display_name := shape_name.trim_prefix("shape_").replace("_", " ").to_upper()
		var unlocked := Leveller.is_level_unlocked(index)
		var status := " (DONE)" if Leveller.is_level_completed(index) else \
			(" (LOCKED)" if not unlocked else "")
		_level_select.add_item("LEVEL %02d - %s%s" % [index + 1, display_name, status], index)
		_level_select.set_item_disabled(index, not unlocked)

	_level_select.select(Leveller.get_continue_level())
	_update_menu_state()

func _on_level_selected(_index: int) -> void:
	_update_menu_state()

func _update_menu_state() -> void:
	_progress_label.text = "%d / %d LEVELS COMPLETE" % [
		Leveller.get_completed_level_count(), Leveller.get_level_count()]
	_play_btn.text = "CONTINUE" if \
		_level_select.get_selected_id() == Leveller.get_continue_level() else "PLAY LEVEL"

func _start_game() -> void:
	Leveller.level = _level_select.get_selected_id()
	get_tree().change_scene_to_file("res://scenes/game_level.tscn")
