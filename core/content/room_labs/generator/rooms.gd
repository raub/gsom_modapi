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

	RoomLabsGeneratorDoors.build_wall_with_optional_door(
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
	RoomLabsGeneratorDoors.build_wall_with_optional_door(
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
	RoomLabsGeneratorDoors.build_wall_with_optional_door(
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
	RoomLabsGeneratorDoors.build_wall_with_optional_door(
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
