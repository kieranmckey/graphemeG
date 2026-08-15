## hud.gd
## In-game HUD - level-end panel and navigation buttons.
## Scene: res://scenes/components/hud.tscn
class_name HUD
extends CanvasLayer

signal next_level_pressed()
signal redo_level_pressed()
signal quit_pressed()

@onready var _end_panel: Control = $LevelEndPanel
@onready var _next_btn:  Button  = $LevelEndPanel/NextButton
@onready var _redo_btn:  Button  = $LevelEndPanel/RedoButton
@onready var _quit_btn:  Button  = $LevelEndPanel/QuitButton

func _ready() -> void:
	_end_panel.visible = false
	_next_btn.pressed.connect(func(): next_level_pressed.emit())
	_redo_btn.pressed.connect(func(): redo_level_pressed.emit())
	_quit_btn.pressed.connect(func(): quit_pressed.emit())
	_apply_theme()

func show_level_end(won: bool) -> void:
	_end_panel.visible = true
	_next_btn.visible  = won
	_redo_btn.visible  = not won

func _apply_theme() -> void:
	var font: FontFile = load(Constants.FONT_PATH) as FontFile
	if not font:
		return
	var btn_tex: Texture2D = load(Constants.UI_BUTTON_PATH)
	var btn_style := StyleBoxTexture.new()
	if btn_tex:
		btn_style.texture = btn_tex
		btn_style.texture_margin_left   = 12
		btn_style.texture_margin_right  = 12
		btn_style.texture_margin_top    = 10
		btn_style.texture_margin_bottom = 10
	for node in _collect_nodes(self):
		if node is Button:
			node.add_theme_font_override("font", font)
			node.add_theme_font_size_override("font_size", Constants.UI_FONT_SIZE)
			if btn_tex:
				node.add_theme_stylebox_override("normal",  btn_style)
				node.add_theme_stylebox_override("hover",   btn_style)
				node.add_theme_stylebox_override("pressed", btn_style)

func _collect_nodes(root: Node) -> Array:
	var result := [root]
	for child in root.get_children():
		result.append_array(_collect_nodes(child))
	return result
