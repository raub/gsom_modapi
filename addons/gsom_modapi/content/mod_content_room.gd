@tool
extends GsomModContent
class_name GsomModContentRoom

func _get_kind() -> StringName:
	return &"room"

func _get_default_tags() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_tags()
	base.append_array([&"room"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base: Dictionary[StringName, Variant] = super._get_default_attrs()
	base[&"difficulty"] = 1
	base[&"size"] = &"medium"
	base[&"biome"] = &"generic"
	return base

func _get_default_caps() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_caps()
	base.append_array([
		&"room_chunk",
		&"spawn_anchor",
	])
	return base
