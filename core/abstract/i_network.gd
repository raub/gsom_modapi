extends Node
class_name INetwork

## Interface declaration for a global networking service.
## Default value for net_id and peer.id. Valid values start at 1.
const NET_ID_EMPTY: int = 0

## First peer id - the local peer starts with this ID on `INetwork._init`.
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

## This process' local peer.
##
## The "local" player will spawn for this peer when GameMode starts.
## It starts as "host" when game process starts.
## Connecting to other hosts will re-assign `local_peer.id`, but not `identity`.
func get_local_peer() -> IPeer:
	assert(false, "Not implemented")
	return null
	

## Which peer is the host (at process startup - this one).
##
## Connecting to other hosts should re-assign `host_identity`.
func get_host_identity() -> StringName:
	assert(false, "Not implemented")
	return &""

## Is this instance the host?
##
## You always launch the game process as a host.
## Will become false upon successfully joining the game.
func check_is_host() -> bool:
	assert(false, "Not implemented")
	return true

## Identity of the local peer.
func get_local_identity() -> StringName:
	assert(false, "Not implemented")
	return &""

## Create an entity. Host-only.
##
## Returns the spawned entity or `null` if failed.
## E.g. you shoot a rocket - `_sv_tick` of the launcher (or of the player) calls this.
func _sv_spawn(
	_content_id: StringName,
	_layer: INetwork.SpawnLayer = INetwork.SpawnLayer.WORLD,
	_init_data: Variant = null,
	_instigator_key: StringName = &"",
) -> IReplicator:
	assert(false, "Not implemented")
	return null

## Remove an entity. Host-only.
##
## E.g. a grenade has blown up - `_sv_tick` of the grenade calls this.
func _sv_despawn(_net_id: int) -> void:
	assert(false, "Not implemented")

## Send a reliable event to the server instance of `net_id` (usually `sender.net_id`)
##
## On host, this can be called too, from the client code.
## Ideally, this event should be efficiently packed, but a simple Dictionary will also work.
func _cl_send_event(_net_id: int, _e: IReplicator.Event) -> void:
	assert(false, "Not implemented")

## Broadcast a reliable event to ALL instances of `net_id` (usually `sender.net_id`)
##
## Only server can call it.
## Ideally, this event should be efficiently packed, but a simple Dictionary will also work.
func _sv_send_event(_net_id: int, _e: IReplicator.Event) -> void:
	assert(false, "Not implemented")

## Entity lookup by `net_id`.
##
## The implementation may store entities in any way. This makes them available by ID.
func _get_entity(_net_id: int) -> IReplicator:
	assert(false, "Not implemented")
	return null

## Entity lookup by `layer`.
func _get_entities_by_layer(_layer: SpawnLayer) -> Array[IReplicator]:
	assert(false, "Not implemented")
	return []

## Simply get a peer by identity string (same as `net.peers[identity]`).
##
## Because `peer.id` is volatile it is recommended to use `peer.identity`.
## The former is used in low-level network routing, and not game logic.
func _get_peer(_identity: StringName) -> IPeer:
	assert(false, "Not implemented")
	return null

## List of all peers.
func _get_peers_all() -> Array[IPeer]:
	assert(false, "Not implemented")
	return []

## List of connected peers.
func _get_peers_connected() -> Array[IPeer]:
	assert(false, "Not implemented")
	return []

## Update peer data.
##
## Will invoke `_sv_peer_update` on IGameMode and related IPlayer.
##
## Only server can call it.
func _sv_set_peer(_identity: StringName, _peer: IPeer) -> void:
	assert(false, "Not implemented")

## Assign instigator data.
##
## Registering the same key will override the instigator data.
##
## Only server can call it.
func _sv_set_instigator(_instigator: IInstigator) -> void:
	assert(false, "Not implemented")

## Fetch instigator data by key.
func _get_instigator(_key: StringName) -> IInstigator:
	assert(false, "Not implemented")
	return null
