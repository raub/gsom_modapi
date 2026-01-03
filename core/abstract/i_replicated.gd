extends Node
class_name IReplicated

## Base for any network-visible object.
##
## This class is opensourced for modders to share common ground in codebase.

var entity: SvcSpawn.Entity = null

## Accept extra data duting spawn
func _cl_init(_data: Variant) -> void:
	pass

## Accept an update payload
func _cl_unpack(_payload: Variant) -> void:
	pass

func _sv_pack() -> Variant:
	return null
