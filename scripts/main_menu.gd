## main_menu.gd
## Main menu scene — translated from AMGMainMenuScene.h/.m
extends Node2D

@onready var _play_btn:     Button = $UI/PlayButton
@onready var _hi_score_lbl: Label  = $UI/HiScoreLabel
@onready var _title_lbl:    Label  = $UI/TitleLabel

func _ready() -> void:
    _hi_score_lbl.text = "Best score: %d" % GameStats.high_score
    if GameStats.best_word.length() > 0:
        _hi_score_lbl.text += "\nBest word: %s (%d pts)" % \
            [GameStats.best_word, GameStats.best_word_score]
    _play_btn.pressed.connect(_start_game)

func _start_game() -> void:
    get_tree().change_scene_to_file("res://scenes/game_level.tscn")
