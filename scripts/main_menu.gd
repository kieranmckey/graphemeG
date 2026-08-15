## main_menu.gd
## Main menu scene.
extends Node2D

@onready var _play_btn: Button = $UI/PlayButton

func _ready() -> void:
	_play_btn.pressed.connect(_start_game)

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game_level.tscn")
