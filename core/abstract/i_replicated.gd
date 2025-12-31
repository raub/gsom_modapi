extends Node
class_name IReplicated

## This is the base interface that all game-modes will implement.
##
## This class is opensourced for modders to share common ground in codebase.

var entity: SvcSpawn.Entity = null
var is_dirty: bool = false

func _assign_data(_data: Variant) -> void:
	pass

func _assign_payload(_payload: Variant) -> void:
	pass

func _create_payload() -> Variant:
	return null
