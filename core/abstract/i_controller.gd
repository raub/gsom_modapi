extends IReplicator
class_name IController

## This is a replicated controller interface.
##
## Controllers are used to orchestrate game logic and input.
## They work behind the scenes - you can't see them, you see through them.

## Advance the authority simulation
func _sv_tick(_dt: float) -> void:
	pass

## Update client-side representation
func _cl_tick(_dt: float) -> void:
	pass
