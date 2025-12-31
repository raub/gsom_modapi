extends RefCounted
class_name GsomModMeta

## Redefine this in subclasses
func _mod_init() -> void:
	push_warning("Method '_mod_init' not implemented.")

## Redefine this in subclasses
func _get_version() -> StringName:
	push_warning("Method '_get_version' not implemented.")
	return &"0"
