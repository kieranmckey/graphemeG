## game_stats.gd  (autoload: GameStats)
## Persistent game data — translated from AMGGameStats.h/.m (NSCoding → ConfigFile)
extends Node

const SAVE_PATH := "user://game_stats.cfg"

var score: int = 0
var best_word: String = ""
var new_best_word: bool = false
var new_hi_score: bool = false
var best_word_score: int = 0
var high_score: int = 0

func _ready() -> void:
    _load()

func reset() -> void:
    score = 0
    best_word = ""
    new_best_word = false
    new_hi_score = false
    best_word_score = 0

func save() -> void:
    if score > high_score:
        high_score = score
        new_hi_score = true
    var config := ConfigFile.new()
    config.set_value("stats", "high_score", high_score)
    config.set_value("stats", "best_word", best_word)
    config.set_value("stats", "best_word_score", best_word_score)
    config.save(SAVE_PATH)

func _load() -> void:
    var config := ConfigFile.new()
    if config.load(SAVE_PATH) == OK:
        high_score = config.get_value("stats", "high_score", 0)
        best_word  = config.get_value("stats", "best_word", "")
        best_word_score = config.get_value("stats", "best_word_score", 0)
