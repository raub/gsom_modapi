@tool
extends GsomModContent
class_name GsomModContentEffect

func _get_kind() -> StringName:
	return &"effect"

func _get_default_tags() -> Array[StringName]:
	return [&"effect"]

func _get_default_attrs() -> Dictionary:
	return {
		&"duration": 0.0, # 0 = instantaneous
	}

func _get_default_caps() -> Array[StringName]:
	return [
		&"ephemeral",
		&"client_side_only",
	]
