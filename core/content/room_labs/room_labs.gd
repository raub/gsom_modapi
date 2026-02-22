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
@export_range(4.0, 12.0, 0.25) var corridor_width: float = 6.0
@export_range(0.0, 6.0, 0.25) var corridor_target_length: float = 1.0
@export_range(0.0, 2.0, 0.05) var room_cell_margin: float = 0.5
@export_range(2.2, 4.5, 0.1) var doorway_height: float = 3.2
@export_range(0.2, 1.0, 0.05) var wall_thickness: float = 0.5
@export_range(0.2, 1.2, 0.05) var floor_thickness: float = 0.45

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
	var combat: bool = false

var __rng: RandomNumberGenerator = RandomNumberGenerator.new()
var __rooms_by_key: Dictionary[String, RoomData] = {}
var __neighbors_by_key: Dictionary = {}
var __edges: Array[RoomEdge] = []

var __mat_floor: StandardMaterial3D
var __mat_wall: StandardMaterial3D
var __mat_trim: StandardMaterial3D
var __mat_cover: StandardMaterial3D
var __mat_light: StandardMaterial3D

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
	__prepare_materials()
	__build_layout_graph()
	__spawn_generated_geometry()
	print(
		"[RoomLabs] Generated labs room_seed=%d rooms=%d edges=%d"
		% [room_seed, __rooms_by_key.size(), __edges.size()]
	)

func __clear_previous_generation() -> void:
	var generated: Node = get_node_or_null(GENERATED_ROOT_PATH)
	if generated:
		generated.free()

func __prepare_materials() -> void:
	__mat_floor = StandardMaterial3D.new()
	__mat_floor.albedo_color = Color(0.14, 0.16, 0.18)
	__mat_floor.roughness = 0.92
	__mat_floor.metallic = 0.15

	__mat_wall = StandardMaterial3D.new()
	__mat_wall.albedo_color = Color(0.57, 0.61, 0.66)
	__mat_wall.roughness = 0.74
	__mat_wall.metallic = 0.1

	__mat_trim = StandardMaterial3D.new()
	__mat_trim.albedo_color = Color(0.18, 0.29, 0.38)
	__mat_trim.roughness = 0.52
	__mat_trim.metallic = 0.38

	__mat_cover = StandardMaterial3D.new()
	__mat_cover.albedo_color = Color(0.22, 0.25, 0.3)
	__mat_cover.roughness = 0.78
	__mat_cover.metallic = 0.2

	__mat_light = StandardMaterial3D.new()
	__mat_light.albedo_color = Color(0.66, 0.78, 0.92)
	__mat_light.emission_enabled = true
	__mat_light.emission = Color(0.4, 0.6, 0.95)
	__mat_light.emission_energy_multiplier = 1.35
	__mat_light.metallic = 0.0
	__mat_light.roughness = 0.1

func __build_layout_graph() -> void:
	var grid_diameter: int = grid_radius * 2 + 1
	var max_rooms_in_grid: int = grid_diameter * grid_diameter
	var target_rooms: int = clampi(room_count, 1, max_rooms_in_grid)
	var path: Array[Vector2i] = __build_linear_room_path(target_rooms)
	if path.is_empty():
		path = [Vector2i.ZERO]

	for i: int in range(path.size()):
		var coord: Vector2i = path[i]
		__add_room(coord, i == 0 or __rng.randf() < combat_room_ratio)
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

func __add_room(coord: Vector2i, force_combat: bool) -> void:
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
	room_data.combat = is_combat
	var key: String = __coord_key(coord)
	__rooms_by_key[key] = room_data
	__neighbors_by_key[key] = []

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

	__add_origin_key_light(light_root)

func __build_room(geom_root: Node3D, light_root: Node3D, room: RoomData) -> void:
	var center: Vector3 = room.center
	var width: float = room.width
	var depth: float = room.depth
	var is_combat: bool = room.combat
	var coord: Vector2i = room.coord
	var neighbors: Array = __neighbors_by_key.get(__coord_key(coord), [])

	__add_solid_box(
		geom_root,
		"room_floor_%s" % __coord_key(coord),
		Vector3(width, floor_thickness, depth),
		center + Vector3(0.0, -floor_thickness * 0.5, 0.0),
		__mat_floor
	)

	__add_solid_box(
		geom_root,
		"room_ceiling_%s" % __coord_key(coord),
		Vector3(width, floor_thickness, depth),
		center + Vector3(0.0, room_height + floor_thickness * 0.5, 0.0),
		__mat_wall
	)

	var north_open: bool = __has_neighbor_in_dir(neighbors, coord, Vector2i.UP)
	var south_open: bool = __has_neighbor_in_dir(neighbors, coord, Vector2i.DOWN)
	var east_open: bool = __has_neighbor_in_dir(neighbors, coord, Vector2i.RIGHT)
	var west_open: bool = __has_neighbor_in_dir(neighbors, coord, Vector2i.LEFT)

	__build_wall_with_optional_door(
		geom_root,
		center + Vector3(0.0, 0.0, -depth * 0.5),
		width,
		true,
		north_open
	)
	__build_wall_with_optional_door(
		geom_root,
		center + Vector3(0.0, 0.0, depth * 0.5),
		width,
		true,
		south_open
	)
	__build_wall_with_optional_door(
		geom_root,
		center + Vector3(-width * 0.5, 0.0, 0.0),
		depth,
		false,
		west_open
	)
	__build_wall_with_optional_door(
		geom_root,
		center + Vector3(width * 0.5, 0.0, 0.0),
		depth,
		false,
		east_open
	)

	__add_room_trim(geom_root, center, width, depth)
	__add_ceiling_strip(geom_root, center, minf(width, depth) * 0.6)
	__add_room_light(light_root, center, is_combat)

	if is_combat:
		__add_cover_props(geom_root, room)

func __build_wall_with_optional_door(
	geom_root: Node3D,
	wall_center_at_floor: Vector3,
	length: float,
	along_x: bool,
	has_opening: bool
) -> void:
	var door_width: float = min(corridor_width + 1.0, length - 2.0)
	var side_length: float = (length - door_width) * 0.5
	var clear_height: float = min(doorway_height, room_height - 0.4)
	var upper_height: float = room_height - clear_height

	if !has_opening or side_length <= 0.25:
		var full_size: Vector3 = (
			Vector3(length, room_height, wall_thickness)
			if along_x
			else Vector3(wall_thickness, room_height, length)
		)
		__add_solid_box(
			geom_root,
			"wall_full",
			full_size,
			wall_center_at_floor + Vector3(0.0, room_height * 0.5, 0.0),
			__mat_wall
		)
		return

	if side_length > 0.3:
		var side_size: Vector3 = (
			Vector3(side_length, room_height, wall_thickness)
			if along_x
			else Vector3(wall_thickness, room_height, side_length)
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
			wall_center_at_floor + Vector3(0.0, room_height * 0.5, 0.0) - side_axis,
			__mat_wall
		)
		__add_solid_box(
			geom_root,
			"wall_side_b",
			side_size,
			wall_center_at_floor + Vector3(0.0, room_height * 0.5, 0.0) + side_axis,
			__mat_wall
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
			wall_center_at_floor + Vector3(0.0, clear_height + upper_height * 0.5, 0.0),
			__mat_trim
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
		__build_corridor_segment(geom_root, Vector3(center_x, 0.0, center_z), length, true)
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
		__build_corridor_segment(geom_root, Vector3(center_x2, 0.0, center_z2), length_z, false)

func __build_corridor_segment(
	geom_root: Node3D,
	center: Vector3,
	length: float,
	runs_x: bool
) -> void:
	var floor_size: Vector3 = (
		Vector3(length, floor_thickness, corridor_width)
		if runs_x
		else Vector3(corridor_width, floor_thickness, length)
	)
	__add_solid_box(
		geom_root,
		"corridor_floor",
		floor_size,
		center + Vector3(0.0, -floor_thickness * 0.5, 0.0),
		__mat_floor
	)
	__add_solid_box(
		geom_root,
		"corridor_ceiling",
		floor_size,
		center + Vector3(0.0, room_height + floor_thickness * 0.5, 0.0),
		__mat_wall
	)

	var wall_size: Vector3 = (
		Vector3(length, room_height, wall_thickness)
		if runs_x
		else Vector3(wall_thickness, room_height, length)
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
		center + Vector3(0.0, room_height * 0.5, 0.0) + wall_offset_axis,
		__mat_wall
	)
	__add_solid_box(
		geom_root,
		"corridor_wall_b",
		wall_size,
		center + Vector3(0.0, room_height * 0.5, 0.0) - wall_offset_axis,
		__mat_wall
	)

	__add_ceiling_strip(geom_root, center + Vector3(0.0, 0.0, 0.0), length * 0.8, runs_x)

func __add_room_trim(geom_root: Node3D, center: Vector3, width: float, depth: float) -> void:
	var trim_height: float = min(room_height * 0.58, room_height - 0.7)
	var trim_thickness: float = 0.25
	var trim_offset: float = wall_thickness * 0.5 + trim_thickness * 0.5

	__add_solid_box(
		geom_root,
		"trim_n",
		Vector3(width * 0.85, trim_thickness, 0.35),
		center + Vector3(0.0, trim_height, -depth * 0.5 + trim_offset),
		__mat_trim
	)
	__add_solid_box(
		geom_root,
		"trim_s",
		Vector3(width * 0.85, trim_thickness, 0.35),
		center + Vector3(0.0, trim_height, depth * 0.5 - trim_offset),
		__mat_trim
	)
	__add_solid_box(
		geom_root,
		"trim_w",
		Vector3(0.35, trim_thickness, depth * 0.85),
		center + Vector3(-width * 0.5 + trim_offset, trim_height, 0.0),
		__mat_trim
	)
	__add_solid_box(
		geom_root,
		"trim_e",
		Vector3(0.35, trim_thickness, depth * 0.85),
		center + Vector3(width * 0.5 - trim_offset, trim_height, 0.0),
		__mat_trim
	)

func __add_ceiling_strip(
	geom_root: Node3D,
	center: Vector3,
	length: float,
	runs_x: bool = true
) -> void:
	var strip_width: float = min(corridor_width * 0.35, 1.8)
	var strip_size: Vector3 = (
		Vector3(length, 0.12, strip_width)
		if runs_x
		else Vector3(strip_width, 0.12, length)
	)
	__add_solid_box(
		geom_root,
		"ceiling_strip",
		strip_size,
		center + Vector3(0.0, room_height - 0.05, 0.0),
		__mat_light,
		false
	)

func __add_room_light(light_root: Node3D, center: Vector3, is_combat: bool) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = center + Vector3(0.0, room_height - 0.2, 0.0)
	light.light_color = Color(0.78, 0.87, 1.0) if is_combat else Color(0.7, 0.8, 0.95)
	light.light_energy = 1.2 if is_combat else 0.9
	light.omni_range = 18.0 if is_combat else 14.0
	light.shadow_enabled = false
	light_root.add_child(light)

func __add_origin_key_light(light_root: Node3D) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = Vector3(0.0, room_height - 0.15, 0.0)
	light.light_color = Color(0.92, 0.95, 1.0)
	light.light_energy = 1.5
	light.omni_range = 22.0
	light_root.add_child(light)

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
			__mat_cover
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
