@tool
extends GsomModContent
class_name GsomModContentStatus

func _get_kind() -> StringName:
	return &"status"

func _get_default_tags() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_tags()
	base.append_array([&"status"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base: Dictionary[StringName, Variant] = super._get_default_attrs()
	base[&"duration"] = 0.0
	base[&"is_buff"] = false
	base[&"max_stacks"] = 1
	return base

func _get_default_caps() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_caps()
	base.append_array([
		&"status_effect",
	])
	return base
