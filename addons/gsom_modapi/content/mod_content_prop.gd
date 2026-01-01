@tool
extends GsomModContent
class_name GsomModContentProp

func _get_kind() -> StringName:
	return &"prop"

func _get_default_tags() -> Array[StringName]:
	return [&"prop"]

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	return {
		&"static": true,
	}

func _get_default_caps() -> Array[StringName]:
	return [
		&"world_prop",
	]
