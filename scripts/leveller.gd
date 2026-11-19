## leveller.gd  (autoload: Leveller)
## Level config + puzzle bank singleton. Also owns the word-list for O(1) validation.
extends Node

const PROGRESS_PATH: String = "user://progress.cfg"

var level: int = Constants.START_LEVEL
var highest_unlocked_level: int = Constants.START_LEVEL
var selected_difficulty: String = "Any"

var _word_set: Dictionary = {}
var _level_configs: Array = []
var _piece_sets: Dictionary = {}
var _completed_levels: Dictionary = {}
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
	_load_progress()

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
	if not parsed is Dictionary or not parsed.get("levels") is Array:
		push_error("Leveller: level_data.json must contain a levels array")
		return

	var piece_sets = parsed.get("piece_sets")
	if not piece_sets is Dictionary:
		push_error("Leveller: level_data.json must contain a piece_sets Dictionary")
		return

	var levels: Array = parsed["levels"]
	for config in levels:
		if not config is Dictionary:
			push_error("Leveller: each level config must be a Dictionary")
			return
		if not config.has("piece_set"):
			push_error("Leveller: level config is missing piece_set")
			return
		var piece_set_name = config["piece_set"]
		if not piece_set_name is String:
			push_error("Leveller: piece_set name must be a String")
			return
		if not piece_sets.has(piece_set_name) or not piece_sets[piece_set_name] is Array:
			push_error("Leveller: unknown or invalid piece set '%s'" % piece_set_name)
			return
	_piece_sets = piece_sets
	_level_configs = levels

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

func _load_progress() -> void:
	var progress := ConfigFile.new()
	var error := progress.load(PROGRESS_PATH)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_error("Leveller: cannot load progress file (error %d)" % error)
		return

	var max_level: int = maxi(get_level_count() - 1, Constants.START_LEVEL)
	var saved_unlocked = progress.get_value("progress", "highest_unlocked_level", Constants.START_LEVEL)
	if saved_unlocked is int:
		highest_unlocked_level = clampi(saved_unlocked, Constants.START_LEVEL, max_level)
	else:
		push_error("Leveller: saved highest_unlocked_level must be an integer")

	var saved_completed = progress.get_value("progress", "completed_levels", [])
	if saved_completed is Array:
		for completed_level in saved_completed:
			if completed_level is int and completed_level >= 0 and completed_level < get_level_count():
				_completed_levels[completed_level] = true
			else:
				push_error("Leveller: saved completed level is invalid")
	else:
		push_error("Leveller: saved completed_levels must be an Array")

	for completed_level in _completed_levels:
		highest_unlocked_level = maxi(highest_unlocked_level,
			mini(completed_level + 1, max_level))

func _save_progress() -> void:
	var progress := ConfigFile.new()
	progress.set_value("progress", "highest_unlocked_level", highest_unlocked_level)
	progress.set_value("progress", "completed_levels", _completed_levels.keys())
	var error := progress.save(PROGRESS_PATH)
	if error != OK:
		push_error("Leveller: cannot save progress file (error %d)" % error)

# -- Accessors -------------------------------------------------------------

func get_level_config() -> Dictionary:
	if level >= 0 and level < _level_configs.size():
		var config: Dictionary = _level_configs[level].duplicate()
		var piece_set_name: String = config["piece_set"]
		config["allowed_piece_ids"] = _piece_sets[piece_set_name].duplicate()
		return config
	return {}

func get_level_count() -> int:
	return _level_configs.size()

func get_level_shape(index: int) -> String:
	return _level_configs[index].get("grid_shape", "") if index >= 0 and index < _level_configs.size() else ""

func get_continue_level() -> int:
	return clampi(highest_unlocked_level, Constants.START_LEVEL,
		maxi(get_level_count() - 1, Constants.START_LEVEL))

func is_level_unlocked(index: int) -> bool:
	return index >= Constants.START_LEVEL and index <= highest_unlocked_level

func is_level_completed(index: int) -> bool:
	return _completed_levels.has(index)

func get_completed_level_count() -> int:
	return _completed_levels.size()

func complete_level(index: int) -> void:
	if index < Constants.START_LEVEL or index >= get_level_count():
		push_error("Leveller: cannot complete invalid level %d" % index)
		return
	_completed_levels[index] = true
	highest_unlocked_level = mini(
		maxi(highest_unlocked_level, index + 1),
		maxi(get_level_count() - 1, Constants.START_LEVEL))
	_save_progress()

func load_grid_shape(shape_name: String) -> Dictionary:
	return _grid_shapes.get(shape_name, {})

## Returns a random unused puzzle for the given shape (resets pool when exhausted).
func get_puzzle(shape_name: String) -> Dictionary:
	if not _puzzle_bank.has(shape_name):
		push_error("Leveller: no puzzles for shape '%s'" % shape_name)
		return {}
	var puzzles: Array = _puzzle_bank[shape_name]
	if selected_difficulty != "Any":
		var matching := puzzles.filter(
			func(p): return p.get("difficulty", "") == selected_difficulty)
		if not matching.is_empty():
			puzzles = matching
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

func set_difficulty(value: String) -> void:
	selected_difficulty = value

func is_word_valid(word: String) -> bool:
	return _word_set.has(word)
