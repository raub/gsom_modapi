extends RefCounted
class_name RoomLabsGeneratorRamps

const CARDINAL_DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const RoomData = RoomLabsGeneratorRooms.RoomData

static func add_room_door_adaptors(
	geom_root: Node3D,
	room: RoomData,
	neighbors: Array,
	rng: RandomNumberGenerator,
	corridor_width: float,
	floor_thickness: float,
	wall_thickness: float,
	door_floor_snap_threshold: float,
	door_bridge_min_height: float,
	door_bottom_for_side: Callable
) -> void:
	var openings: Array = []
	for dir: Vector2i in CARDINAL_DIRS:
		if !((room.coord + dir) in neighbors):
			continue
		var door_bottom: float = door_bottom_for_side.call(room.coord, dir, room.height)
		if door_bottom <= 0.05:
			continue
		var wall_length: float = __wall_length_for_dir(room, dir)
		openings.append(
			{
				"dir": dir,
				"door_bottom": door_bottom,
				"door_world_y": room.center.y + door_bottom,
				"wall_length": wall_length,
				"door_width": __door_width_for_length(corridor_width, wall_length)
			}
		)

	if openings.is_empty():
		return

	var bridged_dirs: Array = __try_add_room_door_bridge(
		geom_root,
		room,
		openings,
		rng,
		corridor_width,
		floor_thickness,
		wall_thickness,
		door_bridge_min_height
	)
	var bridged_lookup: Dictionary = {}
	for bridged_dir: Vector2i in bridged_dirs:
		bridged_lookup[bridged_dir] = true

	for opening: Dictionary in openings:
		var opening_dir: Vector2i = opening["dir"]
		if bridged_lookup.has(opening_dir):
			continue
		__build_single_door_adaptor(
			geom_root,
			room,
			opening,
			rng,
			corridor_width,
			floor_thickness,
			wall_thickness,
			door_floor_snap_threshold
		)

static func add_segmented_ramp(
	geom_root: Node3D,
	base_name: String,
	start: Vector3,
	finish: Vector3,
	width: float,
	block_variant: bool,
	material: Material,
	floor_thickness: float,
	add_cap: bool = true
) -> void:
	var horizontal_start: Vector3 = Vector3(start.x, 0.0, start.z)
	var horizontal_finish: Vector3 = Vector3(finish.x, 0.0, finish.z)
	var run: float = horizontal_start.distance_to(horizontal_finish)
	var rise: float = finish.y - start.y
	if run < 0.2:
		var low_y: float = minf(start.y, finish.y)
		var top_y: float = maxf(start.y, finish.y)
		var fallback_size_y: float = floor_thickness
		var fallback_center_y: float = top_y - floor_thickness * 0.5
		var fallback_width: float = minf(width, 0.85)
		if block_variant:
			fallback_size_y = maxf(top_y - low_y + floor_thickness, floor_thickness)
			fallback_center_y = top_y - fallback_size_y * 0.5
		RoomLabsGeneratorBoxes.add_solid_box(
			geom_root,
			base_name,
			Vector3(fallback_width, fallback_size_y, fallback_width),
			Vector3((start.x + finish.x) * 0.5, fallback_center_y, (start.z + finish.z) * 0.5),
			material
		)
		return

	var flat_delta: Vector3 = horizontal_finish - horizontal_start
	var flat_dir: Vector3 = flat_delta / run
	var slope_angle: float = atan2(rise, run)
	# Godot's +yaw rotates local +X toward -Z, so negate Z to align +X with flat_dir.
	var yaw: float = atan2(-flat_dir.z, flat_dir.x)
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
	RoomLabsGeneratorBoxes.add_oriented_box(
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
		var cap_length: float = minf(width * 0.42, run * 0.33)
		cap_length = minf(cap_length, 0.9)
		if cap_length < 0.18:
			cap_length = 0.0
		var cap_gap: float = 0.01
		if cap_length > 0.0:
			var cap_center: Vector3 = (
				high_point
				+ away_from_low_dir * (cap_length * 0.5 + cap_gap)
				- Vector3(0.0, floor_thickness * 0.5, 0.0)
			)
			RoomLabsGeneratorBoxes.add_oriented_box(
				geom_root,
				"%s_cap" % base_name,
				Vector3(cap_length, floor_thickness, width),
				cap_center,
				cap_basis,
				material
			)

	if !block_variant:
		return

	var low_support_y: float = minf(start.y, finish.y) - floor_thickness * 0.25
	var high_support_y: float = maxf(start.y, finish.y) - floor_thickness * 0.25
	var support_height: float = maxf(high_support_y - low_support_y, floor_thickness)
	var support_center: Vector3 = Vector3(ramp_midpoint.x, (low_support_y + high_support_y) * 0.5, ramp_midpoint.z)
	RoomLabsGeneratorBoxes.add_oriented_box(
		geom_root,
		"%s_support" % base_name,
		Vector3(run + 0.05, support_height, width * 0.92),
		support_center,
		cap_basis,
		RoomLabsGeneratorMaterials.mat_cover
	)

static func __try_add_room_door_bridge(
	geom_root: Node3D,
	room: RoomData,
	openings: Array,
	rng: RandomNumberGenerator,
	corridor_width: float,
	floor_thickness: float,
	wall_thickness: float,
	door_bridge_min_height: float
) -> Array:
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

	var chosen_pair: Array = pair_indices[rng.randi_range(0, pair_indices.size() - 1)]
	var opening_a: Dictionary = elevated[chosen_pair[0]]
	var opening_b: Dictionary = elevated[chosen_pair[1]]
	var dir_a_chosen: Vector2i = opening_a["dir"]
	var dir_b_chosen: Vector2i = opening_b["dir"]
	var bottom_a: float = opening_a["door_bottom"]
	var bottom_b: float = opening_b["door_bottom"]
	var bridge_local_y: float = minf(bottom_a, bottom_b)
	if bridge_local_y < door_bridge_min_height:
		return []
	var bridge_world_y: float = room.center.y + bridge_local_y

	var runs_x: bool = abs(dir_a_chosen.x) > 0
	var bridge_frame_offset: float = -wall_thickness * 0.5 + 0.03
	var anchor_a: Vector3 = __door_inside_anchor(
		room,
		dir_a_chosen,
		bridge_local_y,
		wall_thickness,
		bridge_frame_offset,
		0.0
	)
	var anchor_b: Vector3 = __door_inside_anchor(
		room,
		dir_b_chosen,
		bridge_local_y,
		wall_thickness,
		bridge_frame_offset,
		0.0
	)
	var bridge_length: float = (
		absf(anchor_b.x - anchor_a.x)
		if runs_x
		else absf(anchor_b.z - anchor_a.z)
	) - wall_thickness
	if bridge_length <= corridor_width * 0.8:
		return []
	var bridge_width: float = clampf(corridor_width * 0.72, 1.8, 4.2)
	var bridge_center: Vector3 = Vector3(
		(anchor_a.x + anchor_b.x) * 0.5 if runs_x else room.center.x,
		bridge_world_y - floor_thickness * 0.5,
		room.center.z if runs_x else (anchor_a.z + anchor_b.z) * 0.5
	)
	var bridge_size: Vector3 = (
		Vector3(bridge_length, floor_thickness, bridge_width)
		if runs_x
		else Vector3(bridge_width, floor_thickness, bridge_length)
	)
	RoomLabsGeneratorBoxes.add_solid_box(
		geom_root,
		"door_bridge",
		bridge_size,
		bridge_center,
		RoomLabsGeneratorMaterials.mat_trim
	)

	for opening_link: Dictionary in [opening_a, opening_b]:
		var dir_link: Vector2i = opening_link["dir"]
		var door_bottom_link: float = opening_link["door_bottom"]
		var door_point: Vector3 = __door_inside_anchor(
			room,
			dir_link,
			door_bottom_link,
			wall_thickness,
			bridge_frame_offset,
			0.0
		)
		var bridge_point: Vector3 = Vector3(door_point.x, bridge_world_y, door_point.z)
		if bridge_point.distance_to(door_point) >= 0.2:
			add_segmented_ramp(
				geom_root,
				"door_bridge_link",
				bridge_point,
				door_point,
				minf(bridge_width * 0.8, 2.4),
				false,
				RoomLabsGeneratorMaterials.mat_trim,
				floor_thickness
			)

	var ramp_count: int = 1 + (1 if rng.randf() < 0.55 else 0)
	for _ramp_index: int in range(ramp_count):
		if runs_x:
			var sign_z: float = -1.0 if rng.randf() < 0.5 else 1.0
			var top_x: float = rng.randf_range(-bridge_length * 0.25, bridge_length * 0.25)
			var top_point_x: Vector3 = room.center + Vector3(top_x, bridge_local_y, sign_z * bridge_width * 0.35)
			var run_z: float = clampf(bridge_local_y * 2.0 + rng.randf_range(0.4, 1.8), 2.0, room.depth * 0.36)
			var base_point_x: Vector3 = top_point_x + Vector3(0.0, 0.0, sign_z * run_z)
			base_point_x.y = room.center.y
			base_point_x = __clamp_point_inside_room(room, base_point_x, 0.5)
			add_segmented_ramp(
				geom_root,
				"door_bridge_ramp",
				base_point_x,
				top_point_x,
				minf(corridor_width * 0.48, 2.2),
				false,
				RoomLabsGeneratorMaterials.mat_floor,
				floor_thickness,
				false
			)
			continue

		var sign_x: float = -1.0 if rng.randf() < 0.5 else 1.0
		var top_z: float = rng.randf_range(-bridge_length * 0.25, bridge_length * 0.25)
		var top_point_z: Vector3 = room.center + Vector3(sign_x * bridge_width * 0.35, bridge_local_y, top_z)
		var run_x: float = clampf(bridge_local_y * 2.0 + rng.randf_range(0.4, 1.8), 2.0, room.width * 0.36)
		var base_point_z: Vector3 = top_point_z + Vector3(sign_x * run_x, 0.0, 0.0)
		base_point_z.y = room.center.y
		base_point_z = __clamp_point_inside_room(room, base_point_z, 0.5)
		add_segmented_ramp(
			geom_root,
			"door_bridge_ramp",
			base_point_z,
			top_point_z,
			minf(corridor_width * 0.48, 2.2),
			false,
			RoomLabsGeneratorMaterials.mat_floor,
			floor_thickness,
			false
		)

	return [dir_a_chosen, dir_b_chosen]

static func __build_single_door_adaptor(
	geom_root: Node3D,
	room: RoomData,
	opening: Dictionary,
	rng: RandomNumberGenerator,
	corridor_width: float,
	floor_thickness: float,
	wall_thickness: float,
	door_floor_snap_threshold: float
) -> void:
	var door_bottom: float = opening["door_bottom"]
	if door_bottom <= 0.05:
		return

	var block_variant: bool = false
	if door_bottom <= door_floor_snap_threshold + 0.2:
		__build_door_step_adaptor(
			geom_root,
			room,
			opening,
			rng,
			corridor_width,
			floor_thickness,
			wall_thickness,
			block_variant
		)
		return

	var roll: float = rng.randf()
	if roll < 0.38:
		__build_wall_strip_adaptor(
			geom_root,
			room,
			opening,
			rng,
			corridor_width,
			floor_thickness,
			wall_thickness,
			true,
			block_variant
		)
		return
	if roll < 0.7:
		__build_wall_strip_adaptor(
			geom_root,
			room,
			opening,
			rng,
			corridor_width,
			floor_thickness,
			wall_thickness,
			false,
			block_variant
		)
		return
	__build_door_step_adaptor(
		geom_root,
		room,
		opening,
		rng,
		corridor_width,
		floor_thickness,
		wall_thickness,
		block_variant
	)

static func __build_wall_strip_adaptor(
	geom_root: Node3D,
	room: RoomData,
	opening: Dictionary,
	rng: RandomNumberGenerator,
	corridor_width: float,
	floor_thickness: float,
	wall_thickness: float,
	wall_to_wall: bool,
	block_variant: bool
) -> void:
	var dir: Vector2i = opening["dir"]
	var door_bottom: float = opening["door_bottom"]
	var door_world_y: float = opening.get("door_world_y", room.center.y + door_bottom)
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
		var side_sign: float = -1.0 if rng.randf() < 0.5 else 1.0
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

	var platform_center: Vector3 = __door_inside_anchor(room, dir, 0.0, wall_thickness, platform_depth * 0.5 + 0.15, along_offset)
	__add_elevated_platform(
		geom_root,
		"door_platform_strip",
		platform_center,
		along_is_x,
		span_along,
		platform_depth,
		room.center.y,
		door_world_y,
		floor_thickness,
		block_variant
	)

	var ramp_count: int = 1
	if wall_to_wall and door_bottom > 1.7 and rng.randf() < 0.6:
		ramp_count = 2

	var ramp_signs: Array[float] = [-1.0 if rng.randf() < 0.5 else 1.0]
	if ramp_count == 2:
		ramp_signs = [-1.0, 1.0]

	var built_ramps: int = 0
	for ramp_sign: float in ramp_signs:
		var top_offset: float = ramp_sign * maxf(span_along * 0.5 - 0.22, 0.05)
		var top_point: Vector3 = (
			platform_center
			+ along * top_offset
			+ inward * maxf(platform_depth * 0.5 - 0.08, 0.05)
			+ Vector3(0.0, door_world_y - platform_center.y, 0.0)
		)
		var run_length: float = clampf(
			door_bottom * rng.randf_range(1.8, 2.6),
			1.6,
			wall_length * 0.42
		)
		if __add_adaptor_ramp(
			geom_root,
			room,
			top_point,
			inward,
			run_length,
			minf(platform_depth * 0.9, 2.2),
			floor_thickness,
			block_variant
		):
			built_ramps += 1

	if !wall_to_wall and door_bottom <= 1.6 and rng.randf() < 0.5:
		var frontal_top: Vector3 = (
			platform_center
			+ inward * maxf(platform_depth * 0.5 - 0.08, 0.05)
			+ Vector3(0.0, door_world_y - platform_center.y, 0.0)
		)
		if __add_adaptor_ramp(
			geom_root,
			room,
			frontal_top,
			inward,
			clampf(door_bottom * 2.2 + 0.4, 1.4, 3.8),
			minf(span_along * 0.5, 2.6),
			floor_thickness,
			block_variant
		):
			built_ramps += 1

	if built_ramps == 0:
		var fallback_top: Vector3 = (
			platform_center
			+ inward * maxf(platform_depth * 0.5 - 0.08, 0.05)
			+ Vector3(0.0, door_world_y - platform_center.y, 0.0)
		)
		__add_adaptor_ramp(
			geom_root,
			room,
			fallback_top,
			inward,
			clampf(door_bottom * 2.1 + 0.4, 1.2, wall_length * 0.45),
			minf(span_along * 0.6, 2.6),
			floor_thickness,
			block_variant
		)

static func __build_door_step_adaptor(
	geom_root: Node3D,
	room: RoomData,
	opening: Dictionary,
	rng: RandomNumberGenerator,
	corridor_width: float,
	floor_thickness: float,
	wall_thickness: float,
	block_variant: bool
) -> void:
	var dir: Vector2i = opening["dir"]
	var door_bottom: float = opening["door_bottom"]
	var door_world_y: float = opening.get("door_world_y", room.center.y + door_bottom)
	var wall_length: float = opening["wall_length"]
	var door_width: float = opening["door_width"]
	var inward: Vector3 = __door_inward_axis(dir)
	var along: Vector3 = __door_along_axis(dir)
	var along_is_x: bool = absf(along.x) > 0.5

	var step_span: float = clampf(
		door_width + rng.randf_range(0.3, 2.0),
		door_width + 0.2,
		wall_length - 0.9
	)
	var step_depth: float = clampf(rng.randf_range(0.9, 2.4), 0.9, 3.0)
	var step_center: Vector3 = __door_inside_anchor(room, dir, 0.0, wall_thickness, step_depth * 0.5 + 0.12, 0.0)
	__add_elevated_platform(
		geom_root,
		"door_platform_step",
		step_center,
		along_is_x,
		step_span,
		step_depth,
		room.center.y,
		door_world_y,
		floor_thickness,
		block_variant
	)

	var built_ramps: int = 0
	if door_bottom <= 1.35 and rng.randf() < 0.65:
		var frontal_top: Vector3 = (
			step_center
			+ inward * maxf(step_depth * 0.5 - 0.08, 0.05)
			+ Vector3(0.0, door_world_y - step_center.y, 0.0)
		)
		if __add_adaptor_ramp(
			geom_root,
			room,
			frontal_top,
			inward,
			clampf(door_bottom * 2.4 + 0.5, 1.2, 4.2),
			minf(step_span * 0.6, corridor_width * 0.7),
			floor_thickness,
			block_variant
		):
			return

	var ramp_count: int = 1 + (1 if door_bottom > 2.2 and rng.randf() < 0.6 else 0)
	var ramp_signs: Array[float] = [-1.0 if rng.randf() < 0.5 else 1.0]
	if ramp_count == 2:
		ramp_signs = [-1.0, 1.0]
	for ramp_sign: float in ramp_signs:
		var lateral_top: Vector3 = (
			step_center
			+ along * (ramp_sign * maxf(step_span * 0.5 - 0.2, 0.05))
			+ inward * maxf(step_depth * 0.5 - 0.08, 0.05)
			+ Vector3(0.0, door_world_y - step_center.y, 0.0)
		)
		if __add_adaptor_ramp(
			geom_root,
			room,
			lateral_top,
			inward,
			clampf(door_bottom * 2.1 + rng.randf_range(0.2, 1.2), 1.5, wall_length * 0.38),
			minf(step_depth * 0.9, 2.0),
			floor_thickness,
			block_variant
		):
			built_ramps += 1

	if built_ramps == 0:
		var fallback_top: Vector3 = (
			step_center
			+ inward * maxf(step_depth * 0.5 - 0.08, 0.05)
			+ Vector3(0.0, door_world_y - step_center.y, 0.0)
		)
		__add_adaptor_ramp(
			geom_root,
			room,
			fallback_top,
			inward,
			clampf(door_bottom * 2.2 + 0.35, 1.2, wall_length * 0.45),
			minf(step_span * 0.62, corridor_width * 0.82),
			floor_thickness,
			block_variant
		)

static func __add_elevated_platform(
	geom_root: Node3D,
	base_name: String,
	center: Vector3,
	along_is_x: bool,
	span_along: float,
	span_inward: float,
	floor_y: float,
	top_world_y: float,
	floor_thickness: float,
	block_variant: bool
) -> void:
	var slab_size: Vector3 = (
		Vector3(span_along, floor_thickness, span_inward)
		if along_is_x
		else Vector3(span_inward, floor_thickness, span_along)
	)
	RoomLabsGeneratorBoxes.add_solid_box(
		geom_root,
		base_name,
		slab_size,
		Vector3(center.x, top_world_y - floor_thickness * 0.5, center.z),
		RoomLabsGeneratorMaterials.mat_trim
	)
	var elevation: float = top_world_y - floor_y
	if !block_variant or elevation <= 0.08:
		return

	var support_size: Vector3 = slab_size
	support_size.x = maxf(support_size.x - 0.45, 0.35)
	support_size.z = maxf(support_size.z - 0.45, 0.35)
	support_size.y = maxf(elevation - floor_thickness, 0.05)
	RoomLabsGeneratorBoxes.add_solid_box(
		geom_root,
		"%s_support" % base_name,
		support_size,
		Vector3(center.x, floor_y + support_size.y * 0.5, center.z),
		RoomLabsGeneratorMaterials.mat_cover
	)

static func __add_adaptor_ramp(
	geom_root: Node3D,
	room: RoomData,
	top_point: Vector3,
	top_to_base_direction: Vector3,
	desired_run: float,
	width: float,
	floor_thickness: float,
	block_variant: bool
) -> bool:
	var horizontal_dir: Vector3 = Vector3(top_to_base_direction.x, 0.0, top_to_base_direction.z)
	if horizontal_dir.length() <= 0.01:
		return false
	horizontal_dir = horizontal_dir.normalized()
	var base_point: Vector3 = top_point + horizontal_dir * desired_run
	base_point.y = room.center.y
	base_point = __clamp_point_inside_room(room, base_point, 0.55)

	var horizontal_span: float = Vector2(base_point.x - top_point.x, base_point.z - top_point.z).length()
	if horizontal_span < 0.8:
		return false

	add_segmented_ramp(
		geom_root,
		"door_ramp",
		base_point,
		top_point,
		width,
		false,
		RoomLabsGeneratorMaterials.mat_floor,
		floor_thickness,
		false
	)
	return true

static func __clamp_point_inside_room(room: RoomData, point: Vector3, margin: float = 0.4) -> Vector3:
	return Vector3(
		clampf(point.x, room.center.x - room.width * 0.5 + margin, room.center.x + room.width * 0.5 - margin),
		point.y,
		clampf(point.z, room.center.z - room.depth * 0.5 + margin, room.center.z + room.depth * 0.5 - margin)
	)

static func __door_width_for_length(corridor_width: float, wall_length: float) -> float:
	return maxf(1.25, minf(corridor_width + 1.0, wall_length - 2.0))

static func __door_inward_axis(dir: Vector2i) -> Vector3:
	if dir == Vector2i.UP:
		return Vector3(0.0, 0.0, 1.0)
	if dir == Vector2i.DOWN:
		return Vector3(0.0, 0.0, -1.0)
	if dir == Vector2i.LEFT:
		return Vector3(1.0, 0.0, 0.0)
	if dir == Vector2i.RIGHT:
		return Vector3(-1.0, 0.0, 0.0)
	return Vector3.ZERO

static func __door_along_axis(dir: Vector2i) -> Vector3:
	if dir == Vector2i.UP or dir == Vector2i.DOWN:
		return Vector3(1.0, 0.0, 0.0)
	return Vector3(0.0, 0.0, 1.0)

static func __wall_length_for_dir(room: RoomData, dir: Vector2i) -> float:
	if dir == Vector2i.UP or dir == Vector2i.DOWN:
		return room.width
	return room.depth

static func __wall_distance_for_dir(room: RoomData, dir: Vector2i) -> float:
	if dir == Vector2i.UP or dir == Vector2i.DOWN:
		return room.depth * 0.5
	return room.width * 0.5

static func __door_inside_anchor(
	room: RoomData,
	dir: Vector2i,
	y: float,
	wall_thickness: float,
	inward_offset: float = 0.6,
	along_offset: float = 0.0
) -> Vector3:
	var inward: Vector3 = __door_inward_axis(dir)
	var along: Vector3 = __door_along_axis(dir)
	var wall_center: Vector3 = room.center - inward * __wall_distance_for_dir(room, dir)
	return wall_center + inward * (wall_thickness * 0.5 + inward_offset) + along * along_offset + Vector3(0.0, y, 0.0)
