## grapheme_slider.gd
## A horizontal tray of grapheme tiles with swipeable pages.
## Translated from AMGGraphemeSlider.h/.m
## Scene: res://scenes/components/grapheme_slider.tscn
class_name GraphemeSlider
extends Node2D

var grapheme_type: Constants.GraphemeType = Constants.GraphemeType.VOWEL
var x_limit: float = 0.0   # max pixel width of one page

var _pages: Array[Node2D] = []
var _graphemes: Array = []          # all Grapheme nodes in this slider
var _placed_graphemes: Array = []   # graphemes currently locked on the grid
var _current_page: int = 0
var _page_cursor_x: float = 0.0     # x offset within the current page being filled
var _ai: GraphemeAI = null

@onready var _dots_root: Node2D = $DotsContainer

# ── Initialization ────────────────────────────────────────────────────────────

func initialize(pos: Vector2, x_lim: float, type: Constants.GraphemeType) -> void:
    position   = pos
    x_limit    = x_lim
    grapheme_type = type
    _ai = GraphemeAI.new()

## Populate the slider with graphemes for the current level.
## max_grapheme_length caps how long morphemes can be.
func show_graphemes(max_grapheme_length: int) -> void:
    var count := Leveller.number_of_graphemes(grapheme_type)
    var g_scene := load("res://scenes/components/grapheme.tscn") as PackedScene

    for _i in range(count):
        var g: Grapheme = g_scene.instantiate()
        var morpheme := _ai.get_random_morpheme(grapheme_type, max_grapheme_length)
        g.setup(morpheme, grapheme_type, _ai)
        _add_to_page(g)
        _graphemes.append(g)

    if _pages.size() > 0:
        _pages[0].modulate.a = 1.0
    _current_page = 0
    _set_page_selectable(_current_page, true)
    _redraw_dots()

# ── Page management ───────────────────────────────────────────────────────────

func _add_to_page(g: Grapheme) -> void:
    var g_width := g.length * (Constants.LETTER_TILE_SIZE + Constants.LETTER_OFFSET * 2)

    if _pages.is_empty() or _page_cursor_x + g_width > x_limit + Constants.LETTER_TILE_SIZE:
        _new_page()

    var page := _pages[-1]
    page.add_child(g)
    g.is_selectable = false
    g.position = Vector2(_page_cursor_x, 0.0)
    _page_cursor_x += g_width

func _new_page() -> void:
    var page := Node2D.new()
    page.modulate.a = 0.0
    add_child(page)
    _pages.append(page)
    _page_cursor_x = Constants.LETTER_TILE_SIZE / 2.0

func slide(direction: int) -> void:
    # direction: +1 = forward (swipe left), -1 = back (swipe right)
    var target := _current_page + direction
    if target < 0 or target >= _pages.size():
        return
    _set_page_selectable(_current_page, false)
    var tw_out := create_tween()
    tw_out.tween_property(_pages[_current_page], "modulate:a", 0.0, 0.2)
    _current_page = target
    var tw_in := create_tween()
    tw_in.tween_property(_pages[_current_page], "modulate:a", 1.0, 0.2)
    _set_page_selectable(_current_page, true)
    _redraw_dots()

func _set_page_selectable(page_idx: int, selectable: bool) -> void:
    if page_idx < 0 or page_idx >= _pages.size():
        return
    for child in _pages[page_idx].get_children():
        if child is Grapheme:
            (child as Grapheme).is_selectable = selectable

# ── Grapheme add / remove ─────────────────────────────────────────────────────

## Called when a grapheme is successfully placed on the grid.
func mark_placed(g: Grapheme) -> void:
    if not _placed_graphemes.has(g):
        _placed_graphemes.append(g)

## Return a grapheme to this slider (after failed placement or un-placement).
func return_grapheme(g: Grapheme) -> void:
    _placed_graphemes.erase(g)
    if not g.get_parent():
        var page := _pages[_current_page] if not _pages.is_empty() else self
        page.add_child(g)
    g.is_selectable = true
    g.z_index = Constants.WorldLayer.GRAPHEME

## Remove grapheme node from its current page parent (called when drag begins).
func detach_grapheme(g: Grapheme) -> void:
    if not _placed_graphemes.has(g) and g.get_parent():
        g.get_parent().remove_child(g)

func remove_all() -> void:
    for g in _graphemes:
        if is_instance_valid(g):
            g.queue_free()
    _graphemes.clear()
    _placed_graphemes.clear()
    for p in _pages:
        if is_instance_valid(p):
            p.queue_free()
    _pages.clear()
    _current_page = 0
    _page_cursor_x = 0.0

# ── Page indicator dots ───────────────────────────────────────────────────────

func _redraw_dots() -> void:
    if not _dots_root:
        return
    for child in _dots_root.get_children():
        child.queue_free()
    if _pages.size() < 2:
        return
    var spacer := 25.0
    var start_x := -(_pages.size() - 1) * spacer * 0.5
    for i in range(_pages.size()):
        var dot := ColorRect.new()
        dot.size    = Vector2(8.0, 8.0)
        dot.position = Vector2(start_x + i * spacer - 4.0,
                                -Constants.LETTER_TILE_SIZE * 0.5 - spacer * 0.25)
        dot.color = Color.LIGHT_GRAY if i == _current_page else Color.DARK_GRAY
        _dots_root.add_child(dot)
