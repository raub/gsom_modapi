@tool
extends GsomModContent
class_name GsomModContentSelector

func _get_kind() -> StringName:
	return &"selector"

func _get_default_tags() -> Array[StringName]:
	return [&"selector"]

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	return {
		&"selector_type": &"loot",
	}

func _get_default_caps() -> Array[StringName]:
	return [
		&"content_selector",
	]
