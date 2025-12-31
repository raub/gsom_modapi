@tool
extends GsomModContentEffect
class_name GsomModContentVfx

func _get_default_tags() -> Array[StringName]:
    var base := super._get_default_tags()
    base.append_array([&"vfx"])
    return base

func _get_default_attrs() -> Dictionary:
    var base := super._get_default_attrs()
    base[&"category"] = &"vfx"
    return base

func _get_default_caps() -> Array[StringName]:
    var base := super._get_default_caps()
    base.append_array([&"visual_effect"])
    return base
