extends RefCounted
class_name RoomLabsGeneratorRooms

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
	for room_key: String in rooms_by_key.keys():
		var room: RoomData = rooms_by_key[room_key]
		var neighbors: Array = neighbors_by_key.get(room_key, [])
		if neighbors.is_empty():
			continue

		var dirs: Array[Vector2i] = []
		for neighbor_coord: Vector2i in neighbors:
			dirs.append(neighbor_coord - room.coord)
		if dirs.is_empty():
			continue

		var max_bottom: float = __max_door_bottom_from_height(room.height, doorway_height)
		if dirs.size() == 1:
			door_bottom_by_side[__side_key(room.coord, dirs[0])] = __sample_single_door_bottom(
				rng,
				max_bottom,
				elevated_door_chance,
				door_floor_snap_threshold
			)
			continue

		var pair: Array[float] = __sample_two_door_bottoms(
			rng,
			max_bottom,
			elevated_door_chance,
			door_split_min_delta,
			door_floor_snap_threshold
		)
		for dir_index: int in range(dirs.size()):
			var use_index: int = mini(dir_index, pair.size() - 1)
			door_bottom_by_side[__side_key(room.coord, dirs[dir_index])] = pair[use_index]

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

static func build_room(
	geom_root: Node3D,
	light_root: Node3D,
	room: RoomData,
	neighbors: Array,
	rng: RandomNumberGenerator,
	corridor_width: float,
	doorway_height: float,
	wall_thickness: float,
	floor_thickness: float,
	room_height_default: float,
	door_floor_snap_threshold: float,
	door_bridge_min_height: float,
	door_bottom_for_side: Callable
) -> void:
	var center: Vector3 = room.center
	var width: float = room.width
	var depth: float = room.depth
	var height: float = room.height
	var is_combat: bool = room.combat
	var coord: Vector2i = room.coord

	RoomLabsGeneratorBoxes.add_solid_box(
		geom_root,
		"room_floor_%d,%d" % [coord.x, coord.y],
		Vector3(width, floor_thickness, depth),
		center + Vector3(0.0, -floor_thickness * 0.5, 0.0),
		RoomLabsGeneratorMaterials.mat_floor
	)

	RoomLabsGeneratorBoxes.add_solid_box(
		geom_root,
		"room_ceiling_%d,%d" % [coord.x, coord.y],
		Vector3(width, floor_thickness, depth),
		center + Vector3(0.0, height + floor_thickness * 0.5, 0.0),
		RoomLabsGeneratorMaterials.mat_wall
	)

	var north_open: bool = (coord + Vector2i.UP) in neighbors
	var south_open: bool = (coord + Vector2i.DOWN) in neighbors
	var east_open: bool = (coord + Vector2i.RIGHT) in neighbors
	var west_open: bool = (coord + Vector2i.LEFT) in neighbors
	var north_bottom: float = (
		door_bottom_for_side.call(coord, Vector2i.UP, height)
		if north_open
		else 0.0
	)
	var south_bottom: float = (
		door_bottom_for_side.call(coord, Vector2i.DOWN, height)
		if south_open
		else 0.0
	)
	var east_bottom: float = (
		door_bottom_for_side.call(coord, Vector2i.RIGHT, height)
		if east_open
		else 0.0
	)
	var west_bottom: float = (
		door_bottom_for_side.call(coord, Vector2i.LEFT, height)
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
		north_bottom,
		corridor_width,
		doorway_height,
		wall_thickness
	)
	__build_wall_with_optional_door(
		geom_root,
		center + Vector3(0.0, 0.0, depth * 0.5),
		width,
		true,
		south_open,
		height,
		south_bottom,
		corridor_width,
		doorway_height,
		wall_thickness
	)
	__build_wall_with_optional_door(
		geom_root,
		center + Vector3(-width * 0.5, 0.0, 0.0),
		depth,
		false,
		west_open,
		height,
		west_bottom,
		corridor_width,
		doorway_height,
		wall_thickness
	)
	__build_wall_with_optional_door(
		geom_root,
		center + Vector3(width * 0.5, 0.0, 0.0),
		depth,
		false,
		east_open,
		height,
		east_bottom,
		corridor_width,
		doorway_height,
		wall_thickness
	)

	RoomLabsGeneratorRamps.add_room_door_adaptors(
		geom_root,
		room,
		neighbors,
		rng,
		corridor_width,
		floor_thickness,
		wall_thickness,
		door_floor_snap_threshold,
		door_bridge_min_height,
		door_bottom_for_side
	)

	__add_room_trim(geom_root, center, width, depth, height, wall_thickness)
	RoomLabsGeneratorLighting.add_room_ceiling_strips(
		geom_root,
		center,
		width,
		depth,
		height,
		corridor_width,
		room_height_default
	)
	RoomLabsGeneratorLighting.add_room_lights(light_root, center, width, depth, height, is_combat)

	if is_combat:
		__add_cover_props(geom_root, room, rng)

static func __build_wall_with_optional_door(
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
			RoomLabsGeneratorMaterials.mat_trim
		)

static func __add_room_trim(
	geom_root: Node3D,
	center: Vector3,
	width: float,
	depth: float,
	room_height_local: float,
	wall_thickness: float
) -> void:
	var trim_height: float = min(room_height_local * 0.58, room_height_local - 0.7)
	var trim_thickness: float = 0.25
	var trim_offset: float = wall_thickness * 0.5 + trim_thickness * 0.5

	RoomLabsGeneratorBoxes.add_solid_box(
		geom_root,
		"trim_n",
		Vector3(width * 0.85, trim_thickness, 0.35),
		center + Vector3(0.0, trim_height, -depth * 0.5 + trim_offset),
		RoomLabsGeneratorMaterials.mat_trim
	)
	RoomLabsGeneratorBoxes.add_solid_box(
		geom_root,
		"trim_s",
		Vector3(width * 0.85, trim_thickness, 0.35),
		center + Vector3(0.0, trim_height, depth * 0.5 - trim_offset),
		RoomLabsGeneratorMaterials.mat_trim
	)
	RoomLabsGeneratorBoxes.add_solid_box(
		geom_root,
		"trim_w",
		Vector3(0.35, trim_thickness, depth * 0.85),
		center + Vector3(-width * 0.5 + trim_offset, trim_height, 0.0),
		RoomLabsGeneratorMaterials.mat_trim
	)
	RoomLabsGeneratorBoxes.add_solid_box(
		geom_root,
		"trim_e",
		Vector3(0.35, trim_thickness, depth * 0.85),
		center + Vector3(width * 0.5 - trim_offset, trim_height, 0.0),
		RoomLabsGeneratorMaterials.mat_trim
	)

static func __add_cover_props(geom_root: Node3D, room: RoomData, rng: RandomNumberGenerator) -> void:
	var center: Vector3 = room.center
	var width: float = room.width
	var depth: float = room.depth
	var coord: Vector2i = room.coord
	if coord == Vector2i.ZERO:
		return

	var props: int = rng.randi_range(2, 5)
	for _i: int in range(props):
		var size_x: float = rng.randf_range(1.6, 3.2)
		var size_z: float = rng.randf_range(1.6, 3.4)
		var offset_x: float = rng.randf_range(-width * 0.33, width * 0.33)
		var offset_z: float = rng.randf_range(-depth * 0.33, depth * 0.33)
		if Vector2(offset_x, offset_z).length() < 3.4:
			continue
		var prop_size: Vector3 = Vector3(size_x, rng.randf_range(1.0, 1.6), size_z)
		RoomLabsGeneratorBoxes.add_solid_box(
			geom_root,
			"cover",
			prop_size,
			center + Vector3(offset_x, prop_size.y * 0.5, offset_z),
			RoomLabsGeneratorMaterials.mat_cover
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

static func __max_door_bottom_from_height(room_height_local: float, doorway_height: float) -> float:
	var nominal_clear_height: float = minf(doorway_height, room_height_local - 0.4)
	return maxf(room_height_local - nominal_clear_height - 0.2, 0.0)

static func __side_key(coord: Vector2i, dir: Vector2i) -> String:
	return "%s|%d,%d" % [__coord_key(coord), dir.x, dir.y]

static func __coord_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]
