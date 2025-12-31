@tool
extends GsomModContent
class_name GsomModContentActor

## Base for anything that has a presence, can move/animate, and usually has health.

func _get_kind() -> StringName:
	return &"actor"

func _get_default_tags() -> Array[StringName]:
	return [&"actor"]

func _get_default_attrs() -> Dictionary:
	return {
		&"base_hp": 100.0,
		&"base_speed": 10.0,
		&"base_accel": 10.0,
	}

func _get_default_caps() -> Array[StringName]:
	return [
		&"health",
		&"transform",
		&"velocity",
		&"actor",
	]
