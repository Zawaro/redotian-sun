class_name Pathfinder

const CELL_SIZE: float = 2.0
const SQRT2: float = 1.41421356237

static func world_to_cell(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		roundi(world_pos.x / CELL_SIZE),
		roundi(world_pos.z / CELL_SIZE)
	)

static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		cell.x * CELL_SIZE,
		0.0,
		cell.y * CELL_SIZE
	)

static func find_path(start_world: Vector3, end_world: Vector3, blocked_cells: Dictionary = {}) -> PackedVector3Array:
	var start_cell := world_to_cell(start_world)
	var end_cell := world_to_cell(end_world)

	if start_cell == end_cell:
		return PackedVector3Array()

	var open_set: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}

	var key: String = _cell_key(start_cell)
	g_score[key] = 0.0
	f_score[key] = _heuristic(start_cell, end_cell)

	var neighbor_dirs := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	var neighbor_costs: Array[float] = [1.0, 1.0, 1.0, 1.0, SQRT2, SQRT2, SQRT2, SQRT2]

	while not open_set.is_empty():
		var current: Vector2i = open_set[0]
		var current_key: String = _cell_key(current)
		var current_f: float = f_score.get(current_key, INF)
		var lowest_idx := 0
		for i in range(1, open_set.size()):
			var ck: String = _cell_key(open_set[i])
			var f: float = f_score.get(ck, INF)
			if f < current_f:
				current = open_set[i]
				current_key = ck
				current_f = f
				lowest_idx = i

		if current == end_cell:
			return _reconstruct_path(came_from, current, start_cell)

		open_set.remove_at(lowest_idx)

		for i in 8:
			var neighbor: Vector2i = current + neighbor_dirs[i]
			var nkey: String = _cell_key(neighbor)

			if blocked_cells.has(nkey):
				continue

			var tentative_g: float = g_score.get(current_key, INF) + neighbor_costs[i]

			if tentative_g < g_score.get(nkey, INF):
				came_from[nkey] = current
				g_score[nkey] = tentative_g
				f_score[nkey] = tentative_g + _heuristic(neighbor, end_cell)
				if not _is_in_open_set(open_set, neighbor):
					open_set.append(neighbor)

	push_warning("[Pathfinder] No path found from ", start_cell, " to ", end_cell)
	return PackedVector3Array()

static func _cell_key(cell: Vector2i) -> String:
	return str(cell.x) + "," + str(cell.y)

static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: float = abs(float(a.x - b.x))
	var dy: float = abs(float(a.y - b.y))
	return max(dx, dy) + (SQRT2 - 1.0) * min(dx, dy)

static func _reconstruct_path(came_from: Dictionary, current: Vector2i, start: Vector2i) -> PackedVector3Array:
	var path_cells: Array[Vector2i] = [current]
	var key: String = _cell_key(current)
	while came_from.has(key):
		current = came_from[key]
		path_cells.push_front(current)
		key = _cell_key(current)

	if path_cells.size() > 1 and path_cells[0] == start:
		path_cells.remove_at(0)

	var result := PackedVector3Array()
	for cell in path_cells:
		result.append(cell_to_world(cell))
	return result

static func _is_in_open_set(open_set: Array[Vector2i], cell: Vector2i) -> bool:
	for c in open_set:
		if c == cell:
			return true
	return false