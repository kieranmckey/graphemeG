## piece_splitter.gd
## Partitions a filled crossword grid into piece shapes from the library.
## Returns the model solution — an Array of placement Dictionaries.
##
## Each entry: { "shape": PieceShape, "rotation": int, "origin": Vector2i,
##               "cells": Array[Vector2i], "letters": Array[String] }
class_name PieceSplitter

static func split(shape_cells: Array, fill: Array, library: Array,
		rng: RandomNumberGenerator, allowed_ids: Array) -> Array:

	# Build set of all grid cells for fast membership test
	var cell_set: Dictionary = {}
	for c in shape_cells:
		cell_set[_key(c[0], c[1])] = true

	# Sort cells in reading order (row-major)
	var sorted_cells: Array = shape_cells.duplicate()
	sorted_cells.sort_custom(func(a, b):
		return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])

	var covered: Dictionary = {}
	var result: Array = []

	for c in sorted_cells:
		var row: int = c[0]
		var col: int = c[1]
		if covered.has(_key(row, col)):
			continue

		# Shuffle library for random piece selection each iteration
		var lib_copy: Array = library.duplicate()
		for i in range(lib_copy.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = lib_copy[i]; lib_copy[i] = lib_copy[j]; lib_copy[j] = tmp

		var placed := false
		for shape in lib_copy:
			if not allowed_ids.is_empty() and not allowed_ids.has(shape.id):
				continue
			for rot in range(shape.rotation_count()):
				var offsets: Array = shape.get_cells(rot)
				var abs_cells: Array[Vector2i] = []
				var valid := true
				for off in offsets:
					var ar: int = row + off.x
					var ac: int = col + off.y
					var k := _key(ar, ac)
					if not cell_set.has(k) or covered.has(k):
						valid = false
						break
					abs_cells.append(Vector2i(ar, ac))
				if not valid:
					continue
				var letters: Array[String] = []
				for cell in abs_cells:
					letters.append(_letter(fill, cell.x, cell.y))
				result.append({
					"shape": shape, "rotation": rot,
					"origin": Vector2i(row, col),
					"cells": abs_cells, "letters": letters
				})
				for cell in abs_cells:
					covered[_key(cell.x, cell.y)] = true
				placed = true
				break
			if placed:
				break

		if not placed:
			# Fallback: dot (1-cell piece) — should always exist in library
			for shape in library:
				if shape.id == "dot":
					result.append({
						"shape": shape, "rotation": 0,
						"origin": Vector2i(row, col),
						"cells": [Vector2i(row, col)],
						"letters": [_letter(fill, row, col)]
					})
					covered[_key(row, col)] = true
					break

	return result

static func _key(row: int, col: int) -> int:
	return row * 10000 + col

static func _letter(fill: Array, row: int, col: int) -> String:
	if row < 0 or row >= fill.size():
		return "?"
	var row_data = fill[row]
	if col < 0 or col >= (row_data as Array).size():
		return "?"
	var v = (row_data as Array)[col]
	return str(v) if v != null else "?"
