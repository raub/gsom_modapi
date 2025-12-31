@tool
extends GsomModContentStatus
class_name GsomModContentUpgrade

func _get_default_tags() -> Array[StringName]:
    var base := super._get_default_tags()
    base.append_array([&"upgrade"])
    return base

func _get_default_attrs() -> Dictionary:
    var base := super._get_default_attrs()
    base[&"is_buff"] = true
    base[&"upgrade_scope"] = base.get(&"upgrade_scope", &"run") # "run" or "meta"
    return base

func _get_default_caps() -> Array[StringName]:
    var base := super._get_default_caps()
    base.append_array([
        &"upgrade_effect",
    ])
    return base
