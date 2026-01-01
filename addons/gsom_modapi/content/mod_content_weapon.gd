@tool
extends GsomModContentItem
class_name GsomModContentWeapon

func _get_default_tags() -> Array[StringName]:
	var base := super._get_default_tags()
	base.append_array([&"weapon"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base := super._get_default_attrs()
	base[&"damage"] = base.get(&"damage", 10.0)
	base[&"fire_rate"] = base.get(&"fire_rate", 1.0)
	base[&"weapon_class"] = base.get(&"weapon_class", &"generic")
	return base

func _get_default_caps() -> Array[StringName]:
	var base := super._get_default_caps()
	base.append_array([
		&"equippable_weapon",
		&"deals_damage",
	])
	return base
