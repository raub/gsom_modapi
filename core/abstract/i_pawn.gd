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
