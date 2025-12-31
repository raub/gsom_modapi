@tool
extends GsomModContent
class_name GsomModContentRoom

func _get_kind() -> StringName:
	return &"room"

func _get_default_tags() -> Array[StringName]:
	return [&"room"]

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	return {
		&"difficulty": 1,
		&"size": &"medium",
		&"biome": &"generic",
	}

func _get_default_caps() -> Array[StringName]:
	return [
		&"room_chunk",
		&"spawn_anchor",
	]
