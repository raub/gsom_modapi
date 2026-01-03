extends IReplicated
class_name IController

## This is a replicated controller interface.
##
## Controllers are used to orchestrate game logic and input.
## They work behind the scenes - you can't see them, you see through them.
##
## This class is opensourced for modders to share common ground in codebase.

## Receive and apply state changes according to peer events.
func _sv_tick(_delta: float) -> void:
	pass

## Receive and apply actions from server.
##
## Local player uses this too, but favors the realtime changes from `_local_tick`
func _cl_tick(_delta: float) -> void:
	pass
