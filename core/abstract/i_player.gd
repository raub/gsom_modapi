extends IController
class_name IPlayer

var is_local: bool = false

## This is the base player controller interface.
##
## This class is opensourced for modders to share common ground in codebase.

## This is only called on local player (before sv_ and cl_).
##
## Local player is special: it immediately applies certain actions.
## Also this is where the peer input events are generated.
func _local_tick(_delta: float) -> Array[SvcNetwork.Event]:
	return [] as Array[SvcNetwork.Event]
