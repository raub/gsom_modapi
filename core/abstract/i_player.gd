extends IController
class_name IPlayer

## This is the base player controller interface.
##
## Note: [readonly] means if you mutate it, you will face a terrible fate.
## There is no need for over-engineered precautions, you've been warned.

## [readonly] Is this the local player.
##
## Network implementation must inject `peer_identity` before _sv/_cl init.
## Each peer only has one "local" player controller - the one they are in control of.
var is_local: bool:
	get: return peer_identity == net.local_identity

## [readonly] Persistent peer identification - even after reconnect.
##
## This is assigned automatically when player spawns (before `_ready`).
var peer_identity: StringName = &""

## Only called on local player (after sv_, before cl_).
##
## This is where the peer input actions are collected.
## The format is controller-specific - this is what you get in `_apply_actions`.
##
## This is different from "reliable events":
## - Unreliable channel is utilized.
## - Network actively polls this, instead of waiting for event to happen.
## - You can't produce actions for other player controllers (possible with events).
func _local_tick(_dt: float) -> Variant:
	assert(false, "Not implemented")
	return null

## Apply the actions from `_local_tick`.
##
## - Server applies actions from each peer to their respective IPlayer.
## - Client self-applies their own actions for smooth prediction.
func _apply_actions(_actions: Variant) -> void:
	assert(false, "Not implemented")

## Update player based on their peer changes.
##
## When peer disconnects by accident, it counts as "update" to `peer.connected`.
func _sv_peer_update(_peer: IPeer) -> void:
	pass
