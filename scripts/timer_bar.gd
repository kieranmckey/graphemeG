## timer_bar.gd
## Countdown timer visual — translated from AMGTimerBar (SKCropNode → TextureProgressBar)
## Scene: res://scenes/components/timer_bar.tscn
class_name TimerBar
extends Control

signal time_up()

@export var start_seconds: int = Constants.START_TIMER_SECONDS

var _remaining: float = 0.0
var _running: bool = false

@onready var _bar: TextureProgressBar = $Bar
@onready var _label: Label            = $Label

func _ready() -> void:
    _remaining = float(start_seconds)
    _refresh()

func _process(delta: float) -> void:
    if not _running:
        return
    _remaining = maxf(_remaining - delta, 0.0)
    _refresh()
    if _remaining == 0.0:
        _running = false
        time_up.emit()

func start() -> void:
    _remaining = float(start_seconds)
    _running   = true

func stop() -> void:
    _running = false

func _refresh() -> void:
    var ratio := _remaining / float(max(start_seconds, 1))
    if _bar:
        _bar.value     = ratio * 100.0
        _bar.modulate  = Color.RED if _remaining < 30.0 else Color.WHITE
    if _label:
        var mins := int(_remaining) / 60
        var secs := int(_remaining) % 60
        _label.text = "%d:%02d" % [mins, secs]
