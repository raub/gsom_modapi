@tool
extends GsomModContent
class_name GsomModContentController

## Base for player and AI behavior

func _get_kind() -> StringName:
	return &"controller"

func _get_default_tags() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_tags()
	base.append_array([&"controller"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base: Dictionary[StringName, Variant] = super._get_default_attrs()
	return base

func _get_default_caps() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_caps()
	base.append_array([
		&"controller",
	])
	return base
