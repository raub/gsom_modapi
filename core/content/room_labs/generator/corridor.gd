extends RefCounted
class_name RoomLabsGeneratorCorridor

const RoomData = RoomLabsGeneratorRooms.RoomData

static func build_corridor(
	geom_root: Node3D,
	rooms_by_key: Dictionary[String, RoomData],
	neighbors_by_key: Dictionary,
	a_coord: Vector2i,
	b_coord: Vector2i,
	corridor_width: float,
	wall_thickness: float,
	floor_thickness: float,
	room_height_default: float,
	door_bottom_for_side: Callable
) -> void:
	var key_a: String = __coord_key(a_coord)
	var key_b: String = __coord_key(b_coord)
	if !neighbors_by_key.has(key_a) or !neighbors_by_key.has(key_b):
		return
	var a_room: RoomData = rooms_by_key[__coord_key(a_coord)]
	var b_room: RoomData = rooms_by_key[__coord_key(b_coord)]

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
		var a_floor_y: float = door_bottom_for_side.call(a_coord, a_dir, a_room.height)
		var b_floor_y: float = door_bottom_for_side.call(b_coord, b_dir, b_room.height)
		var left_floor_y: float = a_floor_y if direction == Vector2i.RIGHT else b_floor_y
		var right_floor_y: float = b_floor_y if direction == Vector2i.RIGHT else a_floor_y
		__build_corridor_segment(
			geom_root,
			Vector3(center_x, 0.0, center_z),
			length,
			true,
			corridor_height,
			left_floor_y,
			right_floor_y,
			corridor_width,
			wall_thickness,
			floor_thickness,
			room_height_default
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
		var a_floor_y_z: float = door_bottom_for_side.call(a_coord, a_dir_z, a_room.height)
		var b_floor_y_z: float = door_bottom_for_side.call(b_coord, b_dir_z, b_room.height)
		var north_floor_y: float = b_floor_y_z if direction == Vector2i.UP else a_floor_y_z
		var south_floor_y: float = a_floor_y_z if direction == Vector2i.UP else b_floor_y_z
		__build_corridor_segment(
			geom_root,
			Vector3(center_x2, 0.0, center_z2),
			length_z,
			false,
			corridor_height_z,
			north_floor_y,
			south_floor_y,
			corridor_width,
			wall_thickness,
			floor_thickness,
			room_height_default
		)

static func __build_corridor_segment(
	geom_root: Node3D,
	center: Vector3,
	length: float,
	runs_x: bool,
	corridor_height: float,
	start_floor_y: float,
	end_floor_y: float,
	corridor_width: float,
	wall_thickness: float,
	floor_thickness: float,
	room_height_default: float
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
	RoomLabsGeneratorRamps.add_segmented_ramp(
		geom_root,
		"corridor_floor",
		start_point,
		end_point,
		corridor_width,
		true,
		RoomLabsGeneratorMaterials.mat_floor,
		floor_thickness,
		false
	)

	var highest_floor: float = maxf(start_floor_y, end_floor_y)
	var envelope_height: float = corridor_height + highest_floor
	var ceiling_size: Vector3 = (
		Vector3(length, floor_thickness, corridor_width)
		if runs_x
		else Vector3(corridor_width, floor_thickness, length)
	)
	RoomLabsGeneratorBoxes.add_solid_box(
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
	RoomLabsGeneratorBoxes.add_solid_box(
		geom_root,
		"corridor_wall_a",
		wall_size,
		center + Vector3(0.0, envelope_height * 0.5, 0.0) + wall_offset_axis,
		RoomLabsGeneratorMaterials.mat_wall
	)
	RoomLabsGeneratorBoxes.add_solid_box(
		geom_root,
		"corridor_wall_b",
		wall_size,
		center + Vector3(0.0, envelope_height * 0.5, 0.0) - wall_offset_axis,
		RoomLabsGeneratorMaterials.mat_wall
	)

	RoomLabsGeneratorLighting.add_ceiling_strip(
		geom_root,
		center + Vector3(0.0, 0.0, 0.0),
		length * 0.8,
		corridor_width,
		room_height_default,
		runs_x,
		envelope_height
	)

static func __coord_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]
