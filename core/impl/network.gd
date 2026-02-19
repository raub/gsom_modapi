extends IGsomNetwork
class_name GsomNetworkImpl

signal gamemode_started()
signal gamemode_ended()

var __svc_spawn: SvcSpawn = null
var __peers: Dictionary[StringName, GsomPeerImpl] = {}
var __instigators: Dictionary[StringName, GsomInstigatorImpl] = {}

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
	__instigators[host_identity] = instigator
	__peers[host_identity] = local_peer

var nextId: int = 0
var __events_in: Array[NetEvent] = []
var __events_out: Array[NetEvent] = []

var __gm: IGsomGameMode = null

func _ready() -> void:
	__svc_spawn = SvcSpawn.new()
	GsomModapi.scene.add_child(__svc_spawn)

func _cl_send_event(net_id: int, event: IGsomEntity.Event) -> void:
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.ENTITY
	var ev_data: EventDataEntity = EventDataEntity.new()
	ev_data.dest_net_id = net_id
	ev_data.payload = event
	__send_net_event(e)

func _sv_send_event(net_id: int, event: IGsomEntity.Event) -> void:
	if !check_is_host():
		return
	_cl_send_event(net_id, event)

func _get_entity(net_id: int) -> IGsomEntity:
	if !__svc_spawn:
		return null
	return __svc_spawn.entities_by_id.get(net_id, null)

func _get_entities_by_layer(_layer: SpawnLayer) -> Array[IGsomEntity]:
	var entities: Array[IGsomEntity] = []
	if !__svc_spawn or !__svc_spawn.entities_by_layer.has(_layer):
		return entities
	for entity: IGsomEntity in __svc_spawn.entities_by_layer[_layer].values():
		entities.append(entity)
	return entities

#region Events

enum EventKind {
	# New entity created (net_id, content_id, transform, data)
	SV_SPAWN,
	# Remove entity by net_id
	SV_DESPAWN,
	# Apply player action from peer
	CL_ACTION,
	# Apply snapshot changes to world objects
	SV_SNAPSHOT,
	# Internal message from entity to entity
	ENTITY,
	# Broadcast peer update
	SV_PEER,
	# Broadcast instigator update
	SV_INSTIGATOR,
	# Declare load epoch
	SV_LOAD,
	# Hint prefetch resources
	SV_PREFETCH,
	# Report load progress to server
	CL_PROGRESS,
}

class NetEvent:
	var identity: StringName = &"" # set this automatically on transport
	var kind: EventKind = EventKind.SV_SNAPSHOT
	var data: Variant = null

class EventDataSpawn:
	var net_id: int = IGsomNetwork.NET_ID_EMPTY
	var instigator: StringName = &""
	var content_id: StringName = &""
	var layer: IGsomNetwork.SpawnLayer = IGsomNetwork.SpawnLayer.WORLD
	var init_data: Variant = null

class EventDataEntity:
	var dest_net_id: int = IGsomNetwork.NET_ID_EMPTY
	var payload: IGsomEntity.Event = null

class EventDataSnapshot:
	var dest_net_id: int = IGsomNetwork.NET_ID_EMPTY
	var payload: Variant = null

class EventDataLoad:
	var epoch_id: int = 0
	var label: String = ""
	var resources: Array[StringName] = []

class EventDataProgress:
	var epoch_id: int = 0
	var progress: float = 0

class EventDataPrefetch:
	var epoch_id: int = 0
	var resources: Array[StringName] = []

func __send_net_event(e: NetEvent) -> void:
	e.identity = get_local_identity()
	__events_out.append(e)

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
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.SV_SPAWN
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
	__send_net_event(e)
	return ent

func _sv_despawn(net_id: int) -> void:
	if !check_is_host():
		return
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.SV_DESPAWN
	e.data = net_id
	__shared_despawn(net_id)
	__send_net_event(e)

func __poll_events() -> void:
	# add __events from network
	pass

func __sv_handle_events() -> void:
	if !check_is_host():
		return
	for e: NetEvent in __events_in:
		if e.kind == EventKind.ENTITY:
			var data: EventDataEntity = e.data
			var ent: IGsomEntity = _get_entity(data.dest_net_id)
			if !ent:
				continue
			var peer: IGsomPeer = _get_peer(e.identity)
			if !peer:
				continue
			var payload: IGsomEntity.Event = data.payload
			if !payload:
				continue
			ent._sv_read_event(peer, payload)
		if e.kind == EventKind.CL_PROGRESS:
			var ev_data: EventDataProgress = e.data
			__shared_progress(_get_peer(e.identity) as GsomPeerImpl, ev_data)

func __sv_handle_actions() -> void:
	if !check_is_host():
		return
	for e: NetEvent in __events_in:
		# Server only accepts actions from other peers
		if !e.identity == get_local_identity():
			continue
		
		if e.kind == EventKind.CL_ACTION:
			var player: IGsomPlayer = _get_player(e.identity)
			if !player:
				continue
			var pawn: IGsomPawn = player._get_pawn()
			if !pawn:
				continue
			pawn._apply_actions(e.data)

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
	for e: NetEvent in __events_in:
		if e.kind == EventKind.SV_SPAWN:
			if check_is_host():
				continue # already spawned
			var ev_data: EventDataSpawn = e.data
			__shared_spawn(ev_data)
		if e.kind == EventKind.SV_DESPAWN:
			if check_is_host():
				continue # already despawned
			var net_id: int = e.data
			__shared_despawn(net_id)
		if e.kind == EventKind.SV_LOAD:
			if check_is_host():
				continue # host has already entered this load epoch
			var load_data: EventDataLoad = e.data
			__shared_load(load_data)
		if e.kind == EventKind.SV_PREFETCH:
			if check_is_host():
				continue # host has already performed the prefetch
			var prefetch_data: EventDataPrefetch = e.data
			__shared_prefetch(prefetch_data)
		if e.kind == EventKind.SV_SNAPSHOT:
			if check_is_host():
				continue
			var snapshots: Array[EventDataSnapshot] = e.data
			for item: EventDataSnapshot in snapshots:
				var ent: IGsomEntity = _get_entity(item.dest_net_id)
				if !ent:
					continue
				ent._cl_unpack(item.payload)
		if e.kind == EventKind.ENTITY:
			var data: Dictionary = e.data
			if data.get("to_server", true):
				continue
			var net_id: int = data.get("net_id", NET_ID_EMPTY)
			var ent: IGsomEntity = _get_entity(net_id)
			if !ent:
				continue
			var payload: IGsomEntity.Event = data.get("event", null)
			if !payload:
				continue
			ent._cl_read_event(payload)

#endregion

#region Tick

func __local_tick(dt: float) -> void:
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		if entity is not IGsomPlayer:
			continue
		var as_player: IGsomPlayer = entity
		if as_player.check_is_local():
			var actions: Variant = as_player._local_tick(dt)
			var e: NetEvent = NetEvent.new()
			e.kind = EventKind.CL_ACTION
			e.data = actions
			__send_net_event(e)
			
			var pawn: IGsomPawn = as_player._get_pawn()
			if pawn:
				pawn._apply_actions(e.data)
			
			break

func __sv_tick(dt: float) -> void:
	if !check_is_host():
		return
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		entity._sv_tick(dt)
	var snapshots: Array[EventDataSnapshot] = []
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		var snapshot: Variant = entity._sv_pack(IGsomEntity.RelevancyLod.MAX)
		if snapshot == null:
			continue
		var ev_data: EventDataSnapshot = EventDataSnapshot.new()
		ev_data.dest_net_id = entity.net_id
		ev_data.payload = snapshot
	if snapshots.is_empty():
		return
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.SV_SNAPSHOT
	e.data = snapshots
	__send_net_event(e)

func __cl_tick(dt: float) -> void:
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		entity._cl_tick(dt)

func __flush_events() -> void:
	__events_in = __events_out
	__events_out = []

func _physics_process(dt: float) -> void:
	__poll_events()
	
	__sv_handle_events()
	__sv_handle_actions()
	__sv_tick(dt)
	
	__local_tick(dt)
	
	__cl_handle_events()
	__cl_tick(dt)
	
	__flush_events()

#endregion

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

#region Instigator

func _sv_register_instigator(
	_identity: StringName,
	_kind: IGsomInstigator.Kind,
	_label: String,
	_content_id: StringName = &"",
) -> IGsomInstigator:
	if !check_is_host():
		return null
	var instigator: GsomInstigatorImpl = GsomInstigatorImpl.new()
	instigator.net_set_identity(_identity)
	instigator.net_set_kind(_kind)
	instigator.net_set_label(_label)
	if _content_id != &"":
		instigator.net_set_attr_string(&"content_id", String(_content_id))
	__instigators[_identity] = instigator
	return instigator

func _get_instigator(_identity: StringName) -> IGsomInstigator:
	return __instigators.get(_identity, null)

func _sv_set_instigator_label(
	_identity: StringName,
	_label: String,
) -> void:
	if !check_is_host():
		return
	var instigator: GsomInstigatorImpl = _get_instigator(_identity) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_label(_label)

func _sv_set_instigator_attr_int(
	identity: StringName,
	key: StringName,
	value: int,
) -> void:
	if !check_is_host():
		return
	var instigator: GsomInstigatorImpl = _get_instigator(identity) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_attr_int(key, value)

func _sv_set_instigator_attr_bool(
	identity: StringName,
	key: StringName,
	value: bool,
) -> void:
	if !check_is_host():
		return
	var instigator: GsomInstigatorImpl = _get_instigator(identity) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_attr_bool(key, value)

func _sv_set_instigator_attr_string(
	identity: StringName,
	key: StringName,
	value: String,
) -> void:
	if !check_is_host():
		return
	var instigator: GsomInstigatorImpl = _get_instigator(identity) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_attr_string(key, value)

func _sv_set_instigator_attr_float(
	identity: StringName,
	key: StringName,
	value: float,
) -> void:
	if !check_is_host():
		return
	var instigator: GsomInstigatorImpl = _get_instigator(identity) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_attr_float(key, value)

#endregion

#region Peer

func get_local_peer() -> IGsomPeer:
	return local_peer

func get_host_identity() -> StringName:
	return host_identity

func check_is_host() -> bool:
	return get_local_identity() == host_identity

func get_local_identity() -> StringName:
	return local_peer._get_identity()

func _get_peer(_identity: StringName) -> IGsomPeer:
	return __peers.get(_identity, null)

func _get_peers_all() -> Array[IGsomPeer]:
	var peers: Array[IGsomPeer] = []
	for peer: GsomPeerImpl in __peers.values():
		peers.append(peer)
	return peers

func _get_peers_connected() -> Array[IGsomPeer]:
	var peers: Array[IGsomPeer] = []
	for peer: GsomPeerImpl in __peers.values():
		if peer._get_connected():
			peers.append(peer)
	return peers

func _sv_set_peer_connected(identity: StringName, connected: bool) -> void:
	if !check_is_host():
		return
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if !peer:
		return
	if peer._get_connected() == connected:
		return
	peer.net_set_connected(connected)
	__sv_dispatch_peer_update(peer)

func _sv_set_peer_label(
	identity: StringName,
	label: String,
) -> void:
	if !check_is_host():
		return
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if !peer:
		return
	peer.net_set_label(label)
	__sv_dispatch_peer_update(peer)

func _sv_set_peer_attr_int(
	identity: StringName,
	key: StringName,
	value: int,
) -> void:
	if !check_is_host():
		return
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if !peer:
		return
	peer.net_set_attr_int(key, value)
	__sv_dispatch_peer_update(peer)

func _sv_set_peer_attr_bool(
	identity: StringName,
	key: StringName,
	value: bool,
) -> void:
	if !check_is_host():
		return
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if !peer:
		return
	peer.net_set_attr_bool(key, value)
	__sv_dispatch_peer_update(peer)

func _sv_set_peer_attr_string(
	identity: StringName,
	key: StringName,
	value: String,
) -> void:
	if !check_is_host():
		return
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if !peer:
		return
	peer.net_set_attr_string(key, value)
	__sv_dispatch_peer_update(peer)

func _sv_set_peer_attr_float(
	identity: StringName,
	key: StringName,
	value: float,
) -> void:
	if !check_is_host():
		return
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if !peer:
		return
	peer.net_set_attr_float(key, value)
	__sv_dispatch_peer_update(peer)

func _get_game_mode() -> IGsomGameMode:
	return __gm

func _get_player(_identity: StringName) -> IGsomPlayer:
	for player: IGsomPlayer in _get_players():
		if player.peer_identity == _identity:
			return player
	return null

func _get_players() -> Array[IGsomPlayer]:
	var players: Array[IGsomPlayer] = []
	if !__svc_spawn:
		return players
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		if entity is IGsomPlayer:
			players.append(entity as IGsomPlayer)
	return players

func __sv_dispatch_peer_join(peer: IGsomPeer) -> void:
	if !check_is_host():
		return
	if __gm:
		__gm._sv_peer_join(peer)
	__sv_dispatch_player_peer_update(peer)

func __sv_dispatch_peer_drop(peer: IGsomPeer) -> void:
	if !check_is_host():
		return
	if __gm:
		__gm._sv_peer_drop(peer)
	__sv_dispatch_player_peer_update(peer)

func __sv_dispatch_peer_update(peer: IGsomPeer) -> void:
	if !check_is_host():
		return
	if __gm:
		__gm._sv_peer_update(peer)
	__sv_dispatch_player_peer_update(peer)

func __sv_dispatch_player_peer_update(peer: IGsomPeer) -> void:
	var peer_identity: StringName = peer._get_identity()
	for player: IGsomPlayer in _get_players():
		if player.peer_identity != peer_identity:
			continue
		player._sv_peer_update(peer)

#endregion

#region Load

class LoadEpoch:
	var epoch_id: int = 0
	var label: String = ""
	var resources: Dictionary[StringName, Resource] = {}

var __load_epoch: LoadEpoch = LoadEpoch.new()
var __load_epoch_next: LoadEpoch = null
var __load_prefetch: Dictionary[StringName, Resource] = {}

func _sv_load_start(label: String, resources: Array[StringName]) -> void:
	if !check_is_host():
		return
	if __gm:
		__gm._sv_load_start(label)
	
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.SV_LOAD
	var ev_data: EventDataLoad = EventDataLoad.new()
	ev_data.epoch_id = __load_epoch.epoch_id + 1
	ev_data.label = label
	ev_data.resources = resources.duplicate()
	e.data = ev_data
	__shared_load(ev_data)
	__send_net_event(e)

func __shared_load(ev_data: EventDataLoad) -> void:
	__load_epoch_next = LoadEpoch.new()
	__load_epoch_next.epoch_id = ev_data.epoch_id
	__load_epoch_next.label = ev_data.label
	
	for peer: GsomPeerImpl in __peers.values():
		peer.net_set_load_epoch(ev_data.epoch_id)
		peer.net_set_load_progress(0.0)
	
	for path: StringName in ev_data.resources:
		if __load_epoch.resources.has(path):
			__load_epoch_next.resources[path] = __load_epoch.resources[path]
		elif __load_prefetch.has(path):
			__load_epoch_next.resources[path] = __load_prefetch[path]
		else:
			__load_epoch_next.resources[path] = null
	
	for path: StringName in ev_data.resources:
		__load_into_epoch.call_deferred(ev_data.epoch_id, path)
	
	# This cache only applies until next load epoch begins.
	__load_prefetch.clear()
	
	if ev_data.resources.is_empty():
		if __gm:
			__gm._cl_load_complete()
		else:
			_cl_load_complete()

func __shared_progress(peer: GsomPeerImpl, ev_data: EventDataProgress) -> void:
	if peer._get_load_epoch() != ev_data.epoch_id:
		return
	peer.net_set_load_progress(clampf(ev_data.progress, 0.0, 1.0))

func __commit_load_epoch(epoch_id: int) -> void:
	if __load_epoch_next and __load_epoch_next.epoch_id == epoch_id:
		__load_epoch = __load_epoch_next
		__load_epoch_next = null

func __load_into_epoch(epoch_id: int, path: StringName) -> void:
	if !__load_epoch_next or __load_epoch_next.epoch_id != epoch_id:
		return
	if !__load_epoch_next.resources.has(path):
		return
	if __load_epoch_next.resources[path] == null:
		__load_epoch_next.resources[path] = load(path)
	
	var count_total: float = float(__load_epoch_next.resources.size())
	if count_total <= 0.0:
		if __gm:
			__gm._cl_load_complete()
		else:
			_cl_load_complete()
		return
	var count_loaded: float = 0.0
	for rc: Resource in __load_epoch_next.resources.values():
		if rc:
			count_loaded += 1.0
	var progress: float = count_loaded / count_total
	
	if progress >= 1.0:
		if __gm:
			__gm._cl_load_complete()
		else:
			_cl_load_complete()
		return
	
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.CL_PROGRESS
	var ev_data: EventDataProgress = EventDataProgress.new()
	ev_data.epoch_id = epoch_id
	ev_data.progress = minf(progress, 0.99)
	e.data = ev_data
	__shared_progress(get_local_peer() as GsomPeerImpl, ev_data)
	__send_net_event(e)

func __load_into_prefetch(path: StringName) -> void:
	var res: Resource = load(path)
	__load_prefetch[path] = res
	prints("Precached:", path, Time.get_ticks_usec())

func __shared_prefetch(ev_data: EventDataPrefetch) -> void:
	if __load_epoch_next:
		return
	if __load_epoch.epoch_id + 1 != ev_data.epoch_id:
		return
	
	for path: StringName in ev_data.resources:
		if !__load_epoch.resources.has(path) and !__load_prefetch.has(path):
			__load_into_prefetch(path)

func _sv_load_prefetch(resources: Array[StringName]) -> void:
	if !check_is_host():
		return
	
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.SV_PREFETCH
	var ev_data: EventDataPrefetch = EventDataPrefetch.new()
	ev_data.epoch_id = __load_epoch.epoch_id + 1
	ev_data.resources = resources.duplicate()
	e.data = ev_data
	__shared_prefetch(ev_data)
	__send_net_event(e)

func _cl_load_complete() -> void:
	var epoch_id: int = __load_epoch_next.epoch_id if __load_epoch_next else __load_epoch.epoch_id
	if epoch_id <= 0:
		return
	var local: GsomPeerImpl = get_local_peer() as GsomPeerImpl
	if local._get_load_epoch() == epoch_id and local._get_load_progress() >= 1.0:
		return
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.CL_PROGRESS
	var ev_data: EventDataProgress = EventDataProgress.new()
	ev_data.epoch_id = epoch_id
	ev_data.progress = 1
	e.data = ev_data
	__shared_progress(local, ev_data)
	__send_net_event(e)
	__commit_load_epoch(epoch_id)

#endregion
