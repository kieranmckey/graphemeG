## hud.gd
## In-game heads-up display — translated from the HUD portion of AMGGraphemeLevelScene.m
## Scene: res://scenes/components/hud.tscn
class_name HUD
extends CanvasLayer

signal check_words_pressed()
signal next_level_pressed()
signal redo_level_pressed()
signal quit_pressed()

@onready var _score_label:  Label      = $ScoreContainer/ScoreLabel
@onready var _lives_row:    HBoxContainer = $LivesContainer
@onready var _check_btn:    Button     = $CheckButton
@onready var _end_panel:    Control    = $LevelEndPanel
@onready var _next_btn:     Button     = $LevelEndPanel/NextButton
@onready var _redo_btn:     Button     = $LevelEndPanel/RedoButton
@onready var _quit_btn:     Button     = $LevelEndPanel/QuitButton
@onready var _best_lbl:     Label      = $BestWordLabel
@onready var _progress_lbl: Label      = $ProgressLabel

func _ready() -> void:
    _end_panel.visible = false
    _best_lbl.visible  = false
    _check_btn.pressed.connect(func(): check_words_pressed.emit())
    _next_btn.pressed.connect(func(): next_level_pressed.emit())
    _redo_btn.pressed.connect(func(): redo_level_pressed.emit())
    _quit_btn.pressed.connect(func(): quit_pressed.emit())

# ── Score ─────────────────────────────────────────────────────────────────────

func update_score(value: int) -> void:
    if _score_label:
        _score_label.text = str(value)

# ── Lives ─────────────────────────────────────────────────────────────────────

func update_lives(lives: int) -> void:
    if not _lives_row:
        return
    for child in _lives_row.get_children():
        child.queue_free()
    for _i in range(lives):
        var lbl := Label.new()
        lbl.text = "♥"
        lbl.add_theme_color_override("font_color", Color.RED)
        _lives_row.add_child(lbl)

# ── Progress label (words / tiles) ───────────────────────────────────────────

func update_progress(words: int, words_needed: int, tiles: int, tiles_needed: int) -> void:
    if _progress_lbl:
        _progress_lbl.text = "Words: %d/%d  Tiles: %d/%d" % [words, words_needed, tiles, tiles_needed]

# ── Level end ─────────────────────────────────────────────────────────────────

func show_level_end(won: bool) -> void:
    _end_panel.visible = true
    _next_btn.visible  = won
    _redo_btn.visible  = not won

# ── Best word flash ───────────────────────────────────────────────────────────

func show_best_word(word: String, score: int) -> void:
    if not _best_lbl:
        return
    _best_lbl.text    = "Best word: %s (%d pts)" % [word, score]
    _best_lbl.modulate.a = 1.0
    _best_lbl.visible = true
    var tw := create_tween()
    tw.tween_interval(2.0)
    tw.tween_property(_best_lbl, "modulate:a", 0.0, 1.5)
    tw.tween_callback(func(): _best_lbl.visible = false)
