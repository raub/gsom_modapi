extends RefCounted
class_name RoomLabsGeneratorLighting

class RoomLightGrid:
	var lights_x: int = 1
	var lights_z: int = 1
	var step_x: float = 0.0
	var step_z: float = 0.0

static func add_ceiling_strip(
	add_solid_box: Callable,
	geom_root: Node3D,
	center: Vector3,
	length: float,
	corridor_width: float,
	default_room_height: float,
	runs_x: bool = true,
	ceiling_height: float = 0.0
) -> void:
	var ceiling_y: float = ceiling_height if ceiling_height > 0.0 else default_room_height
	var strip_width: float = min(corridor_width * 0.35, 1.8)
	var strip_size: Vector3 = (
		Vector3(length, 0.12, strip_width)
		if runs_x
		else Vector3(strip_width, 0.12, length)
	)
	add_solid_box.call(
		geom_root,
		"ceiling_strip",
		strip_size,
		center + Vector3(0.0, ceiling_y - 0.05, 0.0),
		RoomLabsGeneratorMaterials.mat_light,
		false
	)

static func add_room_ceiling_strips(
	add_solid_box: Callable,
	geom_root: Node3D,
	center: Vector3,
	width: float,
	depth: float,
	room_height_local: float,
	corridor_width: float,
	default_room_height: float
) -> void:
	var grid: RoomLightGrid = __room_light_grid(width, depth)
	var runs_x: bool = width >= depth
	var segment_length: float = (
		minf(grid.step_x * 0.72, width * 0.32)
		if runs_x
		else minf(grid.step_z * 0.72, depth * 0.32)
	)
	segment_length = clampf(segment_length, 1.4, 4.8)

	for x_index: int in range(grid.lights_x):
		for z_index: int in range(grid.lights_z):
			var offset_x: float = -width * 0.5 + grid.step_x * float(x_index + 1)
			var offset_z: float = -depth * 0.5 + grid.step_z * float(z_index + 1)
			add_ceiling_strip(
				add_solid_box,
				geom_root,
				center + Vector3(offset_x, 0.0, offset_z),
				segment_length,
				corridor_width,
				default_room_height,
				runs_x,
				room_height_local
			)

static func add_room_lights(
	light_root: Node3D,
	center: Vector3,
	width: float,
	depth: float,
	room_height_local: float,
	is_combat: bool
) -> void:
	var grid: RoomLightGrid = __room_light_grid(width, depth)
	var base_range: float = clampf(maxf(width, depth) * 0.55, 8.5, 14.0)

	for x_index: int in range(grid.lights_x):
		for z_index: int in range(grid.lights_z):
			var light: OmniLight3D = OmniLight3D.new()
			var offset_x: float = -width * 0.5 + grid.step_x * float(x_index + 1)
			var offset_z: float = -depth * 0.5 + grid.step_z * float(z_index + 1)
			light.position = center + Vector3(offset_x, room_height_local - 2.0, offset_z)
			light.light_color = Color(0.9, 0.87, 0.85) if is_combat else Color(0.8, 0.90, 0.85)
			light.light_energy = 0.55 if is_combat else 0.38
			light.omni_range = base_range + (1.2 if is_combat else 0.0)
			light.shadow_enabled = false
			light_root.add_child(light)

static func add_base_environment_lighting(root: Node3D, light_root: Node3D) -> void:
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = &"AmbientEnv"
	var env: Environment = Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.25, 0.32)
	env.ambient_light_energy = 0.2
	world_env.environment = env
	root.add_child(world_env)

	var directional: DirectionalLight3D = DirectionalLight3D.new()
	directional.name = &"SoftFillDirectional"
	directional.rotation_degrees = Vector3(-58.0, 28.0, 0.0)
	directional.light_color = Color(0.72, 0.82, 0.95)
	directional.light_energy = 0.16
	directional.shadow_enabled = false
	light_root.add_child(directional)

static func __room_light_grid(width: float, depth: float) -> RoomLightGrid:
	var grid: RoomLightGrid = RoomLightGrid.new()
	grid.lights_x = maxi(1, int(floorf(width / 10.0)))
	grid.lights_z = maxi(1, int(floorf(depth / 10.0)))
	grid.step_x = width / float(grid.lights_x + 1)
	grid.step_z = depth / float(grid.lights_z + 1)
	return grid
