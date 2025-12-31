@tool
extends GsomModContent
class_name GsomModContentStatus

func _get_kind() -> StringName:
    return &"status"

func _get_default_tags() -> Array[StringName]:
    return [&"status"]

func _get_default_attrs() -> Dictionary:
    return {
        &"duration": 0.0, # 0 = instant, >0 = timed
        &"is_buff": false,
        &"max_stacks": 1,
    }

func _get_default_caps() -> Array[StringName]:
    return [
        &"status_effect",
    ]
