@tool
extends GsomModContent
class_name GsomModContentEffect

func _get_kind() -> StringName:
	return &"effect"

func _get_default_tags() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_tags()
	base.append_array([&"effect"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base: Dictionary[StringName, Variant] = super._get_default_attrs()
	base[&"duration"] = 0.0
	return base

func _get_default_caps() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_caps()
	base.append_array([
		&"effect",
		&"ephemeral",
		&"client_side_only",
	])
	return base
