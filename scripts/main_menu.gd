## main_menu.gd
## Main menu scene.
extends Node2D

@onready var _play_btn: Button = $UI/PlayButton
@onready var _difficulty: OptionButton = $UI/Difficulty

func _ready() -> void:
	_play_btn.pressed.connect(_start_game)
	_difficulty.item_selected.connect(_difficulty_selected)
	_difficulty.select(0)

func _start_game() -> void:
	_difficulty_selected(_difficulty.selected)
	get_tree().change_scene_to_file("res://scenes/game_level.tscn")

func _difficulty_selected(index: int) -> void:
	Leveller.set_difficulty(_difficulty.get_item_text(index))
