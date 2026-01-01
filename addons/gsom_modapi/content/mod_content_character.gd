@tool
extends GsomModContentActor
class_name GsomModContentCharacter

func _get_default_tags() -> Array[StringName]:
	var base := super._get_default_tags()
	base.append_array([&"character", &"player"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base := super._get_default_attrs()
	base[&"faction"] = &"player"
	base[&"can_respawn"] = true
	base[&"has_inventory"] = true
	return base

func _get_default_caps() -> Array[StringName]:
	var base := super._get_default_caps()
	base.append_array([
		&"controllable",
		&"player_character",
		&"has_inventory",
	])
	return base
