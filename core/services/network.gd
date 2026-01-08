extends INetwork
class_name SvcNetwork

signal gamemode_started()
signal gamemode_ended()

enum EventKind {
	# New entity created (net_id, content_id, transform, data)
	SPAWN,
	# Remove entity by net_id
	DESPAWN,
	# Apply player action from peer
	ACTION,
	# Apply delta changes to world objects
	ADJUST,
	# Internal message from an entity to itself
	ENTITY,
}

var __svc_spawn: SvcSpawn = null

class Event:
	var kind: EventKind = EventKind.ADJUST
	var data: Variant = {}

class EventDataSpawn:
	var net_id: int = INetwork.NET_ID_EMPTY
	var instigator_key: StringName = &""
	var content_id: StringName = &""
	var layer: INetwork.SpawnLayer = INetwork.SpawnLayer.WORLD
	var init_data: Variant = null

#var __peers: Dictionary[StringName, IPeer] = { local_peer.identity: local_peer }

## [readonly] This process' local peer.
##
## The "local" player will spawn for this peer when GameMode starts.
## It starts as "host" when game process starts.
## Connecting to other hosts will re-assign `local_peer.id`, but not `identity`.
var local_peer: IPeer = null

## [readonly] Which peer is the host (at process startup - this one).
##
## Connecting to other hosts should re-assign `host_identity`.
var host_identity: StringName = &""

var __uuid_rng: RandomNumberGenerator = null

## Provides for a somewhat-unique identity (e.g. for default `peer.identity`)
##
## Example: "1767603574.422-1450022-813288388"
func __uuid() -> StringName:
	if !__uuid_rng:
		__uuid_rng = RandomNumberGenerator.new()
		__uuid_rng.randomize()
	var u: StringName = "%s-%s-%s" % [
		Time.get_unix_time_from_system(), Time.get_ticks_usec(), __uuid_rng.randi()
	]
	return u

func _init() -> void:
	local_peer = IPeer.new()
	local_peer.id = PEER_ID_FIRST
	local_peer.identity = __uuid()
	
	host_identity = local_peer.identity

var nextId: int = 0
var __events_in: Array[Event] = []
var __events_out: Array[Event] = []

var __gm: IGameMode = null

func _ready() -> void:
	__svc_spawn = SvcSpawn.new()
	GsomModapi.scene.add_child(__svc_spawn)

func _spawn(
	content_id: StringName,
	layer: INetwork.SpawnLayer = INetwork.SpawnLayer.WORLD,
	init_data: Variant = null,
	instigator_key: StringName = &"",
) -> IReplicator:
	if !check_is_host():
		return null
	nextId += 1
	var net_id: int = nextId;
	var e: Event = Event.new()
	e.kind = EventKind.SPAWN
	var ev_data: EventDataSpawn = EventDataSpawn.new()
	ev_data.net_id = net_id
	ev_data.instigator_key = instigator_key
	ev_data.content_id = content_id
	ev_data.layer = layer
	ev_data.init_data = init_data
	e.data = ev_data
	var ent: IReplicator = __shared_spawn(ev_data)
	if !ent:
		return null
	__events_out.append(e)
	return ent

func _despawn(net_id: int) -> void:
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

func __shared_spawn(ev_data: EventDataSpawn) -> IReplicator:
	#var gm_id: int = __gm.net_id if __gm else INetwork.NET_ID_EMPTY
	var ent: IReplicator = __svc_spawn.spawn(
		ev_data.net_id, ev_data.content_id, ev_data.layer, ev_data.init_data,
		self,
		ev_data.instigator_key,
	)
	if !ent:
		return null
	if ent is IGameMode:
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
	for entity: IReplicator in __svc_spawn.spawned.values():
		if entity is not IPlayer:
			continue
		var as_player: IPlayer = entity
		if as_player.is_local:
			var _actions: Variant = as_player._local_tick(dt)
			break

func __sv_tick(dt: float) -> void:
	if !check_is_host():
		return
	for entity: IReplicator in __svc_spawn.spawned.values():
		if entity is not IController:
			continue
		var as_controller: IController = entity
		as_controller._sv_tick(dt)

func __cl_tick(dt: float) -> void:
	for entity: IReplicator in __svc_spawn.spawned.values():
		if entity is not IController:
			continue
		var as_controller: IController = entity
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
	_spawn(content_id, INetwork.SpawnLayer.CONTROLLERS)

func gamemode_end() -> void:
	if !check_is_host() or !__gm:
		return
	_despawn(__gm.net_id)


## Clients send this data during connection.
##
## Implementation may include:
## - a pass-phrase,
## - network protocol version,
## - mod versions,
## - etc.
func _create_handshake() -> Dictionary:
	assert(false, "Not implemented")
	return {}

## Server checks the incoming handshake data during connection.
##
## Return empty string if the peer is allowed to join.
## Non-empty string will be used to display the disconnection reason.
func _validate_handshake(_data: Dictionary) -> String:
	assert(false, "Not implemented")
	return "Validation not implemented."
