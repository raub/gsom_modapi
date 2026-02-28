@tool
extends EditorPlugin

const SpawnSelectorScript = preload("res://addons/gsom_modapi/nodes/spawn_selector.gd")

var __spawn_selector_registered: bool = false

func _enable_plugin() -> void:
	__register_custom_nodes()
	add_autoload_singleton("GsomModapi", "./gsom_modapi_autoload.gd")


func _disable_plugin() -> void:
	__unregister_custom_nodes()
	remove_autoload_singleton("GsomModapi")

func __register_custom_nodes() -> void:
	if __spawn_selector_registered:
		return

	var icon: Texture2D = EditorInterface.get_base_control().get_theme_icon(
		&"Node3D",
		&"EditorIcons"
	)
	add_custom_type(
		"GsomModSpawnSelector",
		"Node3D",
		SpawnSelectorScript,
		icon
	)
	__spawn_selector_registered = true

func __unregister_custom_nodes() -> void:
	if !__spawn_selector_registered:
		return

	remove_custom_type("GsomModSpawnSelector")
	__spawn_selector_registered = false
