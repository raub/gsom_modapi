@tool
extends GsomModContent
class_name GsomModContentController

## Base for player and AI behavior

func _get_kind() -> StringName:
	return &"controller"

func _get_default_tags() -> Array[StringName]:
	return [&"controller"]

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	return {
		&"view": "fps",
	}

func _get_default_caps() -> Array[StringName]:
	return [
		&"controller",
	]
