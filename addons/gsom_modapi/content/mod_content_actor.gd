@tool
extends GsomModContent
class_name GsomModContentActor

## Base for anything that has a presence, can move/animate, and usually has health.

func _get_kind() -> StringName:
	return &"actor"

func _get_default_tags() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_tags()
	base.append_array([&"actor"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base: Dictionary[StringName, Variant] = super._get_default_attrs()
	base[&"base_hp"] = 100.0
	base[&"base_speed"] = 10.0
	base[&"base_accel"] = 10.0
	return base

func _get_default_caps() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_caps()
	base.append_array([
		&"health",
		&"transform",
		&"velocity",
		&"actor",
	])
	return base
