@tool
extends GsomModContentItem
class_name GsomModContentConsumable

func _get_default_tags() -> Array[StringName]:
	var base := super._get_default_tags()
	base.append_array([&"consumable"])
	return base

func _get_default_attrs() -> Dictionary:
	var base := super._get_default_attrs()
	base[&"uses"] = base.get(&"uses", 1)
	return base

func _get_default_caps() -> Array[StringName]:
	var base := super._get_default_caps()
	base.append_array([
		&"usable_item",
		&"single_use",
	])
	return base
