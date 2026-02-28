@tool
extends GsomModContentActor
class_name GsomModContentProjectile

func _get_default_tags() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_tags()
	base.append_array([&"projectile"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base: Dictionary[StringName, Variant] = super._get_default_attrs()
	base[&"hp_max"] = 0.0
	base[&"speed"] = 20.0
	base[&"lifetime"] = 5.0
	base[&"gravity_scale"] = 1.0
	return base

func _get_default_caps() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_caps()
	base.append_array([
		&"projectile",
		&"deals_damage",
		&"destroy_on_hit",
	])
	return base
