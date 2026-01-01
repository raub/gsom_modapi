@tool
extends GsomModContentActor
class_name GsomModContentMob

func _get_default_tags() -> Array[StringName]:
	var base := super._get_default_tags()
	base.append_array([&"mob", &"enemy"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base := super._get_default_attrs()
	base[&"difficulty"] = base.get(&"difficulty", 1)
	base[&"threat"] = base.get(&"threat", 1)
	base[&"faction"] = &"enemy"
	return base

func _get_default_caps() -> Array[StringName]:
	var base := super._get_default_caps()
	base.append_array([
		&"hostile_ai",
		&"spawnable_mob",
		&"drops_loot",
	])
	return base
