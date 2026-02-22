extends Node3D

@export var room_seed: int = 1337
@export var randomize_seed_on_ready: bool = false
@export_range(8, 64, 1) var room_count: int = 22
@export_range(2, 12, 1) var grid_radius: int = 5
@export_range(22.0, 40.0, 0.5) var grid_step: float = 30.0

@export_range(12.0, 22.0, 0.5) var room_width_min: float = 13.0
@export_range(12.0, 24.0, 0.5) var room_width_max: float = 18.0
@export_range(10.0, 22.0, 0.5) var room_depth_min: float = 12.0
@export_range(10.0, 24.0, 0.5) var room_depth_max: float = 18.0
@export_range(18.0, 34.0, 0.5) var combat_width_min: float = 20.0
@export_range(18.0, 36.0, 0.5) var combat_width_max: float = 28.0
@export_range(18.0, 34.0, 0.5) var combat_depth_min: float = 20.0
@export_range(18.0, 36.0, 0.5) var combat_depth_max: float = 28.0
@export_range(0.1, 0.8, 0.05) var combat_room_ratio: float = 0.35

@export_range(4.0, 8.0, 0.25) var room_height: float = 5.2
@export_range(0.0, 12.0, 0.25) var room_height_variation: float = 10.0
@export_range(0.0, 8.0, 0.1) var adjacent_room_height_min_delta: float = 1.4
@export_range(4.0, 12.0, 0.25) var corridor_width: float = 6.0
@export_range(0.0, 6.0, 0.25) var corridor_target_length: float = 1.0
@export_range(0.0, 2.0, 0.05) var room_cell_margin: float = 0.5
@export_range(2.2, 4.5, 0.1) var doorway_height: float = 3.2
@export_range(0.2, 1.0, 0.05) var wall_thickness: float = 0.5
@export_range(0.2, 1.2, 0.05) var floor_thickness: float = 0.45
@export_range(0.5, 2.0, 0.1) var door_floor_snap_threshold: float = 1.0
@export_range(1.0, 4.0, 0.1) var door_split_min_delta: float = 2.0
@export_range(1.5, 5.0, 0.1) var door_bridge_min_height: float = 3.0
@export_range(0.05, 0.95, 0.05) var elevated_door_chance: float = 0.65

const GENERATED_ROOT_NAME: StringName = &"GeneratedLabs"
const GENERATED_ROOT_PATH: NodePath = ^"GeneratedLabs"
const CARDINAL_DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

class RoomEdge:
	var a: Vector2i = Vector2i.ZERO
	var b: Vector2i = Vector2i.ZERO

class RoomData:
	var coord: Vector2i = Vector2i.ZERO
	var center: Vector3 = Vector3.ZERO
	var width: float = 0.0
	var depth: float = 0.0
	var height: float = 0.0
	var combat: bool = false

var __rng: RandomNumberGenerator = RandomNumberGenerator.new()
var __rooms_by_key: Dictionary[String, RoomData] = {}
var __neighbors_by_key: Dictionary = {}
var __edges: Array[RoomEdge] = []
var __door_bottom_by_side: Dictionary[String, float] = {}

func _ready() -> void:
	if randomize_seed_on_ready:
		room_seed = randi()
	generate()

func generate() -> void:
	__clear_previous_generation()
	__rng.seed = room_seed
	__rooms_by_key.clear()
	__neighbors_by_key.clear()
	__edges.clear()
	__door_bottom_by_side.clear()
	RoomLabsGeneratorMaterials.prepare()
	__build_layout_graph()
	__plan_door_openings()
	__spawn_generated_geometry()
	print(
		"[RoomLabs] Generated labs room_seed=%d rooms=%d edges=%d"
		% [room_seed, __rooms_by_key.size(), __edges.size()]
	)

func __clear_previous_generation() -> void:
	var generated: Node = get_node_or_null(GENERATED_ROOT_PATH)
	if generated:
		generated.free()

func __build_layout_graph() -> void:
	var grid_diameter: int = grid_radius * 2 + 1
	var max_rooms_in_grid: int = grid_diameter * grid_diameter
	var target_rooms: int = clampi(room_count, 1, max_rooms_in_grid)
	var path: Array[Vector2i] = __build_linear_room_path(target_rooms)
	if path.is_empty():
		path = [Vector2i.ZERO]

	for i: int in range(path.size()):
		var coord: Vector2i = path[i]
		var adjacent_height_ref: float = -1.0
		if i > 0:
			var prev_key: String = __coord_key(path[i - 1])
			if __rooms_by_key.has(prev_key):
				var prev_room: RoomData = __rooms_by_key[prev_key]
				adjacent_height_ref = prev_room.height
		__add_room(
			coord,
			i == 0 or __rng.randf() < combat_room_ratio,
			adjacent_height_ref
		)
		if i > 0:
			__connect_rooms(path[i - 1], coord)

	__compact_connected_room_spans()

func __build_linear_room_path(target_rooms: int) -> Array[Vector2i]:
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
			var candidates: Array[Vector2i] = __available_neighbors_for_path(current, occupied)

			if candidates.is_empty():
				if path.size() <= 1:
					break
				var removed: Vector2i = path.pop_back()
				occupied.erase(__coord_key(removed))
				continue

			var next_coord: Vector2i = candidates[__rng.randi_range(0, candidates.size() - 1)]
			path.append(next_coord)
			occupied[__coord_key(next_coord)] = true

		if path.size() > best_path.size():
			best_path = path.duplicate()
		if path.size() >= target_rooms:
			return path

	return best_path

func __add_room(coord: Vector2i, force_combat: bool, adjacent_height_ref: float = -1.0) -> void:
	var is_combat: bool = force_combat
	var width: float
	var depth: float
	if is_combat:
		width = __rng.randf_range(combat_width_min, combat_width_max)
		depth = __rng.randf_range(combat_depth_min, combat_depth_max)
	else:
		width = __rng.randf_range(room_width_min, room_width_max)
		depth = __rng.randf_range(room_depth_min, room_depth_max)

	var max_room_span: float = __max_room_span()
	width = min(width, max_room_span)
	depth = min(depth, max_room_span)
	width = max(width, corridor_width + 2.0)
	depth = max(depth, corridor_width + 2.0)

	var room_data: RoomData = RoomData.new()
	room_data.coord = coord
	room_data.center = Vector3(float(coord.x) * grid_step, 0.0, float(coord.y) * grid_step)
	room_data.width = width
	room_data.depth = depth
	room_data.height = __sample_room_height(adjacent_height_ref)
	room_data.combat = is_combat
	var key: String = __coord_key(coord)
	__rooms_by_key[key] = room_data
	__neighbors_by_key[key] = []

func __sample_room_height(adjacent_height_ref: float = -1.0) -> float:
	var min_height: float = room_height
	if room_height_variation <= 0.0:
		return min_height

	var max_height: float = min_height + room_height_variation
	if adjacent_height_ref < 0.0:
		return __rng.randf_range(min_height, max_height)

	var required_delta: float = minf(adjacent_room_height_min_delta, room_height_variation)
	if required_delta <= 0.0:
		return __rng.randf_range(min_height, max_height)

	for _attempt: int in range(12):
		var candidate: float = __rng.randf_range(min_height, max_height)
		if absf(candidate - adjacent_height_ref) >= required_delta:
			return candidate

	var distance_to_min: float = absf(adjacent_height_ref - min_height)
	var distance_to_max: float = absf(adjacent_height_ref - max_height)
	if distance_to_max >= distance_to_min:
		var high_band_start: float = maxf(max_height - room_height_variation * 0.25, min_height)
		return __rng.randf_range(high_band_start, max_height)
	var low_band_end: float = minf(min_height + room_height_variation * 0.25, max_height)
	return __rng.randf_range(min_height, low_band_end)

func __plan_door_openings() -> void:
	__door_bottom_by_side.clear()
	for room_key: String in __rooms_by_key.keys():
		var room: RoomData = __rooms_by_key[room_key]
		var neighbors: Array = __neighbors_by_key.get(room_key, [])
		if neighbors.is_empty():
			continue

		var dirs: Array[Vector2i] = []
		for neighbor_coord: Vector2i in neighbors:
			dirs.append(neighbor_coord - room.coord)
		if dirs.is_empty():
			continue

		var max_bottom: float = __max_door_bottom_from_height(room.height)
		if dirs.size() == 1:
			__door_bottom_by_side[__side_key(room.coord, dirs[0])] = __sample_single_door_bottom(max_bottom)
			continue

		var pair: Array[float] = __sample_two_door_bottoms(max_bottom)
		for dir_index: int in range(dirs.size()):
			var use_index: int = mini(dir_index, pair.size() - 1)
			__door_bottom_by_side[__side_key(room.coord, dirs[dir_index])] = pair[use_index]

func __sample_single_door_bottom(max_bottom: float) -> float:
	if max_bottom <= 0.0:
		return 0.0
	if __rng.randf() >= elevated_door_chance:
		return 0.0
	return __sample_elevated_door_bottom(max_bottom)

func __sample_two_door_bottoms(max_bottom: float) -> Array[float]:
	var out: Array[float] = [0.0, 0.0]
	if max_bottom <= 0.0:
		return out

	var roll: float = __rng.randf()
	if roll < 0.24:
		return out

	if roll < 0.52:
		var shared: float = __sample_single_door_bottom(max_bottom)
		return [shared, shared]

	if roll < 0.74:
		var elevated: float = __sample_elevated_door_bottom(max_bottom)
		if __rng.randf() < 0.5:
			return [0.0, elevated]
		return [elevated, 0.0]

	var first: float = __sample_elevated_door_bottom(max_bottom)
	var second: float = __sample_elevated_door_bottom(max_bottom)
	for _attempt: int in range(12):
		if absf(first - second) >= door_split_min_delta:
			break
		second = __sample_elevated_door_bottom(max_bottom)

	if absf(first - second) < door_split_min_delta:
		var push_sign: float = 1.0 if __rng.randf() < 0.5 else -1.0
		second = __quantize_door_bottom(first + push_sign * door_split_min_delta, max_bottom)
		if second <= 0.0:
			second = __sample_elevated_door_bottom(max_bottom)

	return [first, second]

func __sample_elevated_door_bottom(max_bottom: float) -> float:
	var min_bottom: float = door_floor_snap_threshold + 0.2
	if max_bottom <= min_bottom:
		return 0.0
	for _attempt: int in range(8):
		var candidate: float = __rng.randf_range(min_bottom, max_bottom)
		candidate = __quantize_door_bottom(candidate, max_bottom)
		if candidate >= door_floor_snap_threshold:
			return candidate
	return __quantize_door_bottom(max_bottom, max_bottom)

func __quantize_door_bottom(value: float, max_bottom: float) -> float:
	var clamped: float = clampf(value, 0.0, max_bottom)
	var snapped_value: float = snappedf(clamped, 0.25)
	if snapped_value < door_floor_snap_threshold:
		return 0.0
	return clampf(snapped_value, 0.0, max_bottom)

func __max_door_bottom_from_height(room_height_local: float) -> float:
	var nominal_clear_height: float = minf(doorway_height, room_height_local - 0.4)
	return maxf(room_height_local - nominal_clear_height - 0.2, 0.0)

func __door_bottom_for_side(coord: Vector2i, dir: Vector2i, room_height_local: float) -> float:
	var key: String = __side_key(coord, dir)
	if !__door_bottom_by_side.has(key):
		return 0.0
	var raw_bottom: float = __door_bottom_by_side[key]
	return __quantize_door_bottom(raw_bottom, __max_door_bottom_from_height(room_height_local))

func __side_key(coord: Vector2i, dir: Vector2i) -> String:
	return "%s|%d,%d" % [__coord_key(coord), dir.x, dir.y]

func __connect_rooms(a: Vector2i, b: Vector2i) -> void:
	var key_a: String = __coord_key(a)
	var key_b: String = __coord_key(b)
	if !__neighbors_by_key.has(key_a) or !__neighbors_by_key.has(key_b):
		return
	var neighbors_a: Array = __neighbors_by_key[key_a]
	if b in neighbors_a:
		return
	neighbors_a.append(b)
	__neighbors_by_key[key_a] = neighbors_a
	var neighbors_b: Array = __neighbors_by_key[key_b]
	neighbors_b.append(a)
	__neighbors_by_key[key_b] = neighbors_b
	var edge: RoomEdge = RoomEdge.new()
	edge.a = a
	edge.b = b
	__edges.append(edge)

func __available_neighbors_for_path(base: Vector2i, occupied: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir: Vector2i in CARDINAL_DIRS:
		var coord: Vector2i = base + dir
		if abs(coord.x) > grid_radius or abs(coord.y) > grid_radius:
			continue
		if occupied.has(__coord_key(coord)):
			continue
		out.append(coord)
	return out

func __compact_connected_room_spans() -> void:
	if __edges.is_empty():
		return

	var target_corridor: float = maxf(corridor_target_length, 0.0)
	var max_room_span: float = __max_room_span()
	var max_iterations: int = 4

	for _iteration: int in range(max_iterations):
		var changed: bool = false
		for edge: RoomEdge in __edges:
			var a_room: RoomData = __rooms_by_key[__coord_key(edge.a)]
			var b_room: RoomData = __rooms_by_key[__coord_key(edge.b)]
			var direction: Vector2i = edge.b - edge.a
			if direction == Vector2i.RIGHT or direction == Vector2i.LEFT:
				var clear_x: float = maxf(absf(a_room.center.x - b_room.center.x) - a_room.width * 0.5 - b_room.width * 0.5, 0.0)
				if clear_x > target_corridor:
					var growth_needed: float = (clear_x - target_corridor) * 2.0
					changed = __expand_room_pair_axis(a_room, b_room, true, growth_needed, max_room_span) or changed
				continue
			if direction == Vector2i.UP or direction == Vector2i.DOWN:
				var clear_z: float = maxf(absf(a_room.center.z - b_room.center.z) - a_room.depth * 0.5 - b_room.depth * 0.5, 0.0)
				if clear_z > target_corridor:
					var growth_needed_z: float = (clear_z - target_corridor) * 2.0
					changed = __expand_room_pair_axis(a_room, b_room, false, growth_needed_z, max_room_span) or changed
		if !changed:
			return

func __expand_room_pair_axis(
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

func __max_room_span() -> float:
	var min_room_span: float = corridor_width + 2.0
	var bounded_span: float = grid_step - room_cell_margin
	return maxf(min_room_span, bounded_span)

func __spawn_generated_geometry() -> void:
	var root: Node3D = Node3D.new()
	root.name = GENERATED_ROOT_NAME
	add_child(root)

	var geom_root: Node3D = Node3D.new()
	geom_root.name = &"Geometry"
	root.add_child(geom_root)

	var light_root: Node3D = Node3D.new()
	light_root.name = &"Lights"
	root.add_child(light_root)

	var room_keys: Array = __rooms_by_key.keys()
	for room_key: String in room_keys:
		var room: RoomData = __rooms_by_key[room_key]
		__build_room(geom_root, light_root, room)

	for edge: RoomEdge in __edges:
		__build_corridor(geom_root, edge.a, edge.b)

	RoomLabsGeneratorLighting.add_base_environment_lighting(root, light_root)

func __build_room(geom_root: Node3D, light_root: Node3D, room: RoomData) -> void:
	var center: Vector3 = room.center
	var width: float = room.width
	var depth: float = room.depth
	var height: float = room.height
	var is_combat: bool = room.combat
	var coord: Vector2i = room.coord
	var neighbors: Array = __neighbors_by_key.get(__coord_key(coord), [])

	__add_solid_box(
		geom_root,
		"room_floor_%s" % __coord_key(coord),
		Vector3(width, floor_thickness, depth),
		center + Vector3(0.0, -floor_thickness * 0.5, 0.0),
		RoomLabsGeneratorMaterials.mat_floor
	)

	__add_solid_box(
		geom_root,
		"room_ceiling_%s" % __coord_key(coord),
		Vector3(width, floor_thickness, depth),
		center + Vector3(0.0, height + floor_thickness * 0.5, 0.0),
		RoomLabsGeneratorMaterials.mat_wall
	)

	var north_open: bool = __has_neighbor_in_dir(neighbors, coord, Vector2i.UP)
	var south_open: bool = __has_neighbor_in_dir(neighbors, coord, Vector2i.DOWN)
	var east_open: bool = __has_neighbor_in_dir(neighbors, coord, Vector2i.RIGHT)
	var west_open: bool = __has_neighbor_in_dir(neighbors, coord, Vector2i.LEFT)
	var north_bottom: float = (
		__door_bottom_for_side(coord, Vector2i.UP, height)
		if north_open
		else 0.0
	)
	var south_bottom: float = (
		__door_bottom_for_side(coord, Vector2i.DOWN, height)
		if south_open
		else 0.0
	)
	var east_bottom: float = (
		__door_bottom_for_side(coord, Vector2i.RIGHT, height)
		if east_open
		else 0.0
	)
	var west_bottom: float = (
		__door_bottom_for_side(coord, Vector2i.LEFT, height)
		if west_open
		else 0.0
	)

	__build_wall_with_optional_door(
		geom_root,
		center + Vector3(0.0, 0.0, -depth * 0.5),
		width,
		true,
		north_open,
		height,
		north_bottom
	)
	__build_wall_with_optional_door(
		geom_root,
		center + Vector3(0.0, 0.0, depth * 0.5),
		width,
		true,
		south_open,
		height,
		south_bottom
	)
	__build_wall_with_optional_door(
		geom_root,
		center + Vector3(-width * 0.5, 0.0, 0.0),
		depth,
		false,
		west_open,
		height,
		west_bottom
	)
	__build_wall_with_optional_door(
		geom_root,
		center + Vector3(width * 0.5, 0.0, 0.0),
		depth,
		false,
		east_open,
		height,
		east_bottom
	)
	__add_room_door_adaptors(geom_root, room, neighbors)

	__add_room_trim(geom_root, center, width, depth, height)
	RoomLabsGeneratorLighting.add_room_ceiling_strips(
		Callable(self, "__add_solid_box"),
		geom_root,
		center,
		width,
		depth,
		height,
		corridor_width,
		room_height
	)
	RoomLabsGeneratorLighting.add_room_lights(light_root, center, width, depth, height, is_combat)

	if is_combat:
		__add_cover_props(geom_root, room)

func __build_wall_with_optional_door(
	geom_root: Node3D,
	wall_center_at_floor: Vector3,
	length: float,
	along_x: bool,
	has_opening: bool,
	room_height_local: float,
	door_bottom: float = 0.0
) -> void:
	var door_width: float = __door_width_for_length(length)
	var side_length: float = (length - door_width) * 0.5
	var max_bottom: float = __max_door_bottom_from_height(room_height_local)
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
		__add_solid_box(
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
		__add_solid_box(
			geom_root,
			"wall_side_a",
			side_size,
			wall_center_at_floor + Vector3(0.0, room_height_local * 0.5, 0.0) - side_axis,
			RoomLabsGeneratorMaterials.mat_wall
		)
		__add_solid_box(
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
		__add_solid_box(
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
		__add_solid_box(
			geom_root,
			"wall_lintel",
			upper_size,
			wall_center_at_floor + Vector3(0.0, clamped_bottom + clear_height + upper_height * 0.5, 0.0),
			RoomLabsGeneratorMaterials.mat_trim
		)

func __build_corridor(geom_root: Node3D, a_coord: Vector2i, b_coord: Vector2i) -> void:
	var key_a: String = __coord_key(a_coord)
	var key_b: String = __coord_key(b_coord)
	if !__neighbors_by_key.has(key_a) or !__neighbors_by_key.has(key_b):
		return
	var a_room: RoomData = __rooms_by_key[__coord_key(a_coord)]
	var b_room: RoomData = __rooms_by_key[__coord_key(b_coord)]

	var a_center: Vector3 = a_room.center
	var b_center: Vector3 = b_room.center
	var direction: Vector2i = b_coord - a_coord

	if direction == Vector2i.RIGHT or direction == Vector2i.LEFT:
		var sign_x: float = sign(float(direction.x))
		var a_half: float = a_room.width * 0.5
		var b_half: float = b_room.width * 0.5
		var length: float = maxf(absf(b_center.x - a_center.x) - a_half - b_half, 0.0)
		if length <= 0.05:
			return
		var center_x: float = a_center.x + sign_x * (a_half + length * 0.5)
		var center_z: float = a_center.z
		var corridor_height: float = minf(a_room.height, b_room.height)
		var a_dir: Vector2i = Vector2i.RIGHT if direction == Vector2i.RIGHT else Vector2i.LEFT
		var b_dir: Vector2i = Vector2i.LEFT if direction == Vector2i.RIGHT else Vector2i.RIGHT
		var a_floor_y: float = __door_bottom_for_side(a_coord, a_dir, a_room.height)
		var b_floor_y: float = __door_bottom_for_side(b_coord, b_dir, b_room.height)
		var left_floor_y: float = a_floor_y if direction == Vector2i.RIGHT else b_floor_y
		var right_floor_y: float = b_floor_y if direction == Vector2i.RIGHT else a_floor_y
		__build_corridor_segment(
			geom_root,
			Vector3(center_x, 0.0, center_z),
			length,
			true,
			corridor_height,
			left_floor_y,
			right_floor_y
		)
		return

	if direction == Vector2i.UP or direction == Vector2i.DOWN:
		var sign_z: float = signf(float(direction.y))
		var a_half_z: float = a_room.depth * 0.5
		var b_half_z: float = b_room.depth * 0.5
		var length_z: float = maxf(absf(b_center.z - a_center.z) - a_half_z - b_half_z, 0.0)
		if length_z <= 0.05:
			return
		var center_z2: float = a_center.z + sign_z * (a_half_z + length_z * 0.5)
		var center_x2: float = a_center.x
		var corridor_height_z: float = minf(a_room.height, b_room.height)
		var a_dir_z: Vector2i = Vector2i.UP if direction == Vector2i.UP else Vector2i.DOWN
		var b_dir_z: Vector2i = Vector2i.DOWN if direction == Vector2i.UP else Vector2i.UP
		var a_floor_y_z: float = __door_bottom_for_side(a_coord, a_dir_z, a_room.height)
		var b_floor_y_z: float = __door_bottom_for_side(b_coord, b_dir_z, b_room.height)
		var north_floor_y: float = b_floor_y_z if direction == Vector2i.UP else a_floor_y_z
		var south_floor_y: float = a_floor_y_z if direction == Vector2i.UP else b_floor_y_z
		__build_corridor_segment(
			geom_root,
			Vector3(center_x2, 0.0, center_z2),
			length_z,
			false,
			corridor_height_z,
			north_floor_y,
			south_floor_y
		)

func __build_corridor_segment(
	geom_root: Node3D,
	center: Vector3,
	length: float,
	runs_x: bool,
	corridor_height: float,
	start_floor_y: float,
	end_floor_y: float
) -> void:
	var start_point: Vector3 = (
		center + Vector3(-length * 0.5, start_floor_y, 0.0)
		if runs_x
		else center + Vector3(0.0, start_floor_y, -length * 0.5)
	)
	var end_point: Vector3 = (
		center + Vector3(length * 0.5, end_floor_y, 0.0)
		if runs_x
		else center + Vector3(0.0, end_floor_y, length * 0.5)
	)
	__add_segmented_ramp(
		geom_root,
		"corridor_floor",
		start_point,
		end_point,
		corridor_width,
		true,
		RoomLabsGeneratorMaterials.mat_floor,
		false
	)

	var highest_floor: float = maxf(start_floor_y, end_floor_y)
	var envelope_height: float = corridor_height + highest_floor
	var ceiling_size: Vector3 = (
		Vector3(length, floor_thickness, corridor_width)
		if runs_x
		else Vector3(corridor_width, floor_thickness, length)
	)
	__add_solid_box(
		geom_root,
		"corridor_ceiling",
		ceiling_size,
		center + Vector3(0.0, envelope_height + floor_thickness * 0.5, 0.0),
		RoomLabsGeneratorMaterials.mat_wall
	)

	var wall_size: Vector3 = (
		Vector3(length, envelope_height, wall_thickness)
		if runs_x
		else Vector3(wall_thickness, envelope_height, length)
	)
	var wall_offset_axis: Vector3 = (
		Vector3(0.0, 0.0, corridor_width * 0.5 + wall_thickness * 0.5)
		if runs_x
		else Vector3(corridor_width * 0.5 + wall_thickness * 0.5, 0.0, 0.0)
	)
	__add_solid_box(
		geom_root,
		"corridor_wall_a",
		wall_size,
		center + Vector3(0.0, envelope_height * 0.5, 0.0) + wall_offset_axis,
		RoomLabsGeneratorMaterials.mat_wall
	)
	__add_solid_box(
		geom_root,
		"corridor_wall_b",
		wall_size,
		center + Vector3(0.0, envelope_height * 0.5, 0.0) - wall_offset_axis,
		RoomLabsGeneratorMaterials.mat_wall
	)

	RoomLabsGeneratorLighting.add_ceiling_strip(
		Callable(self, "__add_solid_box"),
		geom_root,
		center + Vector3(0.0, 0.0, 0.0),
		length * 0.8,
		corridor_width,
		room_height,
		runs_x,
		envelope_height
	)

func __door_width_for_length(wall_length: float) -> float:
	return maxf(1.25, minf(corridor_width + 1.0, wall_length - 2.0))

func __door_inward_axis(dir: Vector2i) -> Vector3:
	if dir == Vector2i.UP:
		return Vector3(0.0, 0.0, 1.0)
	if dir == Vector2i.DOWN:
		return Vector3(0.0, 0.0, -1.0)
	if dir == Vector2i.LEFT:
		return Vector3(1.0, 0.0, 0.0)
	if dir == Vector2i.RIGHT:
		return Vector3(-1.0, 0.0, 0.0)
	return Vector3.ZERO

func __door_along_axis(dir: Vector2i) -> Vector3:
	if dir == Vector2i.UP or dir == Vector2i.DOWN:
		return Vector3(1.0, 0.0, 0.0)
	return Vector3(0.0, 0.0, 1.0)

func __wall_length_for_dir(room: RoomData, dir: Vector2i) -> float:
	if dir == Vector2i.UP or dir == Vector2i.DOWN:
		return room.width
	return room.depth

func __wall_distance_for_dir(room: RoomData, dir: Vector2i) -> float:
	if dir == Vector2i.UP or dir == Vector2i.DOWN:
		return room.depth * 0.5
	return room.width * 0.5

func __door_inside_anchor(
	room: RoomData,
	dir: Vector2i,
	y: float,
	inward_offset: float = 0.6,
	along_offset: float = 0.0
) -> Vector3:
	var inward: Vector3 = __door_inward_axis(dir)
	var along: Vector3 = __door_along_axis(dir)
	var wall_center: Vector3 = room.center - inward * __wall_distance_for_dir(room, dir)
	return wall_center + inward * (wall_thickness * 0.5 + inward_offset) + along * along_offset + Vector3(0.0, y, 0.0)

func __add_room_door_adaptors(geom_root: Node3D, room: RoomData, neighbors: Array) -> void:
	var openings: Array = []
	for dir: Vector2i in CARDINAL_DIRS:
		if !__has_neighbor_in_dir(neighbors, room.coord, dir):
			continue
		var door_bottom: float = __door_bottom_for_side(room.coord, dir, room.height)
		if door_bottom <= 0.05:
			continue
		var wall_length: float = __wall_length_for_dir(room, dir)
		openings.append(
			{
				"dir": dir,
				"door_bottom": door_bottom,
				"wall_length": wall_length,
				"door_width": __door_width_for_length(wall_length)
			}
		)

	if openings.is_empty():
		return

	var bridged_dirs: Array = __try_add_room_door_bridge(geom_root, room, openings)
	var bridged_lookup: Dictionary = {}
	for bridged_dir: Vector2i in bridged_dirs:
		bridged_lookup[__coord_key(bridged_dir)] = true

	for opening: Dictionary in openings:
		var opening_dir: Vector2i = opening["dir"]
		var dir_key: String = __coord_key(opening_dir)
		if bridged_lookup.has(dir_key):
			continue
		__build_single_door_adaptor(geom_root, room, opening)

func __try_add_room_door_bridge(geom_root: Node3D, room: RoomData, openings: Array) -> Array:
	var elevated: Array = []
	for opening: Dictionary in openings:
		var opening_bottom: float = opening["door_bottom"]
		if opening_bottom >= door_bridge_min_height:
			elevated.append(opening)
	if elevated.size() < 2:
		return []

	var pair_indices: Array = []
	for i: int in range(elevated.size()):
		for j: int in range(i + 1, elevated.size()):
			var dir_a: Vector2i = elevated[i]["dir"]
			var dir_b: Vector2i = elevated[j]["dir"]
			if dir_a + dir_b == Vector2i.ZERO:
				pair_indices.append([i, j])

	if pair_indices.is_empty():
		return []

	var chosen_pair: Array = pair_indices[__rng.randi_range(0, pair_indices.size() - 1)]
	var opening_a: Dictionary = elevated[chosen_pair[0]]
	var opening_b: Dictionary = elevated[chosen_pair[1]]
	var dir_a_chosen: Vector2i = opening_a["dir"]
	var dir_b_chosen: Vector2i = opening_b["dir"]
	var bottom_a: float = opening_a["door_bottom"]
	var bottom_b: float = opening_b["door_bottom"]
	var bridge_y: float = minf(bottom_a, bottom_b)
	if bridge_y < door_bridge_min_height:
		return []

	var runs_x: bool = abs(dir_a_chosen.x) > 0
	var bridge_length: float = (
		room.width - wall_thickness * 2.0 - 1.2
		if runs_x
		else room.depth - wall_thickness * 2.0 - 1.2
	)
	if bridge_length <= corridor_width * 0.8:
		return []
	var bridge_width: float = clampf(corridor_width * 0.72, 1.8, 4.2)
	var bridge_size: Vector3 = (
		Vector3(bridge_length, floor_thickness, bridge_width)
		if runs_x
		else Vector3(bridge_width, floor_thickness, bridge_length)
	)
	__add_solid_box(
		geom_root,
		"door_bridge",
		bridge_size,
		room.center + Vector3(0.0, bridge_y - floor_thickness * 0.5, 0.0),
		RoomLabsGeneratorMaterials.mat_trim
	)

	for opening_link: Dictionary in [opening_a, opening_b]:
		var dir_link: Vector2i = opening_link["dir"]
		var door_bottom_link: float = opening_link["door_bottom"]
		var door_point: Vector3 = __door_inside_anchor(room, dir_link, door_bottom_link, 0.7, 0.0)
		var bridge_point: Vector3 = Vector3(door_point.x, bridge_y, door_point.z)
		if bridge_point.distance_to(door_point) >= 0.2:
			__add_segmented_ramp(
				geom_root,
				"door_bridge_link",
				bridge_point,
				door_point,
				minf(bridge_width * 0.8, 2.4),
				false,
				RoomLabsGeneratorMaterials.mat_trim
			)

	var ramp_count: int = 1 + (1 if __rng.randf() < 0.55 else 0)
	for _ramp_index: int in range(ramp_count):
		if runs_x:
			var sign_z: float = -1.0 if __rng.randf() < 0.5 else 1.0
			var top_x: float = __rng.randf_range(-bridge_length * 0.25, bridge_length * 0.25)
			var top_point_x: Vector3 = room.center + Vector3(top_x, bridge_y, sign_z * bridge_width * 0.35)
			var run_z: float = clampf(bridge_y * 2.0 + __rng.randf_range(0.4, 1.8), 2.0, room.depth * 0.36)
			var base_point_x: Vector3 = top_point_x + Vector3(0.0, 0.0, sign_z * run_z)
			base_point_x.y = 0.0
			base_point_x = __clamp_point_inside_room(room, base_point_x, 0.5)
			__add_segmented_ramp(
				geom_root,
				"door_bridge_ramp",
				base_point_x,
				top_point_x,
				minf(corridor_width * 0.48, 2.2),
				false,
				RoomLabsGeneratorMaterials.mat_floor,
				false
			)
			continue

		var sign_x: float = -1.0 if __rng.randf() < 0.5 else 1.0
		var top_z: float = __rng.randf_range(-bridge_length * 0.25, bridge_length * 0.25)
		var top_point_z: Vector3 = room.center + Vector3(sign_x * bridge_width * 0.35, bridge_y, top_z)
		var run_x: float = clampf(bridge_y * 2.0 + __rng.randf_range(0.4, 1.8), 2.0, room.width * 0.36)
		var base_point_z: Vector3 = top_point_z + Vector3(sign_x * run_x, 0.0, 0.0)
		base_point_z.y = 0.0
		base_point_z = __clamp_point_inside_room(room, base_point_z, 0.5)
		__add_segmented_ramp(
			geom_root,
			"door_bridge_ramp",
			base_point_z,
			top_point_z,
			minf(corridor_width * 0.48, 2.2),
			false,
			RoomLabsGeneratorMaterials.mat_floor,
			false
		)

	return [dir_a_chosen, dir_b_chosen]

func __build_single_door_adaptor(geom_root: Node3D, room: RoomData, opening: Dictionary) -> void:
	var door_bottom: float = opening["door_bottom"]
	if door_bottom <= 0.05:
		return

	var block_variant: bool = __rng.randf() < 0.45
	if door_bottom <= door_floor_snap_threshold + 0.2:
		__build_door_step_adaptor(geom_root, room, opening, block_variant)
		return

	var roll: float = __rng.randf()
	if roll < 0.38:
		__build_wall_strip_adaptor(geom_root, room, opening, true, block_variant)
		return
	if roll < 0.7:
		__build_wall_strip_adaptor(geom_root, room, opening, false, block_variant)
		return
	__build_door_step_adaptor(geom_root, room, opening, block_variant)

func __build_wall_strip_adaptor(
	geom_root: Node3D,
	room: RoomData,
	opening: Dictionary,
	wall_to_wall: bool,
	block_variant: bool
) -> void:
	var dir: Vector2i = opening["dir"]
	var door_bottom: float = opening["door_bottom"]
	var wall_length: float = opening["wall_length"]
	var door_width: float = opening["door_width"]
	var inward: Vector3 = __door_inward_axis(dir)
	var along: Vector3 = __door_along_axis(dir)
	var along_is_x: bool = absf(along.x) > 0.5

	var platform_depth: float = clampf(corridor_width * 0.58, 1.35, 3.2)
	var span_along: float = wall_length - 0.9
	var along_offset: float = 0.0

	if !wall_to_wall:
		var margin: float = 0.45
		var side_sign: float = -1.0 if __rng.randf() < 0.5 else 1.0
		var span_start: float = -wall_length * 0.5 + margin
		var span_end: float = wall_length * 0.5 - margin
		if side_sign < 0.0:
			span_end = door_width * 0.5 + 0.2
		else:
			span_start = -door_width * 0.5 - 0.2
		span_along = maxf(span_end - span_start, door_width + 0.75)
		span_along = minf(span_along, wall_length - 0.9)
		along_offset = (span_start + span_end) * 0.5
		along_offset = clampf(
			along_offset,
			-wall_length * 0.5 + span_along * 0.5 + 0.45,
			wall_length * 0.5 - span_along * 0.5 - 0.45
		)

	var platform_center: Vector3 = __door_inside_anchor(room, dir, 0.0, platform_depth * 0.5 + 0.15, along_offset)
	__add_elevated_platform(
		geom_root,
		"door_platform_strip",
		platform_center,
		along_is_x,
		span_along,
		platform_depth,
		door_bottom,
		block_variant
	)

	var ramp_count: int = 1
	if wall_to_wall and door_bottom > 1.7 and __rng.randf() < 0.6:
		ramp_count = 2

	var ramp_signs: Array[float] = [-1.0 if __rng.randf() < 0.5 else 1.0]
	if ramp_count == 2:
		ramp_signs = [-1.0, 1.0]

	for ramp_sign: float in ramp_signs:
		var top_offset: float = ramp_sign * maxf(span_along * 0.5 - 0.55, 0.15)
		var top_point: Vector3 = (
			platform_center
			+ along * top_offset
			+ inward * (platform_depth * 0.35)
			+ Vector3(0.0, door_bottom, 0.0)
		)
		var run_length: float = clampf(
			door_bottom * __rng.randf_range(1.8, 2.6),
			1.6,
			wall_length * 0.42
		)
		__add_adaptor_ramp(
			geom_root,
			room,
			top_point,
			-along * ramp_sign,
			run_length,
			minf(platform_depth * 0.9, 2.2),
			block_variant
		)

	if !wall_to_wall and door_bottom <= 1.6 and __rng.randf() < 0.5:
		var frontal_top: Vector3 = (
			platform_center
			+ inward * (platform_depth * 0.5 - 0.15)
			+ Vector3(0.0, door_bottom, 0.0)
		)
		__add_adaptor_ramp(
			geom_root,
			room,
			frontal_top,
			inward,
			clampf(door_bottom * 2.2 + 0.4, 1.4, 3.8),
			minf(span_along * 0.5, 2.6),
			block_variant
		)

func __build_door_step_adaptor(
	geom_root: Node3D,
	room: RoomData,
	opening: Dictionary,
	block_variant: bool
) -> void:
	var dir: Vector2i = opening["dir"]
	var door_bottom: float = opening["door_bottom"]
	var wall_length: float = opening["wall_length"]
	var door_width: float = opening["door_width"]
	var inward: Vector3 = __door_inward_axis(dir)
	var along: Vector3 = __door_along_axis(dir)
	var along_is_x: bool = absf(along.x) > 0.5

	var step_span: float = clampf(
		door_width + __rng.randf_range(0.3, 2.0),
		door_width + 0.2,
		wall_length - 0.9
	)
	var step_depth: float = clampf(__rng.randf_range(0.9, 2.4), 0.9, 3.0)
	var step_center: Vector3 = __door_inside_anchor(room, dir, 0.0, step_depth * 0.5 + 0.12, 0.0)
	__add_elevated_platform(
		geom_root,
		"door_platform_step",
		step_center,
		along_is_x,
		step_span,
		step_depth,
		door_bottom,
		block_variant
	)

	if door_bottom <= 1.35 and __rng.randf() < 0.65:
		var frontal_top: Vector3 = (
			step_center
			+ inward * (step_depth * 0.5 - 0.1)
			+ Vector3(0.0, door_bottom, 0.0)
		)
		__add_adaptor_ramp(
			geom_root,
			room,
			frontal_top,
			inward,
			clampf(door_bottom * 2.4 + 0.5, 1.2, 4.2),
			minf(step_span * 0.6, corridor_width * 0.7),
			block_variant
		)
		return

	var ramp_count: int = 1 + (1 if door_bottom > 2.2 and __rng.randf() < 0.6 else 0)
	var ramp_signs: Array[float] = [-1.0 if __rng.randf() < 0.5 else 1.0]
	if ramp_count == 2:
		ramp_signs = [-1.0, 1.0]
	for ramp_sign: float in ramp_signs:
		var lateral_top: Vector3 = (
			step_center
			+ along * (ramp_sign * maxf(step_span * 0.5 - 0.28, 0.1))
			+ inward * (step_depth * 0.22)
			+ Vector3(0.0, door_bottom, 0.0)
		)
		__add_adaptor_ramp(
			geom_root,
			room,
			lateral_top,
			-along * ramp_sign,
			clampf(door_bottom * 2.1 + __rng.randf_range(0.2, 1.2), 1.5, wall_length * 0.38),
			minf(step_depth * 0.9, 2.0),
			block_variant
		)

func __add_elevated_platform(
	geom_root: Node3D,
	base_name: String,
	center: Vector3,
	along_is_x: bool,
	span_along: float,
	span_inward: float,
	top_y: float,
	block_variant: bool
) -> void:
	var slab_size: Vector3 = (
		Vector3(span_along, floor_thickness, span_inward)
		if along_is_x
		else Vector3(span_inward, floor_thickness, span_along)
	)
	__add_solid_box(
		geom_root,
		base_name,
		slab_size,
		Vector3(center.x, top_y - floor_thickness * 0.5, center.z),
		RoomLabsGeneratorMaterials.mat_trim
	)
	if !block_variant or top_y <= 0.08:
		return

	var support_size: Vector3 = slab_size
	support_size.y = maxf(top_y - floor_thickness, 0.05)
	__add_solid_box(
		geom_root,
		"%s_support" % base_name,
		support_size,
		Vector3(center.x, support_size.y * 0.5, center.z),
		RoomLabsGeneratorMaterials.mat_cover
	)

func __add_adaptor_ramp(
	geom_root: Node3D,
	room: RoomData,
	top_point: Vector3,
	top_to_base_direction: Vector3,
	desired_run: float,
	width: float,
	block_variant: bool
) -> void:
	var horizontal_dir: Vector3 = Vector3(top_to_base_direction.x, 0.0, top_to_base_direction.z)
	if horizontal_dir.length() <= 0.01:
		return
	horizontal_dir = horizontal_dir.normalized()
	var base_point: Vector3 = top_point + horizontal_dir * desired_run
	base_point.y = 0.0
	base_point = __clamp_point_inside_room(room, base_point, 0.55)

	var horizontal_span: float = Vector2(base_point.x - top_point.x, base_point.z - top_point.z).length()
	if horizontal_span < 0.8:
		return

	__add_segmented_ramp(
		geom_root,
		"door_ramp",
		base_point,
		top_point,
		width,
		block_variant,
		RoomLabsGeneratorMaterials.mat_floor,
		false
	)

func __clamp_point_inside_room(room: RoomData, point: Vector3, margin: float = 0.4) -> Vector3:
	return Vector3(
		clampf(point.x, room.center.x - room.width * 0.5 + margin, room.center.x + room.width * 0.5 - margin),
		point.y,
		clampf(point.z, room.center.z - room.depth * 0.5 + margin, room.center.z + room.depth * 0.5 - margin)
	)

func __add_segmented_ramp(
	geom_root: Node3D,
	base_name: String,
	start: Vector3,
	finish: Vector3,
	width: float,
	block_variant: bool,
	material: Material,
	add_cap: bool = true
) -> void:
	var horizontal_start: Vector3 = Vector3(start.x, 0.0, start.z)
	var horizontal_finish: Vector3 = Vector3(finish.x, 0.0, finish.z)
	var run: float = horizontal_start.distance_to(horizontal_finish)
	var rise: float = finish.y - start.y
	if run < 0.2:
		var top_y: float = maxf(start.y, finish.y)
		var fallback_size_y: float = floor_thickness
		var fallback_center_y: float = top_y - floor_thickness * 0.5
		if block_variant:
			fallback_size_y = maxf(top_y + floor_thickness, floor_thickness)
			fallback_center_y = top_y - fallback_size_y * 0.5
		__add_solid_box(
			geom_root,
			base_name,
			Vector3(width, fallback_size_y, width),
			Vector3((start.x + finish.x) * 0.5, fallback_center_y, (start.z + finish.z) * 0.5),
			material
		)
		return

	var flat_delta: Vector3 = horizontal_finish - horizontal_start
	var flat_dir: Vector3 = flat_delta / run
	var slope_angle: float = atan2(rise, run)
	var yaw: float = atan2(flat_dir.z, flat_dir.x)
	var ramp_length: float = sqrt(run * run + rise * rise)
	var ramp_thickness: float = floor_thickness
	var ramp_midpoint: Vector3 = start.lerp(finish, 0.5)
	var ramp_center: Vector3 = Vector3(
		ramp_midpoint.x,
		ramp_midpoint.y - cos(slope_angle) * ramp_thickness * 0.5,
		ramp_midpoint.z
	)
	# In Godot, FORWARD is -Z; use BACK (+Z) so positive slope rises toward +local X.
	var ramp_basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, slope_angle)
	__add_oriented_box(
		geom_root,
		base_name,
		Vector3(ramp_length, ramp_thickness, width),
		ramp_center,
		ramp_basis,
		material
	)

	var cap_basis: Basis = Basis(Vector3.UP, yaw)
	if add_cap:
		var high_is_finish: bool = finish.y >= start.y
		var high_point: Vector3 = finish if high_is_finish else start
		var away_from_low_dir: Vector3 = flat_dir if high_is_finish else -flat_dir
		var cap_length: float = clampf(width * 0.52, 0.7, 1.8)
		var cap_gap: float = 0.01
		var cap_center: Vector3 = (
			high_point
			+ away_from_low_dir * (cap_length * 0.5 + cap_gap)
			- Vector3(0.0, floor_thickness * 0.5, 0.0)
		)
		__add_oriented_box(
			geom_root,
			"%s_cap" % base_name,
			Vector3(cap_length, floor_thickness, width),
			cap_center,
			cap_basis,
			material
		)

	if !block_variant:
		return

	var support_height: float = maxf(maxf(start.y, finish.y), floor_thickness)
	var support_center: Vector3 = Vector3(ramp_midpoint.x, support_height * 0.5 - floor_thickness * 0.25, ramp_midpoint.z)
	__add_oriented_box(
		geom_root,
		"%s_support" % base_name,
		Vector3(run + 0.05, support_height, width * 0.92),
		support_center,
		cap_basis,
		RoomLabsGeneratorMaterials.mat_cover
	)

func __add_oriented_box(
	parent: Node3D,
	base_name: String,
	size: Vector3,
	pos: Vector3,
	box_basis: Basis,
	material: Material,
	with_collision: bool = true
) -> void:
	var clamped_size: Vector3 = Vector3(
		maxf(size.x, 0.05),
		maxf(size.y, 0.05),
		maxf(size.z, 0.05)
	)

	var node: Node3D = Node3D.new()
	node.name = base_name
	node.position = pos
	node.basis = box_basis
	parent.add_child(node)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = clamped_size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	node.add_child(mesh_instance)

	if !with_collision:
		return

	var body: StaticBody3D = StaticBody3D.new()
	node.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = clamped_size
	collision.shape = shape
	body.add_child(collision)

func __add_room_trim(
	geom_root: Node3D,
	center: Vector3,
	width: float,
	depth: float,
	room_height_local: float
) -> void:
	var trim_height: float = min(room_height_local * 0.58, room_height_local - 0.7)
	var trim_thickness: float = 0.25
	var trim_offset: float = wall_thickness * 0.5 + trim_thickness * 0.5

	__add_solid_box(
		geom_root,
		"trim_n",
		Vector3(width * 0.85, trim_thickness, 0.35),
		center + Vector3(0.0, trim_height, -depth * 0.5 + trim_offset),
		RoomLabsGeneratorMaterials.mat_trim
	)
	__add_solid_box(
		geom_root,
		"trim_s",
		Vector3(width * 0.85, trim_thickness, 0.35),
		center + Vector3(0.0, trim_height, depth * 0.5 - trim_offset),
		RoomLabsGeneratorMaterials.mat_trim
	)
	__add_solid_box(
		geom_root,
		"trim_w",
		Vector3(0.35, trim_thickness, depth * 0.85),
		center + Vector3(-width * 0.5 + trim_offset, trim_height, 0.0),
		RoomLabsGeneratorMaterials.mat_trim
	)
	__add_solid_box(
		geom_root,
		"trim_e",
		Vector3(0.35, trim_thickness, depth * 0.85),
		center + Vector3(width * 0.5 - trim_offset, trim_height, 0.0),
		RoomLabsGeneratorMaterials.mat_trim
	)

func __add_cover_props(geom_root: Node3D, room: RoomData) -> void:
	var center: Vector3 = room.center
	var width: float = room.width
	var depth: float = room.depth
	var coord: Vector2i = room.coord
	if coord == Vector2i.ZERO:
		return

	var props: int = __rng.randi_range(2, 5)
	for _i: int in range(props):
		var size_x: float = __rng.randf_range(1.6, 3.2)
		var size_z: float = __rng.randf_range(1.6, 3.4)
		var offset_x: float = __rng.randf_range(-width * 0.33, width * 0.33)
		var offset_z: float = __rng.randf_range(-depth * 0.33, depth * 0.33)
		if Vector2(offset_x, offset_z).length() < 3.4:
			continue
		var prop_size: Vector3 = Vector3(size_x, __rng.randf_range(1.0, 1.6), size_z)
		__add_solid_box(
			geom_root,
			"cover",
			prop_size,
			center + Vector3(offset_x, prop_size.y * 0.5, offset_z),
			RoomLabsGeneratorMaterials.mat_cover
		)

func __add_solid_box(
	parent: Node3D,
	base_name: String,
	size: Vector3,
	pos: Vector3,
	material: Material,
	with_collision: bool = true
) -> void:
	var clamped_size: Vector3 = Vector3(
		maxf(size.x, 0.05),
		maxf(size.y, 0.05),
		maxf(size.z, 0.05)
	)

	var node: Node3D = Node3D.new()
	node.name = base_name
	node.position = pos
	parent.add_child(node)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = clamped_size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	node.add_child(mesh_instance)

	if !with_collision:
		return

	var body: StaticBody3D = StaticBody3D.new()
	node.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = clamped_size
	collision.shape = shape
	body.add_child(collision)

func __has_neighbor_in_dir(neighbors: Array, coord: Vector2i, dir: Vector2i) -> bool:
	return (coord + dir) in neighbors

func __coord_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func __coord_from_key(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))
