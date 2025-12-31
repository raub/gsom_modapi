extends Node
class_name SvcNetwork

const __SvcSpawn: PackedScene = preload("./spawn.tscn")

signal gamemode_started()
signal gamemode_ended()

enum EventKind {
	NONE, # no-op
	GAME, # global changes: game start/end, transitions.
	PLAYER, # players’ status/state.
	SPAWN, # new entity created (id, content_id, transform, data).
	DESPAWN, # remove entity by id.
	ADJUST, # apply delta changes to world objects.
	MESSAGE, # text/voice/ping message from a player.
	TRANSACTION, # item picked/dropped
	INTERACTION, # door opened, switch flipped.
}

var __svc_spawn: SvcSpawn = null
var lobby: Lobby = Lobby.new()
var local_player: Player = Player.new()

class Player:
	var id: int = 0
	var name: String = "Player"
	var host: bool = false

class Lobby:
	var players: Array[Player] = []

class Event:
	var kind: EventKind = EventKind.NONE
	var data: Variant = null

class EventDataSpawn:
	var id: int = 0
	var content_id: StringName = &""
	var layer: StringName = &""
	var data: Variant = null
	var payload: Variant = null

var autority: bool = true
var nextId: int = 0
var __events: Array[Event] = []

var __gm: IGameMode = null

func _ready() -> void:
	__svc_spawn = __SvcSpawn.instantiate()
	GsomModapi.scene.add_child(__svc_spawn)
	
	local_player.id = 1
	local_player.host = true
	local_player.name = "Host"
	lobby.players.append(local_player)

func spawn(content_id: StringName, layer: StringName, data: Variant = null) -> void:
	if !autority:
		return
	nextId += 1
	var id: int = nextId;
	var e: Event = Event.new()
	e.kind = EventKind.SPAWN
	var ev_data: EventDataSpawn = EventDataSpawn.new()
	ev_data.id = id
	ev_data.content_id = content_id
	ev_data.layer = layer
	ev_data.data = data
	e.data = ev_data
	__events.append(e)

func despawn(id: StringName) -> void:
	if !autority:
		return
	var e: Event = Event.new()
	e.kind = EventKind.DESPAWN
	e.data = id
	__events.append(e)

func __poll_events() -> void:
	# add __events from network
	pass

func __sv_handle_events() -> void:
	if !autority:
		return
	for e: Event in __events:
		if e.kind == EventKind.PLAYER:
			pass

func __cl_handle_events() -> void:
	for e: Event in __events:
		if e.kind == EventKind.SPAWN:
			var ev_data: EventDataSpawn = e.data
			var ent: SvcSpawn.Entity = __svc_spawn.spawn(
				ev_data.id, ev_data.content_id, ev_data.layer, ev_data.data, ev_data.payload,
			)
			if ent and ent.node is IGameMode:
				__gm = ent.node as IGameMode
				__gm.final_closed.connect(__gamemode_end)
				gamemode_started.emit()
		if e.kind == EventKind.DESPAWN:
			var ev_data: int = e.data
			__svc_spawn.despawn(ev_data)
		if e.kind == EventKind.GAME:
			var ev_data: String = e.data
			if ev_data == "game_over":
				__svc_spawn.clear()
				gamemode_ended.emit()

func __sv_tick(dt: float) -> void:
	if !autority:
		return
	if __gm:
		__gm._sv_tick(dt)

func __cl_tick(dt: float) -> void:
	if __gm:
		__gm._cl_tick(dt)

func __flush_events() -> void:
	__events = []

func _physics_process(dt: float) -> void:
	__poll_events()
	
	__sv_handle_events()
	__sv_tick(dt)
	
	__cl_handle_events()
	__cl_tick(dt)
	
	__flush_events()

func gamemode_start(content_id: StringName) -> void:
	spawn(content_id, &"controller")

func __gamemode_end() -> void:
	if !autority:
		return
	var e: Event = Event.new()
	e.kind = EventKind.GAME
	e.data = "game_over"
	__events.append(e)
