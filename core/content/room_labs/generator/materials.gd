extends RefCounted
class_name RoomLabsGeneratorMaterials

static var mat_floor: StandardMaterial3D
static var mat_wall: StandardMaterial3D
static var mat_trim: StandardMaterial3D
static var mat_cover: StandardMaterial3D
static var mat_light: StandardMaterial3D

static func prepare() -> void:
	mat_floor = load(&"res://core/content/room_labs/vfx/floor.material")
	mat_wall = load(&"res://core/content/room_labs/vfx/wall.material")

	mat_trim = StandardMaterial3D.new()
	mat_trim.albedo_color = Color(0.18, 0.29, 0.38)
	mat_trim.roughness = 0.52
	mat_trim.metallic = 0.38

	mat_cover = StandardMaterial3D.new()
	mat_cover.albedo_color = Color(0.22, 0.25, 0.3)
	mat_cover.roughness = 0.78
	mat_cover.metallic = 0.2

	mat_light = StandardMaterial3D.new()
	mat_light.albedo_color = Color(0.66, 0.78, 0.92)
	mat_light.emission_enabled = true
	mat_light.emission = Color(0.4, 0.6, 0.95)
	mat_light.emission_energy_multiplier = 1.35
	mat_light.metallic = 0.0
	mat_light.roughness = 1.0
