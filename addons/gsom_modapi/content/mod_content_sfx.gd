@tool
extends GsomModContentEffect
class_name GsomModContentSfx

func _get_default_tags() -> Array[StringName]:
	var base := super._get_default_tags()
	base.append_array([&"sfx"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base := super._get_default_attrs()
	base[&"category"] = &"sfx"
	return base

func _get_default_caps() -> Array[StringName]:
	var base := super._get_default_caps()
	base.append_array([&"audio_effect"])
	return base
