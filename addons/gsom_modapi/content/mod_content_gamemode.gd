@tool
extends GsomModContent
class_name GsomModContentGamemode

func _get_kind() -> StringName:
	return &"gamemode"

func _get_default_tags() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_tags()
	base.append_array([&"gamemode"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base: Dictionary[StringName, Variant] = super._get_default_attrs()
	base[&"max_players"] = 4
	base[&"has_coop"] = true
	return base

func _get_default_caps() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_caps()
	base.append_array([
		&"gamemode",
	])
	return base
