@tool
extends GsomModContentActor
class_name GsomModContentNpc

func _get_default_tags() -> Array[StringName]:
    var base := super._get_default_tags()
    base.append_array([&"npc"])
    return base

func _get_default_attrs() -> Dictionary:
    var base := super._get_default_attrs()
    base[&"faction"] = &"neutral"
    base[&"dialogue_role"] = &"generic"
    return base

func _get_default_caps() -> Array[StringName]:
    var base := super._get_default_caps()
    base.append_array([
        &"non_hostile",
        &"can_interact",
        &"dialogue_npc",
    ])
    return base
