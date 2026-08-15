## leveller.gd  (autoload: Leveller)
## Level config + puzzle bank singleton. Also owns the word-list for O(1) validation.
extends Node

var level: int = Constants.START_LEVEL

var _word_set: Dictionary = {}
var _level_configs: Array = []
var _grid_shapes: Dictionary = {}
var _puzzle_bank: Dictionary = {}
var _used_puzzles: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_load_word_list()
	_load_level_data()
	_load_grid_shapes()
	_load_puzzle_bank()

# -- Loading ---------------------------------------------------------------

func _load_word_list() -> void:
	var file := FileAccess.open(Constants.WORDS_LIST_PATH, FileAccess.READ)
	if not file:
		push_error("Leveller: cannot open words7.txt")
		return
	for line in file.get_as_text().split("\n"):
		var w := line.strip_edges()
		if w.length() > 0:
			_word_set[w] = true
	file.close()
	print("Leveller: loaded %d words" % _word_set.size())

func _load_level_data() -> void:
	var file := FileAccess.open(Constants.LEVEL_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("Leveller: cannot open level_data.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.has("levels"):
		_level_configs = parsed["levels"]

func _load_grid_shapes() -> void:
	var file := FileAccess.open(Constants.GRID_SHAPES_PATH, FileAccess.READ)
	if not file:
		push_error("Leveller: cannot open grid_shapes.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_grid_shapes = parsed

func _load_puzzle_bank() -> void:
	var file := FileAccess.open(Constants.PUZZLE_BANK_PATH, FileAccess.READ)
	if not file:
		push_error("Leveller: cannot open puzzle_bank.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_puzzle_bank = parsed

# -- Accessors -------------------------------------------------------------

func get_level_config() -> Dictionary:
	if level < _level_configs.size():
		return _level_configs[level]
	return {}

func load_grid_shape(shape_name: String) -> Dictionary:
	return _grid_shapes.get(shape_name, {})

## Returns a random unused puzzle for the given shape (resets pool when exhausted).
func get_puzzle(shape_name: String) -> Dictionary:
	if not _puzzle_bank.has(shape_name):
		push_error("Leveller: no puzzles for shape '%s'" % shape_name)
		return {}
	var puzzles: Array = _puzzle_bank[shape_name]
	if puzzles.is_empty():
		return {}
	var used: Array = _used_puzzles.get(shape_name, [])
	var unused := puzzles.filter(func(p): return not used.has(p["id"]))
	if unused.is_empty():
		used.clear()
		_used_puzzles[shape_name] = used
		unused = puzzles.duplicate()
	var pick = unused[_rng.randi_range(0, unused.size() - 1)]
	used.append(pick["id"])
	_used_puzzles[shape_name] = used
	return pick

func is_word_valid(word: String) -> bool:
	return _word_set.has(word)
