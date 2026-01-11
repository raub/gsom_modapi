extends IGsomController
class_name IGsomPlayer

## This is the base player controller interface.
##
## Note, guideline keywords:
## - [readonly] - if you mutate it, you will face a terrible fate.
## - [required] - there is no "default" implementation.
## - [optional] - it's ok to omit implementation.
## - [server] - this will not be called on clients.
## - [core] - it is safe to assume the Core has implemented it.

## [readonly core] Persistent peer identification - even after reconnect.
##
## Injected before `_ready` (before `_sv_ready` and `_cl_ready`).
var peer_identity: StringName = &""

## Is this the local player.
##
## Each peer only has one "local" player controller - the one they are in control of.
## This check is valid on and after `_ready` (on `_sv_ready` and `_cl_ready`).
func check_is_local() -> bool:
	return peer_identity == net.get_local_identity()

## Is this the host player.
##
## Each server only has one "host" player at most.
## This check is valid on and after `_ready` (on `_sv_ready` and `_cl_ready`).
func check_is_host() -> bool:
	return peer_identity == net.get_host_identity()

## [required] Only called on local player (after `sv_tick`, before `cl_tick`).
##
## This is where the peer input actions are collected.
## The format is controller-specific - this is what you will get in `_apply_actions`.
##
## This is different from "reliable events":
## - Unreliable channel is utilized.
## - Network actively polls this, instead of waiting for event to happen.
## - You can't produce actions for other player controllers (possible with events).
##
## IMPORTANT:
## - Always pair with `_apply_actions` implementation: `actions` are delivered verbatim.
## - Channel is unreliable. Packets may be lost or ignored due to out-of-order.
## - Packet ordering is implemented by the Core, no need to encode and check it.
func _local_tick(_dt: float) -> Variant:
	assert(false, "Not implemented")
	return null

## [required] Apply the actions from `_local_tick`.
##
## - Server applies actions from each peer to their respective IGsomPlayer.
## - Client self-applies their own actions for smooth prediction.
##
## IMPORTANT:
## - Always pair with `_local_tick` implementation: `actions` are delivered verbatim.
## - Channel is unreliable. Packets may be lost or ignored due to out-of-order.
## - Packet ordering is implemented by the Core, no need to encode and check it.
func _apply_actions(_actions: Variant) -> void:
	assert(false, "Not implemented")

## [optional server] Update the player, based on their peer changes.
##
## This is called when fields are modified in the player-related peer.
## When the peer disconnects/reconnects, it counts as an "update" too.
func _sv_peer_update(_peer: IGsomPeer) -> void:
	pass
