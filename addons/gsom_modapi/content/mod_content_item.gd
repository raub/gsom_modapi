@tool
extends GsomModContent
class_name GsomModContentItem

func _get_kind() -> StringName:
	return &"item"

func _get_default_tags() -> Array[StringName]:
	return [&"item"]

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	return {
		&"rarity": &"common",
		&"value": 0,
		&"stack_size": 1,
	}

func _get_default_caps() -> Array[StringName]:
	return [
		&"lootable",
		&"inventory_item",
	]
