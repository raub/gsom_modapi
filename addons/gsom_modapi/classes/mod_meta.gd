extends RefCounted
class_name GsomModMeta

## Redefine this in subclasses
func _mod_init() -> void:
	assert(false, "Not implemented")

## Redefine this in subclasses
func _get_version() -> StringName:
	assert(false, "Not implemented")
	return &"0"
