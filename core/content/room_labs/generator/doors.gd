extends RefCounted
class_name RoomLabsGeneratorDoors

const RoomData = RoomLabsGeneratorRooms.RoomData

static func plan_door_openings(
	rooms_by_key: Dictionary[String, RoomData],
	neighbors_by_key: Dictionary,
	rng: RandomNumberGenerator,
	doorway_height: float,
	door_floor_snap_threshold: float,
	door_split_min_delta: float,
	elevated_door_chance: float
) -> Dictionary[String, float]:
	var door_bottom_by_side: Dictionary[String, float] = {}
	var traversal: Array[Vector2i] = __build_generation_walk(rooms_by_key, neighbors_by_key)
	var last_local_by_room_key: Dictionary = {}

	for i: int in range(maxi(traversal.size() - 1, 0)):
		__assign_edge_door_opening(
			rooms_by_key,
			rng,
			doorway_height,
			door_floor_snap_threshold,
			door_split_min_delta,
			elevated_door_chance,
			door_bottom_by_side,
			last_local_by_room_key,
			traversal[i],
			traversal[i + 1]
		)

	# Fallback for disconnected/non-linear cases: ensure every edge still receives a valid assignment.
	for room_key: String in rooms_by_key.keys():
		var room: RoomData = rooms_by_key[room_key]
		var neighbors: Array = neighbors_by_key.get(room_key, [])
		for neighbor_coord: Vector2i in neighbors:
			if !__should_process_edge(room.coord, neighbor_coord):
				continue
			var dir: Vector2i = neighbor_coord - room.coord
			if absi(dir.x) + absi(dir.y) != 1:
				continue
			var side_key: String = __side_key(room.coord, dir)
			if door_bottom_by_side.has(side_key):
				continue
			__assign_edge_door_opening(
				rooms_by_key,
				rng,
				doorway_height,
				door_floor_snap_threshold,
				door_split_min_delta,
				elevated_door_chance,
				door_bottom_by_side,
				last_local_by_room_key,
				room.coord,
				neighbor_coord
			)

	return door_bottom_by_side

static func door_bottom_for_side(
	coord: Vector2i,
	dir: Vector2i,
	room_height_local: float,
	door_bottom_by_side: Dictionary[String, float],
	doorway_height: float,
	door_floor_snap_threshold: float
) -> float:
	var key: String = __side_key(coord, dir)
	if !door_bottom_by_side.has(key):
		return 0.0
	var raw_bottom: float = door_bottom_by_side[key]
	return __quantize_door_bottom(
		raw_bottom,
		__max_door_bottom_from_height(room_height_local, doorway_height),
		door_floor_snap_threshold
	)

static func build_wall_with_optional_door(
	geom_root: Node3D,
	wall_center_at_floor: Vector3,
	length: float,
	along_x: bool,
	has_opening: bool,
	room_height_local: float,
	door_bottom: float,
	corridor_width: float,
	doorway_height: float,
	wall_thickness: float
) -> void:
	var door_width: float = __door_width_for_length(corridor_width, length)
	var side_length: float = (length - door_width) * 0.5
	var max_bottom: float = __max_door_bottom_from_height(room_height_local, doorway_height)
	var clamped_bottom: float = clampf(door_bottom, 0.0, max_bottom)
	var clear_height: float = maxf(
		minf(doorway_height, room_height_local - clamped_bottom - 0.2),
		1.4
	)
	var upper_height: float = room_height_local - (clamped_bottom + clear_height)

	if !has_opening or side_length <= 0.25:
		var full_size: Vector3 = (
			Vector3(length, room_height_local, wall_thickness)
			if along_x
			else Vector3(wall_thickness, room_height_local, length)
		)
		RoomLabsGeneratorBoxes.add_solid_box(
			geom_root,
			"wall_full",
			full_size,
			wall_center_at_floor + Vector3(0.0, room_height_local * 0.5, 0.0),
			RoomLabsGeneratorMaterials.mat_wall
		)
		return

	if side_length > 0.3:
		var side_size: Vector3 = (
			Vector3(side_length, room_height_local, wall_thickness)
			if along_x
			else Vector3(wall_thickness, room_height_local, side_length)
		)
		var side_offset: float = door_width * 0.5 + side_length * 0.5
		var side_axis: Vector3 = (
			Vector3(side_offset, 0.0, 0.0)
			if along_x
			else Vector3(0.0, 0.0, side_offset)
		)
		RoomLabsGeneratorBoxes.add_solid_box(
			geom_root,
			"wall_side_a",
			side_size,
			wall_center_at_floor + Vector3(0.0, room_height_local * 0.5, 0.0) - side_axis,
			RoomLabsGeneratorMaterials.mat_wall
		)
		RoomLabsGeneratorBoxes.add_solid_box(
			geom_root,
			"wall_side_b",
			side_size,
			wall_center_at_floor + Vector3(0.0, room_height_local * 0.5, 0.0) + side_axis,
			RoomLabsGeneratorMaterials.mat_wall
		)

	if clamped_bottom > 0.1:
		var lower_fill_size: Vector3 = (
			Vector3(door_width, clamped_bottom, wall_thickness)
			if along_x
			else Vector3(wall_thickness, clamped_bottom, door_width)
		)
		RoomLabsGeneratorBoxes.add_solid_box(
			geom_root,
			"wall_door_lower_fill",
			lower_fill_size,
			wall_center_at_floor + Vector3(0.0, clamped_bottom * 0.5, 0.0),
			RoomLabsGeneratorMaterials.mat_wall
		)

	if upper_height > 0.15:
		var upper_size: Vector3 = (
			Vector3(door_width, upper_height, wall_thickness)
			if along_x
			else Vector3(wall_thickness, upper_height, door_width)
		)
		RoomLabsGeneratorBoxes.add_solid_box(
			geom_root,
			"wall_lintel",
			upper_size,
			wall_center_at_floor + Vector3(0.0, clamped_bottom + clear_height + upper_height * 0.5, 0.0),
			RoomLabsGeneratorMaterials.mat_wall
		)

static func __door_width_for_length(corridor_width: float, wall_length: float) -> float:
	return maxf(1.25, minf(corridor_width + 1.0, wall_length - 2.0))

static func __sample_single_door_bottom(
	rng: RandomNumberGenerator,
	max_bottom: float,
	elevated_door_chance: float,
	door_floor_snap_threshold: float
) -> float:
	if max_bottom <= 0.0:
		return 0.0
	if rng.randf() >= elevated_door_chance:
		return 0.0
	return __sample_elevated_door_bottom(rng, max_bottom, door_floor_snap_threshold)

static func __sample_two_door_bottoms(
	rng: RandomNumberGenerator,
	max_bottom: float,
	elevated_door_chance: float,
	door_split_min_delta: float,
	door_floor_snap_threshold: float
) -> Array[float]:
	var out: Array[float] = [0.0, 0.0]
	if max_bottom <= 0.0:
		return out

	var roll: float = rng.randf()
	if roll < 0.24:
		return out

	if roll < 0.52:
		var shared: float = __sample_single_door_bottom(
			rng,
			max_bottom,
			elevated_door_chance,
			door_floor_snap_threshold
		)
		return [shared, shared]

	if roll < 0.74:
		var elevated: float = __sample_elevated_door_bottom(rng, max_bottom, door_floor_snap_threshold)
		if rng.randf() < 0.5:
			return [0.0, elevated]
		return [elevated, 0.0]

	var first: float = __sample_elevated_door_bottom(rng, max_bottom, door_floor_snap_threshold)
	var second: float = __sample_elevated_door_bottom(rng, max_bottom, door_floor_snap_threshold)
	for _attempt: int in range(12):
		if absf(first - second) >= door_split_min_delta:
			break
		second = __sample_elevated_door_bottom(rng, max_bottom, door_floor_snap_threshold)

	if absf(first - second) < door_split_min_delta:
		var push_sign: float = 1.0 if rng.randf() < 0.5 else -1.0
		second = __quantize_door_bottom(
			first + push_sign * door_split_min_delta,
			max_bottom,
			door_floor_snap_threshold
		)
		if second <= 0.0:
			second = __sample_elevated_door_bottom(rng, max_bottom, door_floor_snap_threshold)

	return [first, second]

static func __sample_elevated_door_bottom(
	rng: RandomNumberGenerator,
	max_bottom: float,
	door_floor_snap_threshold: float
) -> float:
	var min_bottom: float = door_floor_snap_threshold + 0.2
	if max_bottom <= min_bottom:
		return 0.0
	for _attempt: int in range(8):
		var candidate: float = rng.randf_range(min_bottom, max_bottom)
		candidate = __quantize_door_bottom(candidate, max_bottom, door_floor_snap_threshold)
		if candidate >= door_floor_snap_threshold:
			return candidate
	return __quantize_door_bottom(max_bottom, max_bottom, door_floor_snap_threshold)

static func __quantize_door_bottom(
	value: float,
	max_bottom: float,
	door_floor_snap_threshold: float
) -> float:
	var clamped: float = clampf(value, 0.0, max_bottom)
	var snapped_value: float = snappedf(clamped, 0.25)
	if snapped_value < door_floor_snap_threshold:
		return 0.0
	return clampf(snapped_value, 0.0, max_bottom)

static func __assign_edge_door_opening(
	rooms_by_key: Dictionary[String, RoomData],
	rng: RandomNumberGenerator,
	doorway_height: float,
	door_floor_snap_threshold: float,
	door_split_min_delta: float,
	elevated_door_chance: float,
	door_bottom_by_side: Dictionary[String, float],
	last_local_by_room_key: Dictionary,
	a_coord: Vector2i,
	b_coord: Vector2i
) -> void:
	var key_a: String = __coord_key(a_coord)
	var key_b: String = __coord_key(b_coord)
	if !rooms_by_key.has(key_a) or !rooms_by_key.has(key_b):
		return
	var direction: Vector2i = b_coord - a_coord
	if absi(direction.x) + absi(direction.y) != 1:
		return

	var room_a: RoomData = rooms_by_key[key_a]
	var room_b: RoomData = rooms_by_key[key_b]
	var max_bottom_a: float = __max_door_bottom_from_height(room_a.height, doorway_height)
	var max_bottom_b: float = __max_door_bottom_from_height(room_b.height, doorway_height)
	var has_previous_local: bool = last_local_by_room_key.has(key_a)
	var previous_local: float = float(last_local_by_room_key[key_a]) if has_previous_local else 0.0
	var preferred_local_a: float = __sample_local_from_room_context(
		rng,
		max_bottom_a,
		has_previous_local,
		previous_local,
		elevated_door_chance,
		door_split_min_delta,
		door_floor_snap_threshold
	)
	var preferred_world: float = room_a.center.y + preferred_local_a
	var shared_world: float = __solve_shared_world_height(
		room_a.center.y,
		max_bottom_a,
		room_b.center.y,
		max_bottom_b,
		preferred_world,
		door_floor_snap_threshold
	)
	if is_nan(shared_world):
		var world_min: float = maxf(room_a.center.y, room_b.center.y)
		var world_max: float = minf(room_a.center.y + max_bottom_a, room_b.center.y + max_bottom_b)
		if world_max < world_min:
			shared_world = world_min
		else:
			shared_world = snappedf(clampf(preferred_world, world_min, world_max), 0.25)

	var local_a: float = __quantize_door_bottom(
		shared_world - room_a.center.y,
		max_bottom_a,
		door_floor_snap_threshold
	)
	var local_b: float = __quantize_door_bottom(
		shared_world - room_b.center.y,
		max_bottom_b,
		door_floor_snap_threshold
	)
	var world_a: float = room_a.center.y + local_a
	var world_b: float = room_b.center.y + local_b
	if absf(world_a - world_b) > 0.001:
		var solved_world: float = __solve_shared_world_height(
			room_a.center.y,
			max_bottom_a,
			room_b.center.y,
			max_bottom_b,
			shared_world,
			door_floor_snap_threshold
		)
		if !is_nan(solved_world):
			local_a = __quantize_door_bottom(
				solved_world - room_a.center.y,
				max_bottom_a,
				door_floor_snap_threshold
			)
			local_b = __quantize_door_bottom(
				solved_world - room_b.center.y,
				max_bottom_b,
				door_floor_snap_threshold
			)

	door_bottom_by_side[__side_key(a_coord, direction)] = local_a
	door_bottom_by_side[__side_key(b_coord, -direction)] = local_b
	last_local_by_room_key[key_a] = local_a
	last_local_by_room_key[key_b] = local_b

static func __sample_local_from_room_context(
	rng: RandomNumberGenerator,
	max_bottom: float,
	has_previous_local: bool,
	previous_local: float,
	elevated_door_chance: float,
	door_split_min_delta: float,
	door_floor_snap_threshold: float
) -> float:
	if max_bottom <= 0.0:
		return 0.0
	if !has_previous_local:
		return __sample_single_door_bottom(rng, max_bottom, elevated_door_chance, door_floor_snap_threshold)
	if rng.randf() < 0.28:
		return __quantize_door_bottom(previous_local, max_bottom, door_floor_snap_threshold)

	var candidate: float = __sample_single_door_bottom(
		rng,
		max_bottom,
		elevated_door_chance,
		door_floor_snap_threshold
	)
	if absf(candidate - previous_local) >= door_split_min_delta:
		return candidate

	var push_sign: float = 1.0 if rng.randf() < 0.5 else -1.0
	var pushed: float = __quantize_door_bottom(
		previous_local + push_sign * door_split_min_delta,
		max_bottom,
		door_floor_snap_threshold
	)
	if absf(pushed - previous_local) >= 0.25:
		return pushed
	return __sample_elevated_door_bottom(rng, max_bottom, door_floor_snap_threshold)

static func __solve_shared_world_height(
	floor_a: float,
	max_bottom_a: float,
	floor_b: float,
	max_bottom_b: float,
	preferred_world: float,
	door_floor_snap_threshold: float
) -> float:
	var world_min: float = maxf(floor_a, floor_b)
	var world_max: float = minf(floor_a + max_bottom_a, floor_b + max_bottom_b)
	if world_max < world_min:
		return NAN

	var step_start: int = ceili(world_min * 4.0 - 0.0001)
	var step_end: int = floori(world_max * 4.0 + 0.0001)
	var best_world: float = NAN
	var best_distance: float = INF
	for step: int in range(step_start, step_end + 1):
		var candidate_world: float = float(step) * 0.25
		var local_a: float = __quantize_door_bottom(
			candidate_world - floor_a,
			max_bottom_a,
			door_floor_snap_threshold
		)
		var local_b: float = __quantize_door_bottom(
			candidate_world - floor_b,
			max_bottom_b,
			door_floor_snap_threshold
		)
		var aligned_world_a: float = floor_a + local_a
		var aligned_world_b: float = floor_b + local_b
		if absf(aligned_world_a - aligned_world_b) > 0.001:
			continue
		var distance: float = absf(aligned_world_a - preferred_world)
		if distance < best_distance:
			best_distance = distance
			best_world = aligned_world_a
	return best_world

static func __build_generation_walk(
	rooms_by_key: Dictionary[String, RoomData],
	neighbors_by_key: Dictionary
) -> Array[Vector2i]:
	if rooms_by_key.is_empty():
		return []

	var start: Vector2i = Vector2i.ZERO
	if !rooms_by_key.has(__coord_key(start)):
		start = __coord_from_key(str(rooms_by_key.keys()[0]))

	var walk: Array[Vector2i] = []
	var visited: Dictionary = {}
	var current: Vector2i = start

	while true:
		var current_key: String = __coord_key(current)
		if visited.has(current_key):
			break
		visited[current_key] = true
		walk.append(current)
		var next_found: bool = false
		for neighbor_coord: Vector2i in neighbors_by_key.get(current_key, []):
			if visited.has(__coord_key(neighbor_coord)):
				continue
			current = neighbor_coord
			next_found = true
			break
		if !next_found:
			break

	return walk

static func __coord_from_key(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

static func __should_process_edge(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y

static func __max_door_bottom_from_height(room_height_local: float, doorway_height: float) -> float:
	var nominal_clear_height: float = minf(doorway_height, room_height_local - 0.4)
	return maxf(room_height_local - nominal_clear_height - 0.2, 0.0)

static func __side_key(coord: Vector2i, dir: Vector2i) -> String:
	return "%s|%d,%d" % [__coord_key(coord), dir.x, dir.y]

static func __coord_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]
