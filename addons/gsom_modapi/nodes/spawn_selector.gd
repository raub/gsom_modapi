@tool
extends Node3D
class_name GsomModSpawnSelector

const DEBUG_MESH_NAME: StringName = &"DebugMesh"
const DEBUG_MESH_PATH: NodePath = ^"DebugMesh"
const GROUP_NAME: StringName = &"GsomModSpawnSelector"

@export var selector: GsomModSelector = null:
	set(value):
		selector = value
		update_configuration_warnings()

@export var debug_visible_in_editor: bool = true:
	set(value):
		debug_visible_in_editor = value
		__refresh_debug_mesh()

@export_range(0.1, 10.0, 0.1) var debug_size: float = 0.5:
	set(value):
		debug_size = maxf(0.1, value)
		__refresh_debug_mesh()

@export var debug_color: Color = Color(0.2, 0.95, 0.65, 0.35):
	set(value):
		debug_color = value
		__refresh_debug_mesh()

var __debug_mesh: MeshInstance3D = null

func _enter_tree() -> void:
	add_to_group(GROUP_NAME)
	__refresh_debug_mesh()

func _ready() -> void:
	__refresh_debug_mesh()

func _exit_tree() -> void:
	if is_in_group(GROUP_NAME):
		remove_from_group(GROUP_NAME)
	__remove_debug_mesh()

func _get_configuration_warnings() -> PackedStringArray:
	if selector == null:
		return PackedStringArray([
			"Assign a GsomModSelector resource.",
		])
	return PackedStringArray()

func get_selector() -> GsomModSelector:
	return selector

func get_content_ids() -> Array[StringName]:
	if selector == null:
		return []
	return GsomModapi.traverse_selector(selector)

static func get_group_name() -> StringName:
	return GROUP_NAME

static func find_all(tree: SceneTree) -> Array[GsomModSpawnSelector]:
	var result: Array[GsomModSpawnSelector] = []
	if tree == null:
		return result

	for node: Node in tree.get_nodes_in_group(GROUP_NAME):
		var spawn_selector: GsomModSpawnSelector = node as GsomModSpawnSelector
		if spawn_selector:
			result.append(spawn_selector)

	return result

func __refresh_debug_mesh() -> void:
	update_configuration_warnings()

	if !is_inside_tree():
		return

	var should_show_debug: bool = Engine.is_editor_hint() and debug_visible_in_editor
	if !should_show_debug:
		__remove_debug_mesh()
		return

	if __debug_mesh == null:
		__debug_mesh = get_node_or_null(DEBUG_MESH_PATH) as MeshInstance3D

	if __debug_mesh == null:
		__debug_mesh = MeshInstance3D.new()
		__debug_mesh.name = DEBUG_MESH_NAME
		__debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		__debug_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(__debug_mesh)
		__debug_mesh.owner = null

	__debug_mesh.visible = true

	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = debug_size
	mesh.height = debug_size * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	__debug_mesh.mesh = mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = debug_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.emission_enabled = true
	material.emission = debug_color
	material.emission_energy_multiplier = 0.6
	__debug_mesh.material_override = material

func __remove_debug_mesh() -> void:
	if __debug_mesh == null:
		return

	__debug_mesh.queue_free()
	__debug_mesh = null
