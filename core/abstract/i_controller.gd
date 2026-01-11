extends IGsomEntity
class_name IGsomController

## This is a replicated controller interface.
##
## Controllers are used to orchestrate game logic and input.
## They work behind the scenes - you can't see them, you see through them.
##
## Note, guideline keywords:
## - [optional] - it's ok to omit implementation.
## - [server] - this will not be called on clients.

## [server, optional] Advance the authority simulation.
func _sv_tick(_dt: float) -> void:
	pass

## [optional] Update client-side representation.
func _cl_tick(_dt: float) -> void:
	pass
