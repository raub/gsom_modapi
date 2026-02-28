@tool
extends GsomModContentProp
class_name GsomModContentInteractable

func _get_default_tags() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_tags()
	base.append_array([&"interactable"])
	return base

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	var base: Dictionary[StringName, Variant] = super._get_default_attrs()
	base[&"use_prompt"] = "Use"
	return base

func _get_default_caps() -> Array[StringName]:
	var base: Array[StringName] = super._get_default_caps()
	base.append_array([
		&"interactable",
		&"trigger_on_use",
	])
	return base
