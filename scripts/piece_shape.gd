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
		for rot_bitmap in entry["rotations"]:
			var cells: Array[Vector2i] = []
			for r in range((rot_bitmap as Array).size()):
				for c in range(((rot_bitmap as Array)[r] as Array).size()):
					if ((rot_bitmap as Array)[r] as Array)[c] == 1:
						cells.append(Vector2i(r, c))
			# Normalise: ensure min row and col are 0
			if not cells.is_empty():
				var min_r := cells[0].x
				var min_c := cells[0].y
				for cell in cells:
					min_r = min(min_r, cell.x)
					min_c = min(min_c, cell.y)
				for i in range(cells.size()):
					cells[i] = Vector2i(cells[i].x - min_r, cells[i].y - min_c)
			shape._rotations.append(cells)
		result.append(shape)
	return result

func get_cells(rot: int) -> Array:
	if _rotations.is_empty():
		return []
	return _rotations[rot % _rotations.size()]

func rotation_count() -> int:
	return _rotations.size()
