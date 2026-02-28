@tool
extends GsomModContentActor
class_name GsomModContentMob

func _get_default_tags() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_tags()
	base.append_array([&"mob"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base: Dictionary[StringName, Variant] = super._get_default_attrs()
	base[&"difficulty"] = 0
	base[&"threat"] = 0
	base[&"faction"] = &"neutral"
	return base

func _get_default_caps() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_caps()
	base.append_array([
		&"spawnable",
		&"mob",
		&"drops_loot",
	])
	return base
