extends INetwork
class_name SvcNetwork

const __SvcSpawn := preload("./spawn.gd")

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
	var net_id: int = 0
	var content_id: StringName = &""
	var layer: StringName = &""
	var data: Variant = null

var nextId: int = 0
var __events_in: Array[Event] = []
var __events_out: Array[Event] = []

var __gm: IGameMode = null

func _ready() -> void:
	__svc_spawn = __SvcSpawn.new()
	GsomModapi.scene.add_child(__svc_spawn)

func _spawn(content_id: StringName, layer: StringName, data: Variant = null) -> void:
	if !authority:
		return
	nextId += 1
	var net_id: int = nextId;
	var e: Event = Event.new()
	e.kind = EventKind.SPAWN
	var ev_data: EventDataSpawn = EventDataSpawn.new()
	ev_data.net_id = net_id
	ev_data.content_id = content_id
	ev_data.layer = layer
	ev_data.data = data
	e.data = ev_data
	__events_out.append(e)

func _despawn(net_id: int) -> void:
	if !authority:
		return
	var e: Event = Event.new()
	e.kind = EventKind.DESPAWN
	e.data = net_id
	__events_out.append(e)

func __poll_events() -> void:
	# add __events from network
	pass

# Server only accepts events from peer
func __sv_handle_events() -> void:
	if !authority:
		return
	for e: Event in __events_in:
		if e.kind == EventKind.ENTITY:
			pass
		if e.kind == EventKind.ACTION:
			pass

func __cl_handle_events() -> void:
	for e: Event in __events_in:
		if e.kind == EventKind.SPAWN:
			var ev_data: EventDataSpawn = e.data
			var ent: IReplicator = __svc_spawn.spawn(
				ev_data.net_id, ev_data.content_id, ev_data.layer, ev_data.data,
			)
			if !ent:
				continue
			
			ent.net = self
			if ent is IGameMode:
				__gm = ent
				gamemode_started.emit()
			if __gm:
				ent.instigator_id = __gm.net_id
		if e.kind == EventKind.DESPAWN:
			var net_id: int = e.data
			if __gm and __gm.net_id == net_id:
				__gm = null
				__svc_spawn.clear()
				gamemode_ended.emit()
			else:
				__svc_spawn.despawn(net_id)

func __local_tick(dt: float) -> void:
	for entity: IReplicator in __svc_spawn.spawned.values():
		if entity is not IPlayer:
			continue
		var as_player: IPlayer = entity
		if as_player.is_local:
			var _actions: Variant = as_player._local_tick(dt)
			break

func __sv_tick(dt: float) -> void:
	if !authority:
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
	if !authority or __gm:
		return
	_spawn(content_id, &"controller")

func gamemode_end() -> void:
	if !authority or !__gm:
		return
	_despawn(__gm.net_id)
