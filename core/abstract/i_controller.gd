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

## On server, read a reliable event from a client
func _sv_read_event(_peer_id: int, _e: Variant) -> void:
	pass

## On client, read a reliable event from the server
func _cl_read_event(_e: Variant) -> void:
	pass
