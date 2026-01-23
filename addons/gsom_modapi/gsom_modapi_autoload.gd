extends Node

const ModRegistry = preload("./helpers/mod_registry.gd")
const ModLoader = preload("./helpers/mod_loader.gd")
const ModDeps = preload("./helpers/mod_deps.gd")

## This is [b]an autoload singleton[/b], that becomes globally available when you enable the plugin.

var scene: Node = null
var __core: GsomModCore = null

func _ready() -> void:
	scene = Node.new()
	add_child(scene)

func launch(core_pck: String, core_script: String) -> void:
	if core_pck:
		var result: bool = ProjectSettings.load_resource_pack(core_pck, false)
		if !result:
			push_error("Error loading PCK '%s'." % core_pck)
			return
	
	ModLoader.load_mods()
	
	var script: GDScript = load(core_script) as GDScript
	var inst: Variant = script.new()
	if !(inst is GsomModCore):
		push_error("The core script should extend 'GsomModCore'.")
		return
	__core = inst
	
	ModLoader.start_phase("~")
	__core._mod_init()
	ModLoader.end_phase()
	
	__core._core_main.call_deferred()


func register(desc: GsomModContent) -> GsomModContent:
	return ModRegistry.register(desc)

func content_by_id(id: StringName) -> GsomModContent:
	return ModRegistry.get_by_id(id)

func content_by_kind(kind: StringName) -> Array[GsomModContent]:
	return ModRegistry.get_by_kind(kind)

func content_by_key(key: StringName) -> GsomModContent:
	return ModRegistry.get_by_key(key)

func content_by_key_all(key: StringName) -> Array[GsomModContent]:
	return ModRegistry.get_by_key_all(key)

func content_by_query(query: GsomModQueryFilter) -> Array[GsomModContent]:
	return ModRegistry.get_by_query(query)

func content_by_mod(mod: StringName) -> Array[GsomModContent]:
	return ModRegistry.get_by_mod(mod)

func traverse_selector(selector: GsomModSelector) -> Array[StringName]:
	return ModDeps.traverse_selector(selector)

func traverse_query(query: GsomModQueryBase) -> Array[StringName]:
	return ModDeps.traverse_query(query)

func traverse_content(content: GsomModContent) -> Array[StringName]:
	return ModDeps.traverse_content(content)
