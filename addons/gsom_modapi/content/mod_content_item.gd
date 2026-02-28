@tool
extends GsomModContent
class_name GsomModContentItem

func _get_kind() -> StringName:
	return &"item"

func _get_default_tags() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_tags()
	base.append_array([&"item"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base: Dictionary[StringName, Variant] = super._get_default_attrs()
	base[&"rarity"] = &"common"
	base[&"value"] = 0
	base[&"stack_size"] = 1
	return base

func _get_default_caps() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_caps()
	base.append_array([
		&"item",
	])
	return base
