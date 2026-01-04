extends IController
class_name IPlayer

## This is the base player controller interface.

## Local player is special: each peer only has one - the one they are in control of.
var is_local: bool = false

## Only called on local player (after sv_, before cl_).
##
## This is where the peer input events are generated.
## The format is controller-specific - this is what you get in `_apply_actions`.
func _local_tick(_dt: float) -> Variant:
	return null

## Apply the actions from `_local_tick`.
##
## - Server applies actions from each peer to their respective IPlayer
## - Client self-applies their own actions for smooth predict
func _apply_actions(_actions: Variant) -> void:
	pass
