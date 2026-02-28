@tool
extends GsomModContentItem
class_name GsomModContentWeapon

func _get_default_tags() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_tags()
	base.append_array([&"weapon"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base: Dictionary[StringName, Variant] = super._get_default_attrs()
	base[&"damage"] = 10.0
	base[&"fire_rate"] = 1.0
	base[&"weapon_class"] = &"generic"
	return base

func _get_default_caps() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_caps()
	base.append_array([
		&"equip",
		&"weapon",
		&"deals_damage",
	])
	return base
