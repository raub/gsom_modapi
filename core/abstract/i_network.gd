extends Node
class_name IGsomNetwork

## Interface declaration for a global networking service.
##
## This is what **Core implements**.
## I.e. opposed to IGsomEntity implementations, shipped by mods.
##
## Note, guideline keywords:
## - [readonly] - if you mutate it, you will face a terrible fate.
## - [core] - it is safe to assume the Core has implemented it.
## - [server] - calling it from non-host will have no effect.

## Default value for net_id and peer.id. Valid values start at 1.
const NET_ID_EMPTY: int = 0

## First peer id - the local peer starts with this ID on `IGsomNetwork._init`.
const PEER_ID_FIRST: int = 1

enum SpawnLayer {
	WORLD,
	ACTORS,
	ITEMS,
	EFFECTS,
	CONTROLLERS,
	HUD,
	MENU,
}

## [core] Which peer is the host (at process startup - this one).
##
## Connecting to other hosts should re-assign `host_identity`.
func get_host_identity() -> StringName:
	assert(false, "Not implemented")
	return &""

## [core] Is this instance the host?
##
## You always launch the game process as a host.
## Will become false upon successfully joining the game.
func check_is_host() -> bool:
	assert(false, "Not implemented")
	return true

## [core] Identity of the local peer.
func get_local_identity() -> StringName:
	assert(false, "Not implemented")
	return &""

#region Instigator

## [core server] Register an instigator. Server-only.
##
## Registering the same key will override the instigator data.
## Do not register instigators for peers - that is done automatically.
func _sv_register_instigator(
	_identity: StringName,
	_kind: IGsomInstigator.Kind,
	_label: String,
	_content_id: StringName = &"",
) -> IGsomInstigator:
	assert(false, "Not implemented")
	return null

## [core] Fetch instigator by key.
##
## Note: as peers are instigators, they are available through this API too.
func _get_instigator(_identity: StringName) -> IGsomInstigator:
	assert(false, "Not implemented")
	return null

## [core server] Set the instigator label.
##
## This is equivalent for calling `instigator._sv_set_label`.
## Won't invoke `_sv_peer_update` even if the instigator is peer.
##
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_instigator_label(
	_identity: StringName,
	_label: String,
) -> void:
	assert(false, "Not implemented")

## [core] Shortcut to get the instigator label.
##
## This is equivalent for calling `instigator._get_label`.
func _get_instigator_label(_identity: StringName) -> String:
	assert(false, "Not implemented")
	return ""

## [core server] Set an integer instigator attribute.
##
## This is equivalent for calling `instigator._sv_set_attr_int`.
## Won't invoke `_sv_peer_update` even if the instigator is peer.
##
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_instigator_attr_int(
	_identity: StringName,
	_key: StringName,
	_value: int,
) -> void:
	assert(false, "Not implemented")

## [core server] Set a boolean instigator attribute.
##
## This is equivalent for calling `instigator._sv_set_attr_bool`.
## Won't invoke `_sv_peer_update` even if the instigator is peer.
##
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_instigator_attr_bool(
	_identity: StringName,
	_key: StringName,
	_value: bool,
) -> void:
	assert(false, "Not implemented")

## [core server] Set a string instigator attribute.
##
## This is equivalent for calling `instigator._sv_set_attr_string`.
## Won't invoke `_sv_peer_update` even if the instigator is peer.
##
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_instigator_attr_string(
	_identity: StringName,
	_key: StringName,
	_value: String,
) -> void:
	assert(false, "Not implemented")

## [core server] Set a float instigator attribute.
##
## This is equivalent for calling `instigator._sv_set_attr_float`.
## Won't invoke `_sv_peer_update` even if the instigator is peer.
##
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_instigator_attr_float(
	_identity: StringName,
	_key: StringName,
	_value: float,
) -> void:
	assert(false, "Not implemented")

## [core] Get an integer instigator attribute. Default - `0`.
##
## This is equivalent for calling `instigator._get_attr_int`.
func _get_instigator_attr_int(_identity: StringName, _key: StringName) -> int:
	assert(false, "Not implemented")
	return 0

## [core] Get a boolean instigator attribute. Default - `false`.
##
## This is equivalent for calling `instigator._get_attr_bool`.
func _get_instigator_attr_bool(_identity: StringName, _key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

## [core] Get a string instigator attribute. Default - `""`.
##
## This is equivalent for calling `instigator._get_attr_string`.
func _get_instigator_attr_string(_identity: StringName, _key: StringName) -> String:
	assert(false, "Not implemented")
	return ""

## [core] Get a float instigator attribute. Default - `0.0`.
##
## This is equivalent for calling `instigator._get_attr_float`.
func _get_instigator_attr_float(_identity: StringName, _key: StringName) -> float:
	assert(false, "Not implemented")
	return 0

## [core] Check if an integer instigator attribute exists.
##
## This is equivalent for calling `instigator._has_attr_int`.
func _has_instigator_attr_int(_identity: StringName, _key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

## [core] Check if a boolean instigator attribute exists.
##
## This is equivalent for calling `instigator._has_attr_bool`.
func _has_instigator_attr_bool(_identity: StringName, _key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

## [core] Check if a string instigator attribute exists.
##
## This is equivalent for calling `instigator._has_attr_string`.
func _has_instigator_attr_string(_identity: StringName, _key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

## [core] Check if a float instigator attribute exists.
##
## This is equivalent for calling `instigator._has_attr_float`.
func _has_instigator_attr_float(_identity: StringName, _key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

#endregion Instigator

#region Peer

## [core] This process' local peer.
##
## The "local" player will spawn for this peer when GameMode starts.
## It starts as "host" when game process starts.
## Connecting to other hosts will re-assign `local_peer.id`, but not `identity`.
func get_local_peer() -> IGsomPeer:
	assert(false, "Not implemented")
	return null

## [core] Get a peer by identity string.
func _get_peer(_identity: StringName) -> IGsomPeer:
	assert(false, "Not implemented")
	return null

## [core] List of all peers.
func _get_peers_all() -> Array[IGsomPeer]:
	assert(false, "Not implemented")
	return []

## [core] List of connected peers.
func _get_peers_connected() -> Array[IGsomPeer]:
	assert(false, "Not implemented")
	return []

## [core server] Set the peer label.
##
## This is equivalent for calling `peer._sv_set_label`.
## Will invoke `_sv_peer_update` on IGsomGameMode and related IGsomPlayer.
##
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_peer_label(
	_identity: StringName,
	_label: String,
) -> void:
	assert(false, "Not implemented")

## [core] Shortcut to get the peer label.
##
## This is equivalent for calling `peer._get_label`.
func _get_peer_label(_identity: StringName) -> String:
	assert(false, "Not implemented")
	return ""

## [core server] Set an integer peer attribute.
##
## This is equivalent for calling `peer._sv_set_attr_int`.
## Will invoke `_sv_peer_update` on IGsomGameMode and related IGsomPlayer.
##
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_peer_attr_int(
	_identity: StringName,
	_key: StringName,
	_value: int,
) -> void:
	assert(false, "Not implemented")

## [core server] Set a boolean peer attribute.
##
## This is equivalent for calling `peer._sv_set_attr_bool`.
## Will invoke `_sv_peer_update` on IGsomGameMode and related IGsomPlayer.
##
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_peer_attr_bool(
	_identity: StringName,
	_key: StringName,
	_value: bool,
) -> void:
	assert(false, "Not implemented")

## [core server] Set a string peer attribute.
##
## This is equivalent for calling `peer._sv_set_attr_string`.
## Will invoke `_sv_peer_update` on IGsomGameMode and related IGsomPlayer.
##
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_peer_attr_string(
	_identity: StringName,
	_key: StringName,
	_value: String,
) -> void:
	assert(false, "Not implemented")

## [core server] Set a float peer attribute.
##
## This is equivalent for calling `peer._sv_set_attr_float`.
## Will invoke `_sv_peer_update` on IGsomGameMode and related IGsomPlayer.
##
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_peer_attr_float(
	_identity: StringName,
	_key: StringName,
	_value: float,
) -> void:
	assert(false, "Not implemented")

## [core] Get an integer peer attribute. Default - `0`.
##
## This is equivalent for calling `peer._get_attr_int`.
func _get_peer_attr_int(_identity: StringName, _key: StringName) -> int:
	assert(false, "Not implemented")
	return 0

## [core] Get a boolean peer attribute. Default - `false`.
##
## This is equivalent for calling `peer._get_attr_bool`.
func _get_peer_attr_bool(_identity: StringName, _key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

## [core] Get a string peer attribute. Default - `""`.
##
## This is equivalent for calling `peer._get_attr_string`.
func _get_peer_attr_string(_identity: StringName, _key: StringName) -> String:
	assert(false, "Not implemented")
	return ""

## [core] Get a float peer attribute. Default - `0.0`.
##
## This is equivalent for calling `peer._get_attr_float`.
func _get_peer_attr_float(_identity: StringName, _key: StringName) -> float:
	assert(false, "Not implemented")
	return 0

## [core] Check if an integer peer attribute exists.
##
## This is equivalent for calling `peer._has_attr_int`.
func _has_peer_attr_int(_identity: StringName, _key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

## [core] Check if a boolean peer attribute exists.
##
## This is equivalent for calling `peer._has_attr_bool`.
func _has_peer_attr_bool(_identity: StringName, _key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

## [core] Check if a string peer attribute exists.
##
## This is equivalent for calling `peer._has_attr_string`.
func _has_peer_attr_string(_identity: StringName, _key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

## [core] Check if a float peer attribute exists.
##
## This is equivalent for calling `peer._has_attr_float`.
func _has_peer_attr_float(_identity: StringName, _key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

#endregion Peer

#region Entity

## [core] The current active game mode instance.
##
## Will be `null` while no game mode is running.
func _get_game_mode() -> IGsomGameMode:
	assert(false, "Not implemented")
	return null

## [core] Fetch a player controller by (peer) identity.
##
## Will be `null` if the player has not yet spawned.
func _get_player(_identity: StringName) -> IGsomPlayer:
	assert(false, "Not implemented")
	return null

## [core] Fetch all player controllers.
##
## Note: players and peers are separate things, players are ingame entities,
## while peers are network clients that continue to exist outside game-modes.
func _get_players() -> Array[IGsomPlayer]:
	assert(false, "Not implemented")
	return []

## [core server] Create an entity. Host-only.
##
## Returns the spawned entity or `null` if failed.
## E.g. you shoot a rocket - `_sv_tick` of the launcher (or of the player) calls this.
func _sv_spawn(
	_content_id: StringName,
	_layer: IGsomNetwork.SpawnLayer = IGsomNetwork.SpawnLayer.WORLD,
	_init_data: Variant = null,
	_instigator_key: StringName = &"",
) -> IGsomEntity:
	assert(false, "Not implemented")
	return null

## [core server] Remove an entity. Host-only.
##
## E.g. a grenade has blown up - `_sv_tick` of the grenade calls this.
func _sv_despawn(_net_id: int) -> void:
	assert(false, "Not implemented")

## [core] Send a reliable event to the server instance of `net_id` (usually `sender.net_id`)
##
## Usually, client entities would report events to their server counterpart.
## But it is possible to send events from any client entity, and to any server entity.
##
## On server it will trigger `entity._sv_read_event`.
## If the recipient entity doesn't exist on the server, this call has no effect.
##
## On host, this can be called too, i.e. from the client code.
##
## Ideally, this event should be efficiently packed,
## but a simple Dictionary will also work.
func _cl_send_event(_net_id: int, _e: IGsomEntity.Event) -> void:
	assert(false, "Not implemented")

## [core server] Broadcast a reliable event to ALL instances of `net_id`.
## 
## Usually, server entities would broadcast events to themselves.
## But it is possible to send events from any, and to any entity.
##
## Server broadcast will trigger `entity._cl_read_event` on all clients.
## If the recipient entity doesn't exist on a client, this call has no effect to them.
##
## Ideally, this event should be efficiently packed,
## but a simple Dictionary will also work.
func _sv_send_event(_net_id: int, _e: IGsomEntity.Event) -> void:
	assert(false, "Not implemented")

## [core] Entity lookup by `net_id`.
##
## The implementation may store entities in any way. This makes them available by ID.
## 
## Note: entities are intrinsicly unstable.
## - It is normal that they spawn and despawn all the time.
## - It is a good idea to check if the returned entity is not `null`.
## - It is a bad idea to preserve the reference beyond this tick.
func _get_entity(_net_id: int) -> IGsomEntity:
	assert(false, "Not implemented")
	return null

## [core] Entity lookup by `layer`.
func _get_entities_by_layer(_layer: SpawnLayer) -> Array[IGsomEntity]:
	assert(false, "Not implemented")
	return []

#endregion Entity
