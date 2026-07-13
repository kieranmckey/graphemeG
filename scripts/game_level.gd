## game_level.gd
## Main game scene controller — translated from AMGGraphemeLevelScene.h/.m
## Handles input (touch drag / swipe), level lifecycle, and ties all subsystems together.
## Scene: res://scenes/game_level.tscn
extends Node2D

# Grid origin: top-left tile centre, matching the SpriteKit layout
# (SpriteKit Y-up → Godot Y-down: grid anchor moves from top-right to top-left)
const GRID_ORIGIN := Vector2(
    Constants.BORDER_SIZE + Constants.WORLD_TILE_SIZE * 0.5,
    Constants.BORDER_SIZE + Constants.WORLD_TILE_SIZE * 0.5)

# ── State ─────────────────────────────────────────────────────────────────────

var _selected_grapheme: Grapheme = null
var _grapheme_sliders: Array = []   # [vowel_slider, consonant_slider, morpheme_slider]
var _level_over: bool = false
var _winner: bool = false
var _lives_left: int = Constants.START_LIVES
var _prior_touch: Vector2 = Vector2.ZERO
var _touch_start: Vector2 = Vector2.ZERO   # for swipe detection
var _is_swiping: bool = false              # touch not yet claimed by a grapheme drag

# ── Node refs ─────────────────────────────────────────────────────────────────

@onready var _grid:         Grid            = $Grid
@onready var _hud:          HUD             = $HUD
@onready var _timer_bar:    TimerBar        = $TimerBar
@onready var _sliders_root: Node2D          = $SlidersRoot
@onready var _background:   Sprite2D        = $Background

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
    _start_level()

func _start_level() -> void:
    _load_background()
    _build_grid()
    _connect_hud()
    _add_grapheme_sliders()
    _setup_timer()

func _load_background() -> void:
    if _background and ResourceLoader.exists(Constants.BACKGROUND_PATH):
        _background.texture = load(Constants.BACKGROUND_PATH)

func _build_grid() -> void:
    _grid.build(GRID_ORIGIN)

func _connect_hud() -> void:
    _hud.update_lives(_lives_left)
    _hud.update_score(GameStats.score)
    _hud.check_words_pressed.connect(_check_grid_for_words)
    _hud.next_level_pressed.connect(_go_to_next_level)
    _hud.redo_level_pressed.connect(_redo_level)
    _hud.quit_pressed.connect(_quit_to_menu)
    _grid.score_updated.connect(_on_score_updated)
    _grid.words_validated.connect(_on_words_validated)

func _add_grapheme_sliders() -> void:
    var tile_count := _grid.tile_count()
    var vp_size    := get_viewport_rect().size

    # One slider per grapheme type: VOWEL=0, CONSONANT=1, MORPHEME=2
    for type_idx in range(3):
        var slider_scene := load("res://scenes/components/grapheme_slider.tscn") as PackedScene
        var slider: GraphemeSlider = slider_scene.instantiate()
        _sliders_root.add_child(slider)

        # Mirror of SpriteKit: y = screen_height*(kplayAreaY - 0.09*type)  from bottom
        #   → Godot (Y-down): y = screen_height * (1 - (0.35 - 0.09*type))
        var y_frac := 1.0 - (Constants.PLAY_AREA_Y - 0.09 * type_idx)
        slider.initialize(
            Vector2(Constants.BORDER_SIZE, vp_size.y * y_frac),
            vp_size.x - Constants.WORLD_TILE_SIZE * 0.5 - Constants.BORDER_SIZE,
            type_idx as Constants.GraphemeType)
        slider.show_graphemes(tile_count - 2)
        _grapheme_sliders.append(slider)

func _setup_timer() -> void:
    _timer_bar.start_seconds = Constants.START_TIMER_SECONDS
    _timer_bar.time_up.connect(_on_time_up)
    # Delay start by 2 s (matches original SKAction waitForDuration:2.0)
    await get_tree().create_timer(2.0).timeout
    if not _level_over:
        _timer_bar.start()

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
    if _level_over:
        return

    if event is InputEventScreenTouch:
        _handle_touch(event as InputEventScreenTouch)
    elif event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT:
            var fake := InputEventScreenTouch.new()
            fake.position = mb.position
            fake.pressed  = mb.pressed
            _handle_touch(fake)
    elif event is InputEventScreenDrag:
        _handle_drag((event as InputEventScreenDrag).position,
                     (event as InputEventScreenDrag).relative)
    elif event is InputEventMouseMotion:
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            _handle_drag((event as InputEventMouseMotion).position,
                         (event as InputEventMouseMotion).relative)

func _handle_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        _touch_start  = event.position
        _prior_touch  = event.position
        _is_swiping   = true
        _selected_grapheme = null

        var g := _grapheme_at(event.position)
        if g:
            _is_swiping = false
            _begin_drag(g, event.position)
    else:
        if _selected_grapheme:
            _end_drag(event.position)
        elif _is_swiping:
            _try_swipe(event.position)
        _is_swiping = false

func _handle_drag(pos: Vector2, delta: Vector2) -> void:
    if not _selected_grapheme or not _selected_grapheme.is_selected:
        return
    _selected_grapheme.global_position += delta
    _prior_touch = pos
    if _grid.is_point_in_grid(_selected_grapheme.global_position, _selected_grapheme):
        _grid.rotate_grapheme_in_grid(delta,
            _selected_grapheme.global_position, _selected_grapheme)

# ── Grapheme selection / drag ─────────────────────────────────────────────────

func _grapheme_at(screen_pos: Vector2) -> Grapheme:
    for slider in _grapheme_sliders:
        for page in slider._pages:
            for child in page.get_children():
                if not (child is Grapheme):
                    continue
                var g := child as Grapheme
                if not g.is_selectable:
                    continue
                if g.get_bounding_rect().has_point(g.to_local(screen_pos)):
                    return g
    # Also check graphemes already on the grid (but not disabled)
    for t in _grid.tiles:
        if t.grapheme == null:
            continue
        var g: Grapheme = t.grapheme
        if g.grapheme_state == Constants.GraphemeState.DISABLED:
            continue
        if g.get_bounding_rect().has_point(g.to_local(screen_pos)):
            return g
    return null

func _begin_drag(g: Grapheme, pos: Vector2) -> void:
    _selected_grapheme  = g
    g.pre_move_position = g.global_position
    g.set_selected(true)

    # Detach from slider page so it renders above everything
    var slider: GraphemeSlider = _grapheme_sliders[g.grapheme_type]
    slider.detach_grapheme(g)
    add_child(g)

    # If it was on the grid, un-place it
    if g.is_placed:
        _grid.remove_from_grid(g)

    # Lift to finger position
    g.global_position = pos

func _end_drag(pos: Vector2) -> void:
    var g := _selected_grapheme
    _selected_grapheme = null

    if not is_instance_valid(g):
        return

    var placed := false
    if _grid.is_point_in_grid(g.global_position, g):
        placed = _grid.snap_to_tile(g)
        if placed:
            var slider: GraphemeSlider = _grapheme_sliders[g.grapheme_type]
            slider.mark_placed(g)
            _check_grid_for_words()

    if not placed:
        _return_to_slider(g)

    g.set_selected(false)

func _return_to_slider(g: Grapheme) -> void:
    var slider: GraphemeSlider = _grapheme_sliders[g.grapheme_type]
    if g.get_parent():
        g.get_parent().remove_child(g)
    if not slider._pages.is_empty():
        slider._pages[slider._current_page].add_child(g)
    g.is_placed          = false
    g.grapheme_state     = Constants.GraphemeState.IDLE
    g.z_index            = Constants.WorldLayer.GRAPHEME
    g.global_position    = g.pre_move_position
    g.is_selectable      = true

# ── Swipe detection (slider page change) ────────────────────────────────────

func _try_swipe(end_pos: Vector2) -> void:
    var dx := end_pos.x - _touch_start.x
    if abs(dx) < Constants.SWIPE_MIN_DISTANCE:
        return
    var direction := 1 if dx < 0 else -1   # swipe left → forward, swipe right → back
    # Find which slider was swiped (by vertical position)
    for slider in _grapheme_sliders:
        var slider_y := slider.global_position.y
        if abs(_touch_start.y - slider_y) < Constants.WORLD_TILE_SIZE * 2:
            slider.slide(direction)
            return

# ── Grid word check ───────────────────────────────────────────────────────────

func _check_grid_for_words() -> void:
    _grid.check_for_valid_words()
    _hud.update_progress(
        _grid.number_of_words,
        Leveller.level_criteria(Constants.LevelCriteriaType.NUMBER_OF_WORDS),
        _grid.tiles_used_count(),
        Leveller.level_criteria(Constants.LevelCriteriaType.TILES_FILLED))
    _check_level_complete()

# ── Signals from grid ─────────────────────────────────────────────────────────

func _on_score_updated(delta: int) -> void:
    GameStats.score += delta
    _hud.update_score(GameStats.score)

func _on_words_validated(_words: Array) -> void:
    if GameStats.new_best_word:
        GameStats.new_best_word = false
        _hud.show_best_word(GameStats.best_word, GameStats.best_word_score)

# ── Timer ─────────────────────────────────────────────────────────────────────

func _on_time_up() -> void:
    if _level_over:
        return
    _level_over = true
    _winner = false
    _end_level()

# ── Level completion ──────────────────────────────────────────────────────────

func _check_level_complete() -> void:
    if _level_over:
        return
    var words_ok := _grid.number_of_words >= \
        Leveller.level_criteria(Constants.LevelCriteriaType.NUMBER_OF_WORDS)
    var score_ok := GameStats.score >= \
        Leveller.level_criteria(Constants.LevelCriteriaType.PLAYER_SCORE)
    var tiles_ok := _grid.tiles_used_count() >= \
        Leveller.level_criteria(Constants.LevelCriteriaType.TILES_FILLED)

    if words_ok and score_ok and tiles_ok:
        _winner = true
        _level_over = true
        _timer_bar.stop()
        _end_level()

func _end_level() -> void:
    GameStats.save()
    _hud.show_level_end(_winner)
    for slider in _grapheme_sliders:
        slider.remove_all()

# ── Navigation ────────────────────────────────────────────────────────────────

func _go_to_next_level() -> void:
    if _winner and Leveller.level < Constants.MAX_LEVELS - 1:
        Leveller.level += 1
    else:
        GameStats.reset()
        Leveller.level = 0
    get_tree().reload_current_scene()

func _redo_level() -> void:
    GameStats.reset()
    get_tree().reload_current_scene()

func _quit_to_menu() -> void:
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
