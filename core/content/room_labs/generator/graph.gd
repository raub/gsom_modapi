extends RefCounted
class_name RoomLabsGeneratorGraph

const CARDINAL_DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const RoomEdge = RoomLabsGeneratorRooms.RoomEdge
const RoomData = RoomLabsGeneratorRooms.RoomData

class LayoutGraph:
	var rooms_by_key: Dictionary[String, RoomData] = {}
	var neighbors_by_key: Dictionary = {}
	var edges: Array[RoomEdge] = []

static func build_layout_graph(
	rng: RandomNumberGenerator,
	room_count: int,
	grid_radius: int,
	grid_step: float,
	combat_room_ratio: float,
	room_width_min: float,
	room_width_max: float,
	room_depth_min: float,
	room_depth_max: float,
	combat_width_min: float,
	combat_width_max: float,
	combat_depth_min: float,
	combat_depth_max: float,
	corridor_width: float,
	room_height: float,
	room_height_variation: float,
	adjacent_room_height_min_delta: float,
	corridor_target_length: float,
	room_cell_margin: float
) -> LayoutGraph:
	var graph: LayoutGraph = LayoutGraph.new()
	var grid_diameter: int = grid_radius * 2 + 1
	var max_rooms_in_grid: int = grid_diameter * grid_diameter
	var target_rooms: int = clampi(room_count, 1, max_rooms_in_grid)
	var path: Array[Vector2i] = __build_linear_room_path(rng, target_rooms, grid_radius)
	if path.is_empty():
		path = [Vector2i.ZERO]

	for i: int in range(path.size()):
		var coord: Vector2i = path[i]
		var adjacent_height_ref: float = -1.0
		if i > 0:
			var prev_key: String = __coord_key(path[i - 1])
			if graph.rooms_by_key.has(prev_key):
				var prev_room: RoomData = graph.rooms_by_key[prev_key]
				adjacent_height_ref = prev_room.height
		__add_room(
			rng,
			graph.rooms_by_key,
			graph.neighbors_by_key,
			coord,
			i == 0 or rng.randf() < combat_room_ratio,
			grid_step,
			room_width_min,
			room_width_max,
			room_depth_min,
			room_depth_max,
			combat_width_min,
			combat_width_max,
			combat_depth_min,
			combat_depth_max,
			corridor_width,
			room_height,
			room_height_variation,
			adjacent_room_height_min_delta,
			room_cell_margin,
			adjacent_height_ref
		)
		if i > 0:
			__connect_rooms(graph.neighbors_by_key, graph.edges, path[i - 1], coord)

	__compact_connected_room_spans(
		graph.rooms_by_key,
		graph.edges,
		corridor_target_length,
		corridor_width,
		grid_step,
		room_cell_margin
	)

	return graph

static func __build_linear_room_path(
	rng: RandomNumberGenerator,
	target_rooms: int,
	grid_radius: int
) -> Array[Vector2i]:
	var best_path: Array[Vector2i] = [Vector2i.ZERO]
	var max_attempts: int = 40

	for _attempt: int in range(max_attempts):
		var occupied: Dictionary = {}
		var path: Array[Vector2i] = [Vector2i.ZERO]
		occupied[__coord_key(Vector2i.ZERO)] = true

		var guard_steps: int = target_rooms * 128
		while path.size() < target_rooms and guard_steps > 0:
			guard_steps -= 1
			var current: Vector2i = path[path.size() - 1]
			var candidates: Array[Vector2i] = __available_neighbors_for_path(current, occupied, grid_radius)

			if candidates.is_empty():
				if path.size() <= 1:
					break
				var removed: Vector2i = path.pop_back()
				occupied.erase(__coord_key(removed))
				continue

			var next_coord: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
			path.append(next_coord)
			occupied[__coord_key(next_coord)] = true

		if path.size() > best_path.size():
			best_path = path.duplicate()
		if path.size() >= target_rooms:
			return path

	return best_path

static func __add_room(
	rng: RandomNumberGenerator,
	rooms_by_key: Dictionary[String, RoomData],
	neighbors_by_key: Dictionary,
	coord: Vector2i,
	force_combat: bool,
	grid_step: float,
	room_width_min: float,
	room_width_max: float,
	room_depth_min: float,
	room_depth_max: float,
	combat_width_min: float,
	combat_width_max: float,
	combat_depth_min: float,
	combat_depth_max: float,
	corridor_width: float,
	room_height: float,
	room_height_variation: float,
	adjacent_room_height_min_delta: float,
	room_cell_margin: float,
	adjacent_height_ref: float = -1.0
) -> void:
	var is_combat: bool = force_combat
	var width: float
	var depth: float
	if is_combat:
		width = rng.randf_range(combat_width_min, combat_width_max)
		depth = rng.randf_range(combat_depth_min, combat_depth_max)
	else:
		width = rng.randf_range(room_width_min, room_width_max)
		depth = rng.randf_range(room_depth_min, room_depth_max)

	var max_room_span: float = __max_room_span(corridor_width, grid_step, room_cell_margin)
	width = min(width, max_room_span)
	depth = min(depth, max_room_span)
	width = max(width, corridor_width + 2.0)
	depth = max(depth, corridor_width + 2.0)

	var room_data: RoomData = RoomData.new()
	room_data.coord = coord
	room_data.center = Vector3(float(coord.x) * grid_step, 0.0, float(coord.y) * grid_step)
	room_data.width = width
	room_data.depth = depth
	room_data.height = __sample_room_height(
		rng,
		room_height,
		room_height_variation,
		adjacent_room_height_min_delta,
		adjacent_height_ref
	)
	room_data.combat = is_combat
	var key: String = __coord_key(coord)
	rooms_by_key[key] = room_data
	neighbors_by_key[key] = []

static func __sample_room_height(
	rng: RandomNumberGenerator,
	room_height: float,
	room_height_variation: float,
	adjacent_room_height_min_delta: float,
	adjacent_height_ref: float = -1.0
) -> float:
	var min_height: float = room_height
	if room_height_variation <= 0.0:
		return min_height

	var max_height: float = min_height + room_height_variation
	if adjacent_height_ref < 0.0:
		return rng.randf_range(min_height, max_height)

	var required_delta: float = minf(adjacent_room_height_min_delta, room_height_variation)
	if required_delta <= 0.0:
		return rng.randf_range(min_height, max_height)

	for _attempt: int in range(12):
		var candidate: float = rng.randf_range(min_height, max_height)
		if absf(candidate - adjacent_height_ref) >= required_delta:
			return candidate

	var distance_to_min: float = absf(adjacent_height_ref - min_height)
	var distance_to_max: float = absf(adjacent_height_ref - max_height)
	if distance_to_max >= distance_to_min:
		var high_band_start: float = maxf(max_height - room_height_variation * 0.25, min_height)
		return rng.randf_range(high_band_start, max_height)
	var low_band_end: float = minf(min_height + room_height_variation * 0.25, max_height)
	return rng.randf_range(min_height, low_band_end)

static func __connect_rooms(
	neighbors_by_key: Dictionary,
	edges: Array[RoomEdge],
	a: Vector2i,
	b: Vector2i
) -> void:
	var key_a: String = __coord_key(a)
	var key_b: String = __coord_key(b)
	if !neighbors_by_key.has(key_a) or !neighbors_by_key.has(key_b):
		return
	var neighbors_a: Array = neighbors_by_key[key_a]
	if b in neighbors_a:
		return
	neighbors_a.append(b)
	neighbors_by_key[key_a] = neighbors_a
	var neighbors_b: Array = neighbors_by_key[key_b]
	neighbors_b.append(a)
	neighbors_by_key[key_b] = neighbors_b
	var edge: RoomEdge = RoomEdge.new()
	edge.a = a
	edge.b = b
	edges.append(edge)

static func __available_neighbors_for_path(
	base: Vector2i,
	occupied: Dictionary,
	grid_radius: int
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir: Vector2i in CARDINAL_DIRS:
		var coord: Vector2i = base + dir
		if abs(coord.x) > grid_radius or abs(coord.y) > grid_radius:
			continue
		if occupied.has(__coord_key(coord)):
			continue
		out.append(coord)
	return out

static func __compact_connected_room_spans(
	rooms_by_key: Dictionary[String, RoomData],
	edges: Array[RoomEdge],
	corridor_target_length: float,
	corridor_width: float,
	grid_step: float,
	room_cell_margin: float
) -> void:
	if edges.is_empty():
		return

	var target_corridor: float = maxf(corridor_target_length, 0.0)
	var max_room_span: float = __max_room_span(corridor_width, grid_step, room_cell_margin)
	var max_iterations: int = 4

	for _iteration: int in range(max_iterations):
		var changed: bool = false
		for edge: RoomEdge in edges:
			var a_room: RoomData = rooms_by_key[__coord_key(edge.a)]
			var b_room: RoomData = rooms_by_key[__coord_key(edge.b)]
			var direction: Vector2i = edge.b - edge.a
			if direction == Vector2i.RIGHT or direction == Vector2i.LEFT:
				var clear_x: float = maxf(
					absf(a_room.center.x - b_room.center.x) - a_room.width * 0.5 - b_room.width * 0.5,
					0.0
				)
				if clear_x > target_corridor:
					var growth_needed: float = (clear_x - target_corridor) * 2.0
					changed = __expand_room_pair_axis(a_room, b_room, true, growth_needed, max_room_span) or changed
				continue
			if direction == Vector2i.UP or direction == Vector2i.DOWN:
				var clear_z: float = maxf(
					absf(a_room.center.z - b_room.center.z) - a_room.depth * 0.5 - b_room.depth * 0.5,
					0.0
				)
				if clear_z > target_corridor:
					var growth_needed_z: float = (clear_z - target_corridor) * 2.0
					changed = __expand_room_pair_axis(a_room, b_room, false, growth_needed_z, max_room_span) or changed
		if !changed:
			return

static func __expand_room_pair_axis(
	a_room: RoomData,
	b_room: RoomData,
	along_x: bool,
	total_growth: float,
	max_room_span: float
) -> bool:
	if total_growth <= 0.0:
		return false

	var a_size: float = a_room.width if along_x else a_room.depth
	var b_size: float = b_room.width if along_x else b_room.depth
	var a_capacity: float = maxf(max_room_span - a_size, 0.0)
	var b_capacity: float = maxf(max_room_span - b_size, 0.0)
	if a_capacity <= 0.0 and b_capacity <= 0.0:
		return false

	var grow_a: float = minf(total_growth * 0.5, a_capacity)
	var grow_b: float = minf(total_growth * 0.5, b_capacity)
	var remaining: float = total_growth - (grow_a + grow_b)

	if remaining > 0.0:
		var extra_a: float = minf(remaining, a_capacity - grow_a)
		grow_a += extra_a
		remaining -= extra_a
	if remaining > 0.0:
		var extra_b: float = minf(remaining, b_capacity - grow_b)
		grow_b += extra_b

	if grow_a <= 0.001 and grow_b <= 0.001:
		return false

	if along_x:
		a_room.width += grow_a
		b_room.width += grow_b
	else:
		a_room.depth += grow_a
		b_room.depth += grow_b
	return true

static func __max_room_span(corridor_width: float, grid_step: float, room_cell_margin: float) -> float:
	var min_room_span: float = corridor_width + 2.0
	var bounded_span: float = grid_step - room_cell_margin
	return maxf(min_room_span, bounded_span)

static func __coord_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]
