## leveller.gd  (autoload: Leveller)
## Level configuration singleton — translated from AMGLeveller.h/.m
## Also owns the word-list dictionary for O(1) validation.
extends Node

var level: int = Constants.START_LEVEL

var _level_data: Dictionary = {}
var _word_set: Dictionary = {}   # word → true  (replaces O(n) string scan)

func _ready() -> void:
    _load_level_data()
    _load_word_list()

# ── Data loading ──────────────────────────────────────────────────────────────

func _load_level_data() -> void:
    var file := FileAccess.open(Constants.LEVEL_DATA_PATH, FileAccess.READ)
    if file:
        var parsed = JSON.parse_string(file.get_as_text())
        if parsed is Dictionary:
            _level_data = parsed
        file.close()
    else:
        push_error("Leveller: cannot open " + Constants.LEVEL_DATA_PATH)

func _load_word_list() -> void:
    var file := FileAccess.open(Constants.WORDS_LIST_PATH, FileAccess.READ)
    if file:
        for line in file.get_as_text().split("\n"):
            var w := line.strip_edges()
            if w.length() > 0:
                _word_set[w] = true
        file.close()
        print("Leveller: loaded %d words" % _word_set.size())
    else:
        push_error("Leveller: cannot open words7.txt at " + Constants.WORDS_LIST_PATH)

# ── Level accessors ───────────────────────────────────────────────────────────

func number_of_graphemes(type: Constants.GraphemeType) -> int:
    if _level_data.is_empty():
        return 5
    return _level_data["graphemes_per_level"][level][type]

func max_same_graphemes(type: Constants.GraphemeType) -> int:
    if _level_data.is_empty():
        return 1
    return _level_data["max_same_grapheme_per_level"][level][type]

func level_criteria(criteria: Constants.LevelCriteriaType) -> int:
    if _level_data.is_empty():
        return 2
    return _level_data["level_complete_criteria"][level][criteria]

func tile_map_name() -> String:
    if _level_data.is_empty():
        return "map1"
    var maps: Array = _level_data["tile_maps"]
    return maps[level % maps.size()]

func is_word_valid(word: String) -> bool:
    return _word_set.has(word)
