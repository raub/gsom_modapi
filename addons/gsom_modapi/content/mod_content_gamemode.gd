@tool
extends GsomModContent
class_name GsomModContentGamemode

const __gamemode_tags: Array[StringName] = [&"gamemode"]
const __gamemode_attrs: Dictionary[StringName, Variant] = {
	&"max_players": 4,
	&"has_coop": true,
}
const __gamemode_caps: Array[StringName] = [
	&"gamemode",
]

func _get_kind() -> StringName:
	return &"gamemode"

func _get_default_tags() -> Array[StringName]:
	return __gamemode_tags

func _get_default_attrs() -> Dictionary[StringName, Variant]:
	return __gamemode_attrs

func _get_default_caps() -> Array[StringName]:
	return __gamemode_caps
