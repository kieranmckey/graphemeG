## piece_shape.gd
## Defines a tetromino-like piece shape with all rotations.
## Cells are stored as Vector2i(row_offset, col_offset) from the top-left origin.
class_name PieceShape
extends RefCounted

var id: String = ""
var _rotations: Array = []   # Array of Array[Vector2i]

static func load_library() -> Array:
	var file := FileAccess.open(Constants.PIECE_LIBRARY_PATH, FileAccess.READ)
	if not file:
		push_error("PieceShape: cannot open " + Constants.PIECE_LIBRARY_PATH)
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary) or not parsed.has("pieces"):
		return []

	var result: Array = []
	for entry in parsed["pieces"]:
		var shape := PieceShape.new()
		shape.id = entry["id"]
		var base_bitmap: Array = entry["rotations"][0]
		var cells: Array[Vector2i] = []
		for r in range(base_bitmap.size()):
			for c in range((base_bitmap[r] as Array).size()):
				if (base_bitmap[r] as Array)[c] == 1:
					cells.append(Vector2i(r, c))
		for rotation in range(4):
			shape._rotations.append(cells)
			cells = _rotate_cells_clockwise(cells)
		result.append(shape)
	return result

static func _rotate_cells_clockwise(source: Array[Vector2i]) -> Array[Vector2i]:
	if source.is_empty():
		return []
	var max_row: int = source[0].x
	for cell in source:
		max_row = max(max_row, (cell as Vector2i).x)
	var rotated: Array[Vector2i] = []
	for cell in source:
		var v := cell as Vector2i
		rotated.append(Vector2i(v.y, max_row - v.x))
	var min_row: int = rotated[0].x
	var min_col: int = rotated[0].y
	for cell in rotated:
		min_row = min(min_row, (cell as Vector2i).x)
		min_col = min(min_col, (cell as Vector2i).y)
	for i in range(rotated.size()):
		rotated[i] = Vector2i(rotated[i].x - min_row, rotated[i].y - min_col)
	rotated.sort_custom(func(a, b):
		return a.x < b.x if a.x != b.x else a.y < b.y)
	return rotated

func remap_letters(source_letters: Array, from_rotation: int,
		to_rotation: int) -> Array:
	var mapped: Array = source_letters.duplicate()
	var steps := posmod(to_rotation - from_rotation, 4)
	for _step in range(steps):
		var old_cells: Array = get_cells(from_rotation)
		var new_cells: Array = get_cells(from_rotation + 1)
		var next: Array = []
		next.resize(new_cells.size())
		var max_row: int = 0
		for cell in old_cells:
			max_row = max(max_row, (cell as Vector2i).x)
		for i in range(old_cells.size()):
			var old := old_cells[i] as Vector2i
			var rotated := Vector2i(old.y, max_row - old.x)
			var min_row := 999
			var min_col := 999
			for cell in old_cells:
				var v := cell as Vector2i
				min_row = min(min_row, v.y)
				min_col = min(min_col, max_row - v.x)
			rotated -= Vector2i(min_row, min_col)
			var target_index := new_cells.find(rotated)
			if target_index >= 0:
				next[target_index] = mapped[i]
		mapped = next
		from_rotation += 1
	return mapped

func remap_cell(source_cell: Vector2i, from_rotation: int,
		to_rotation: int) -> Vector2i:
	var mapped := source_cell
	var steps := posmod(to_rotation - from_rotation, 4)
	for _step in range(steps):
		var old_cells: Array = get_cells(from_rotation)
		var max_row: int = 0
		var min_row: int = 999
		var min_col: int = 999
		for cell in old_cells:
			var v := cell as Vector2i
			max_row = max(max_row, v.x)
			min_row = min(min_row, v.y)
			min_col = min(min_col, max_row - v.x)
		mapped = Vector2i(mapped.y, max_row - mapped.x)
		mapped -= Vector2i(min_row, min_col)
		from_rotation += 1
	return mapped

func get_pivot_cell(rotation: int) -> Vector2i:
	if id == "cross" or id == "tetromino_T":
		return remap_cell(Vector2i(1, 1) if id == "cross" else Vector2i(0, 1), 0, rotation)
	var rotation_cells: Array = get_cells(rotation)
	return rotation_cells[0] if not rotation_cells.is_empty() else Vector2i.ZERO

func get_cells(rot: int) -> Array:
	if _rotations.is_empty():
		return []
	return _rotations[rot % _rotations.size()]

func rotation_count() -> int:
	return _rotations.size()
