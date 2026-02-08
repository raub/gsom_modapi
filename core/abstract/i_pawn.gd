extends IGsomEntity
class_name IGsomPawn

## Base for replicated playable characters.
##
## This type of entity can be posessed by a player controller.
## When posessed by a player, the server slightly changes the event routing.
## Such that the player peer can dictate the pawn state changes.
##
## Note, guideline keywords:
## - [readonly] - if you mutate it, you will face a terrible fate.
## - [required] - there is no "default" implementation.
## - [optional] - it's ok to omit implementation.
## - [server] - this will not be called on clients.
## - [core] - it is safe to assume the Core has implemented it.

## [readonly core] Server-assigned network ID of active player.
##
## This mirrors `player.pawn_id`.
var player_id: int = IGsomNetwork.NET_ID_EMPTY

## [required] Apply the actions from controller `_local_tick`.
##
## - Server delivers actions from each IGsomPlayer to their posessed pawn.
## - Client self-applies their own actions for smooth prediction.
##
## IMPORTANT:
## - Always pair with `_local_tick` implementation: `actions` are delivered verbatim.
## - Channel is unreliable. Packets may be lost or ignored due to out-of-order.
## - Packet ordering is implemented by the Core, no need to encode and check it.
func _apply_actions(_actions: Variant) -> void:
	assert(false, "Not implemented")

## [server optional] Do something when posessed by the player.
##
## By this moment, `player_id` has already been set.
func _sv_posessed() -> void:
	assert(false, "Not implemented")

## [server optional] Do something when the player stops posession of this entity.
##
## By this moment, `player_id` has already been set.
func _sv_dismissed() -> void:
	assert(false, "Not implemented")
