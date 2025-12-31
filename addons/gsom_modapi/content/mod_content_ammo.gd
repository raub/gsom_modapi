@tool
extends GsomModContentItem
class_name GsomModContentAmmo

func _get_default_tags() -> Array[StringName]:
	var base := super._get_default_tags()
	base.append_array([&"ammo"])
	return base

func _get_default_attrs() -> Dictionary:
	var base := super._get_default_attrs()
	base[&"ammo_type"] = &"generic"
	base[&"stack_size"] = 100
	return base

func _get_default_caps() -> Array[StringName]:
	var base := super._get_default_caps()
	base.append_array([&"consumable_ammo"])
	return base
