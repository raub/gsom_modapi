extends IGsomNetwork
class_name GsomNetworkImpl

signal gamemode_started()
signal gamemode_ended()

enum EventKind {
	# New entity created (net_id, content_id, transform, data)
	SPAWN,
	# Remove entity by net_id
	DESPAWN,
	# Apply player action from peer
	ACTION,
	# Apply snapshot changes to world objects
	SNAPSHOT,
	# Internal message from entity to entity
	ENTITY,
	# Broadcast peer update
	PEER,
	# Broadcast instigator update
	INSTIGATOR,
}

var __svc_spawn: SvcSpawn = null

class Event:
	var kind: EventKind = EventKind.SNAPSHOT
	var data: Variant = null

class EventDataSpawn:
	var net_id: int = IGsomNetwork.NET_ID_EMPTY
	var instigator: StringName = &""
	var content_id: StringName = &""
	var layer: IGsomNetwork.SpawnLayer = IGsomNetwork.SpawnLayer.WORLD
	var init_data: Variant = null

#var __peers: Dictionary[StringName, IGsomPeer] = { local_peer.identity: local_peer }

## [readonly] This process' local peer.
##
## The "local" player will spawn for this peer when GameMode starts.
## It starts as "host" when game process starts.
## Connecting to other hosts will re-assign `local_peer.id`, but not `identity`.
var local_peer: GsomPeerImpl = null

## [readonly] Which peer is the host (at process startup - this one).
##
## Connecting to other hosts should re-assign `host_identity`.
var host_identity: StringName = &""

func _init() -> void:
	var instigator: GsomInstigatorImpl = GsomInstigatorImpl.new()
	instigator.net_set_kind(IGsomInstigator.Kind.PLAYER)
	instigator.net_set_label("Player")
	instigator.net_set_identity(GsomUuid.s_uuid())
	
	local_peer = GsomPeerImpl.new()
	local_peer.id = PEER_ID_FIRST
	local_peer.net_set_instigator(instigator)
	
	host_identity = local_peer._get_identity()

var nextId: int = 0
var __events_in: Array[Event] = []
var __events_out: Array[Event] = []

var __gm: IGsomGameMode = null

func _ready() -> void:
	__svc_spawn = SvcSpawn.new()
	GsomModapi.scene.add_child(__svc_spawn)

func _sv_spawn(
	content_id: StringName,
	layer: IGsomNetwork.SpawnLayer = IGsomNetwork.SpawnLayer.WORLD,
	init_data: Variant = null,
	instigator: StringName = &"",
) -> IGsomEntity:
	if !check_is_host():
		return null
	nextId += 1
	var net_id: int = nextId;
	var e: Event = Event.new()
	e.kind = EventKind.SPAWN
	var ev_data: EventDataSpawn = EventDataSpawn.new()
	ev_data.net_id = net_id
	ev_data.instigator = instigator
	ev_data.content_id = content_id
	ev_data.layer = layer
	ev_data.init_data = init_data
	e.data = ev_data
	var ent: IGsomEntity = __shared_spawn(ev_data)
	if !ent:
		return null
	__events_out.append(e)
	return ent

func _sv_despawn(net_id: int) -> void:
	if !check_is_host():
		return
	var e: Event = Event.new()
	e.kind = EventKind.DESPAWN
	e.data = net_id
	__shared_despawn(net_id)
	__events_out.append(e)

func __poll_events() -> void:
	# add __events from network
	pass

# Server only accepts events from peer
func __sv_handle_events() -> void:
	if !check_is_host():
		return
	for e: Event in __events_in:
		if e.kind == EventKind.ENTITY:
			pass
		if e.kind == EventKind.ACTION:
			pass

func __shared_spawn(ev_data: EventDataSpawn) -> IGsomEntity:
	#var gm_id: int = __gm.net_id if __gm else IGsomNetwork.NET_ID_EMPTY
	var ent: IGsomEntity = __svc_spawn.spawn(
		ev_data.net_id, ev_data.content_id, ev_data.layer, ev_data.init_data,
		self,
		ev_data.instigator,
	)
	if !ent:
		return null
	if ent is IGsomGameMode:
		__gm = ent
		gamemode_started.emit()
	
	return ent

func __shared_despawn(net_id: int) -> void:
	if __gm and __gm.net_id == net_id:
		__gm = null
		__svc_spawn.clear()
		gamemode_ended.emit()
	else:
		__svc_spawn.despawn(net_id)

func __cl_handle_events() -> void:
	for e: Event in __events_in:
		if e.kind == EventKind.SPAWN:
			if check_is_host():
				continue # already spawned
			var ev_data: EventDataSpawn = e.data
			__shared_spawn(ev_data)
		if e.kind == EventKind.DESPAWN:
			if check_is_host():
				continue # already despawned
			var net_id: int = e.data
			__shared_despawn(net_id)

func __local_tick(dt: float) -> void:
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		if entity is not IGsomPlayer:
			continue
		var as_player: IGsomPlayer = entity
		if as_player.check_is_local():
			var _actions: Variant = as_player._local_tick(dt)
			break

func __sv_tick(dt: float) -> void:
	if !check_is_host():
		return
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		if entity is not IGsomController:
			continue
		var as_controller: IGsomController = entity
		as_controller._sv_tick(dt)

func __cl_tick(dt: float) -> void:
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		if entity is not IGsomController:
			continue
		var as_controller: IGsomController = entity
		as_controller._cl_tick(dt)

func __flush_events() -> void:
	__events_in = __events_out
	__events_out = []

func _physics_process(dt: float) -> void:
	__local_tick(dt)
	
	__poll_events()
	
	__sv_handle_events()
	__sv_tick(dt)
	
	__cl_handle_events()
	__cl_tick(dt)
	
	__flush_events()

func gamemode_start(content_id: StringName) -> void:
	if !check_is_host() or __gm:
		return
	_sv_spawn(content_id, IGsomNetwork.SpawnLayer.CONTROLLERS)

func gamemode_end() -> void:
	if !check_is_host() or !__gm:
		return
	_sv_despawn(__gm.net_id)


## Clients send this data during connection.
##
## Implementation may include:
## - a pass-phrase,
## - network protocol version,
## - mod versions,
## - etc.
func create_handshake() -> Dictionary:
	assert(false, "Not implemented")
	return {}

## Server checks the incoming handshake data during connection.
##
## Return empty string if the peer is allowed to join.
## Non-empty string will be used to display the disconnection reason.
func validate_handshake(_data: Dictionary) -> String:
	assert(false, "Not implemented")
	return "Validation not implemented."

func _sv_set_attr_int(key: StringName, value: int) -> void:
	var instigator: GsomInstigatorImpl = _get_instigator(key) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_attr_int(key, value)

func _sv_set_attr_bool(key: StringName, value: bool) -> void:
	var instigator: GsomInstigatorImpl = _get_instigator(key) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_attr_bool(key, value)

func _sv_set_attr_string(key: StringName, value: String) -> void:
	var instigator: GsomInstigatorImpl = _get_instigator(key) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_attr_string(key, value)

func _sv_set_attr_float(key: StringName, value: float) -> void:
	var instigator: GsomInstigatorImpl = _get_instigator(key) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_attr_float(key, value)




func get_local_peer() -> IGsomPeer:
	return local_peer

func get_host_identity() -> StringName:
	return host_identity

func check_is_host() -> bool:
	return get_local_identity() == host_identity

func get_local_identity() -> StringName:
	return local_peer._get_identity()

func _cl_send_event(_net_id: int, _e: IGsomEntity.Event) -> void:
	assert(false, "Not implemented")

func _sv_send_event(_net_id: int, _e: IGsomEntity.Event) -> void:
	assert(false, "Not implemented")

func _get_entity(_net_id: int) -> IGsomEntity:
	assert(false, "Not implemented")
	return null

func _get_entities_by_layer(_layer: SpawnLayer) -> Array[IGsomEntity]:
	assert(false, "Not implemented")
	return []

func _get_peer(_identity: StringName) -> IGsomPeer:
	assert(false, "Not implemented")
	return null

func _get_peers_all() -> Array[IGsomPeer]:
	assert(false, "Not implemented")
	return []

func _get_peers_connected() -> Array[IGsomPeer]:
	assert(false, "Not implemented")
	return []

func _sv_register_instigator(
	_identity: StringName,
	_kind: IGsomInstigator.Kind,
	_label: String,
	_content_id: StringName = &"",
) -> IGsomInstigator:
	assert(false, "Not implemented")
	return null

func _get_instigator(_identity: StringName) -> IGsomInstigator:
	assert(false, "Not implemented")
	return null

func _sv_set_instigator_label(
	_identity: StringName,
	_label: String,
) -> void:
	assert(false, "Not implemented")

func _sv_set_instigator_attr_int(
	identity: StringName,
	key: StringName,
	value: int,
) -> void:
	var instigator: GsomInstigatorImpl = _get_instigator(identity) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_attr_int(key, value)

func _sv_set_instigator_attr_bool(
	identity: StringName,
	key: StringName,
	value: bool,
) -> void:
	var instigator: GsomInstigatorImpl = _get_instigator(identity) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_attr_bool(key, value)

func _sv_set_instigator_attr_string(
	identity: StringName,
	key: StringName,
	value: String,
) -> void:
	var instigator: GsomInstigatorImpl = _get_instigator(identity) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_attr_string(key, value)

func _sv_set_instigator_attr_float(
	identity: StringName,
	key: StringName,
	value: float,
) -> void:
	var instigator: GsomInstigatorImpl = _get_instigator(identity) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_attr_float(key, value)

func _sv_set_peer_label(
	identity: StringName,
	label: String,
) -> void:
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if peer:
		peer.net_set_label(label)

func _sv_set_peer_attr_int(
	identity: StringName,
	key: StringName,
	value: int,
) -> void:
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if peer:
		peer.net_set_attr_int(key, value)

func _sv_set_peer_attr_bool(
	identity: StringName,
	key: StringName,
	value: bool,
) -> void:
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if peer:
		peer.net_set_attr_bool(key, value)

func _sv_set_peer_attr_string(
	identity: StringName,
	key: StringName,
	value: String,
) -> void:
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if peer:
		peer.net_set_attr_string(key, value)

func _sv_set_peer_attr_float(
	identity: StringName,
	key: StringName,
	value: float,
) -> void:
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if peer:
		peer.net_set_attr_float(key, value)

func _get_game_mode() -> IGsomGameMode:
	return null

func _get_player(_identity: StringName) -> IGsomPlayer:
	return null

func _get_players() -> Array[IGsomPlayer]:
	return []
