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

	var open_heap: Array[Vector2i] = [start_cell]
	var open_lookup: Dictionary = {}
	open_lookup[_cell_key(start_cell)] = true
	var closed_set: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}

	g_score[_cell_key(start_cell)] = 0.0
	f_score[_cell_key(start_cell)] = _heuristic(start_cell, end_cell)

	var neighbor_dirs := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	var neighbor_costs: Array[float] = [1.0, 1.0, 1.0, 1.0, SQRT2, SQRT2, SQRT2, SQRT2]

	const MAX_ITER: int = 1500
	const STAGNANT_LIMIT: int = 500
	var iter: int = 0
	var stagnant: int = 0
	var best_cell: Vector2i = start_cell
	var best_dist: float = _heuristic(start_cell, end_cell)

	while not open_heap.is_empty():
		var current: Vector2i = _heap_pop(open_heap, f_score)
		var current_key: String = _cell_key(current)
		open_lookup.erase(current_key)

		if closed_set.has(current_key):
			continue
		closed_set[current_key] = true
		iter += 1

		if current == end_cell:
			return _reconstruct_path(came_from, current, start_cell)

		var h := _heuristic(current, end_cell)
		if h < best_dist:
			best_dist = h
			best_cell = current
			stagnant = 0
		else:
			stagnant += 1

		if stagnant > STAGNANT_LIMIT or iter > MAX_ITER:
			return _path_or_fallback(came_from, start_cell, best_cell)

		for i in 8:
			var neighbor: Vector2i = current + neighbor_dirs[i]
			var nkey: String = _cell_key(neighbor)

			if blocked_cells.has(nkey):
				continue

			var tentative_g: float = g_score.get(current_key, INF) + neighbor_costs[i]

			if tentative_g < g_score.get(nkey, INF):
				came_from[nkey] = current
				g_score[nkey] = tentative_g
				f_score[nkey] = tentative_g + _heuristic(neighbor, end_cell) * 1.2
				if not open_lookup.has(nkey):
					_heap_push(open_heap, f_score, neighbor)
					open_lookup[nkey] = true

	return _path_or_fallback(came_from, start_cell, best_cell)

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


static func _path_or_fallback(came_from: Dictionary, start: Vector2i, best: Vector2i) -> PackedVector3Array:
	if best == start:
		return PackedVector3Array()
	return _reconstruct_path(came_from, best, start)

static func _heap_push(heap: Array[Vector2i], f_scores: Dictionary, cell: Vector2i) -> void:
	heap.append(cell)
	var idx: int = heap.size() - 1
	while idx > 0:
		var parent_idx: int = (idx - 1) / 2
		var cf: float = f_scores.get(_cell_key(heap[idx]), INF)
		var pf: float = f_scores.get(_cell_key(heap[parent_idx]), INF)
		if cf >= pf:
			break
		var tmp: Vector2i = heap[idx]
		heap[idx] = heap[parent_idx]
		heap[parent_idx] = tmp
		idx = parent_idx

static func _heap_pop(heap: Array[Vector2i], f_scores: Dictionary) -> Vector2i:
	var result: Vector2i = heap[0]
	var last: Vector2i = heap[heap.size() - 1]
	heap[0] = last
	heap.remove_at(heap.size() - 1)

	if heap.is_empty():
		return result

	var idx: int = 0
	var size: int = heap.size()
	while true:
		var smallest: int = idx
		var left: int = idx * 2 + 1
		var right: int = idx * 2 + 2

		if left < size:
			var lf: float = f_scores.get(_cell_key(heap[left]), INF)
			var sf: float = f_scores.get(_cell_key(heap[smallest]), INF)
			if lf < sf:
				smallest = left

		if right < size:
			var rf: float = f_scores.get(_cell_key(heap[right]), INF)
			var sf: float = f_scores.get(_cell_key(heap[smallest]), INF)
			if rf < sf:
				smallest = right

		if smallest == idx:
			break

		var tmp: Vector2i = heap[idx]
		heap[idx] = heap[smallest]
		heap[smallest] = tmp
		idx = smallest

	return result