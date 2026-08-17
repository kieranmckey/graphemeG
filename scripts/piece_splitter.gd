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

	# Pre-score each cell by the largest piece that could fit there (ignoring coverage).
	# Cells where large pieces fit are processed first so they aren't blocked by dots/dominos.
	var filtered_lib: Array = library.filter(func(s):
		return allowed_ids.is_empty() or allowed_ids.has((s as PieceShape).id))
	var cell_scores: Dictionary = {}
	for c in sorted_cells:
		var cr: int = c[0]; var cc: int = c[1]
		var best := 1
		for shape in filtered_lib:
			for rot in range((shape as PieceShape).rotation_count()):
				var offsets: Array = (shape as PieceShape).get_cells(rot)
				for ai in range(offsets.size()):
					var anch: Vector2i = offsets[ai]
					var fits := true
					for off in offsets:
						if not cell_set.has(_key(cr + (off as Vector2i).x - anch.x,
												cc + (off as Vector2i).y - anch.y)):
							fits = false; break
					if fits:
						best = max(best, offsets.size()); break
			cell_scores[_key(cr, cc)] = best
	sorted_cells.sort_custom(func(a, b):
		return cell_scores.get(_key(a[0],a[1]),1) > cell_scores.get(_key(b[0],b[1]),1))

	var covered: Dictionary = {}
	var result: Array = []

	for c in sorted_cells:
		var row: int = c[0]
		var col: int = c[1]
		if covered.has(_key(row, col)):
			continue

		# Shuffle within size groups for variety, then sort largest-first
		var lib_copy: Array = filtered_lib.duplicate()
		for i in range(lib_copy.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = lib_copy[i]; lib_copy[i] = lib_copy[j]; lib_copy[j] = tmp
		lib_copy.sort_custom(func(a, b):
			return (a as PieceShape).get_cells(0).size() > (b as PieceShape).get_cells(0).size())

		var placed := false
		for shape in lib_copy:
			for rot in range((shape as PieceShape).rotation_count()):
				var offsets: Array = shape.get_cells(rot)
				# Try each cell of the piece as the anchor so pieces whose
				# bounding-box origin is empty (e.g. cross) can still be placed.
				for ai in range(offsets.size()):
					var anchor: Vector2i = offsets[ai]
					var abs_cells: Array[Vector2i] = []
					var valid := true
					for off in offsets:
						var ar: int = row + (off as Vector2i).x - anchor.x
						var ac: int = col + (off as Vector2i).y - anchor.y
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
					# origin = grid position of piece-local (0,0), matching start_tile in grid.gd
					result.append({
						"shape": shape, "rotation": rot,
						"origin": Vector2i(row - anchor.x, col - anchor.y),
						"cells": abs_cells, "letters": letters
					})
					for cell in abs_cells:
						covered[_key(cell.x, cell.y)] = true
					placed = true
					break
				if placed:
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
