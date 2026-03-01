extends IGsomNetwork
class_name GsomNetworkImpl

const __LocalTransport := preload("res://core/impl/net/local_transport.gd")
const __ProtocolVersion: int = 1
const __AutoJoinRetryS: float = 1.0
const __TraceEnabled: bool = false

signal gamemode_started()
signal gamemode_ended()

var __svc_spawn: SvcSpawn = null
var __peers: Dictionary[StringName, GsomPeerImpl] = {}
var __instigators: Dictionary[StringName, GsomInstigatorImpl] = {}
var __transport: GsomLocalTransport = null
var __transport_packets: Array[Dictionary] = []
var __transport_events_in: Array[NetEvent] = []
var __loopback_events_next: Array[NetEvent] = []
var __transport_peer_identity: Dictionary[int, StringName] = {}
var __transport_identity_peer: Dictionary[StringName, int] = {}
var __next_peer_id: int = PEER_ID_FIRST
var __auto_join_elapsed_s: float = 0.0
var __auto_join_enabled: bool = true
var __cl_resync_elapsed_s: float = 0.0

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
	instigator.net = self
	instigator.net_set_kind(IGsomInstigator.Kind.PLAYER)
	instigator.net_set_label("Player")
	instigator.net_set_identity(GsomUuid.s_uuid())
	
	local_peer = GsomPeerImpl.new()
	local_peer.net = self
	local_peer.id = PEER_ID_FIRST
	local_peer.net_set_instigator(instigator)
	
	host_identity = local_peer._get_identity()
	__instigators[host_identity] = instigator
	__peers[host_identity] = local_peer
	__next_peer_id = PEER_ID_FIRST

var nextId: int = 0
var __events_in: Array[NetEvent] = []
var __events_out: Array[NetEvent] = []

var __gm: IGsomGameMode = null

func _ready() -> void:
	__svc_spawn = SvcSpawn.new()
	GsomModapi.scene.add_child(__svc_spawn)
	__trace("_ready: spawn service initialized")
	__init_local_transport()

func _cl_send_event(net_id: int, event: IGsomEntity.Event) -> void:
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.ENTITY
	e.data = {
		"to_server": true,
		"net_id": net_id,
		"event": event,
	}
	__send_net_event(e)

func _sv_send_event(net_id: int, event: IGsomEntity.Event) -> void:
	if !check_is_host():
		return
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.ENTITY
	e.data = {
		"to_server": false,
		"net_id": net_id,
		"event": event,
	}
	__send_net_event(e)

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
	# Ask server to re-emit local peer-driven entities/state
	CL_RESYNC,
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

class EventDataPeer:
	var state: Dictionary = {}

class EventDataInstigator:
	var state: Dictionary = {}

func __trace(message: String, extra: Variant = null) -> void:
	if !__TraceEnabled:
		return
	var role: String = "SV" if check_is_host() else "CL"
	var pid: int = OS.get_process_id()
	prints("#%d" % pid, "[NET]", role, message, extra)

func __event_kind_name(kind: EventKind) -> String:
	match kind:
		EventKind.SV_SPAWN:
			return "SV_SPAWN"
		EventKind.SV_DESPAWN:
			return "SV_DESPAWN"
		EventKind.CL_ACTION:
			return "CL_ACTION"
		EventKind.SV_SNAPSHOT:
			return "SV_SNAPSHOT"
		EventKind.ENTITY:
			return "ENTITY"
		EventKind.SV_PEER:
			return "SV_PEER"
		EventKind.SV_INSTIGATOR:
			return "SV_INSTIGATOR"
		EventKind.SV_LOAD:
			return "SV_LOAD"
		EventKind.SV_PREFETCH:
			return "SV_PREFETCH"
		EventKind.CL_PROGRESS:
			return "CL_PROGRESS"
		EventKind.CL_RESYNC:
			return "CL_RESYNC"
	return "UNKNOWN"

func __should_trace_event(kind: EventKind) -> bool:
	if kind == EventKind.SV_LOAD:
		return true
	if kind == EventKind.SV_SPAWN:
		return true
	if kind == EventKind.SV_DESPAWN:
		return true
	if kind == EventKind.SV_PREFETCH:
		return true
	if kind == EventKind.CL_RESYNC:
		return true
	return false

func __count_traceable_events(events: Array[NetEvent]) -> int:
	var count: int = 0
	for e: NetEvent in events:
		if __should_trace_event(e.kind):
			count += 1
	return count

func __count_kind(events: Array[NetEvent], kind: EventKind) -> int:
	var count: int = 0
	for e: NetEvent in events:
		if e.kind == kind:
			count += 1
	return count

func __summarize_packet_events(events: Array[NetEvent]) -> String:
	return (
		"total=%d CL_PROGRESS=%d CL_RESYNC=%d CL_ACTION=%d SV_LOAD=%d SV_SPAWN=%d SV_SNAPSHOT=%d"
		% [
			events.size(),
			__count_kind(events, EventKind.CL_PROGRESS),
			__count_kind(events, EventKind.CL_RESYNC),
			__count_kind(events, EventKind.CL_ACTION),
			__count_kind(events, EventKind.SV_LOAD),
			__count_kind(events, EventKind.SV_SPAWN),
			__count_kind(events, EventKind.SV_SNAPSHOT),
		]
	)

func __should_trace_packet_summary(events: Array[NetEvent]) -> bool:
	for event: NetEvent in events:
		if event.kind == EventKind.CL_PROGRESS:
			return true
		if event.kind == EventKind.CL_RESYNC:
			return true
		if event.kind == EventKind.SV_LOAD:
			return true
		if event.kind == EventKind.SV_SPAWN:
			return true
		if event.kind == EventKind.SV_DESPAWN:
			return true
	return false

func __trace_event(stage: String, event: NetEvent) -> void:
	if !__should_trace_event(event.kind):
		return
	__trace(
		"%s event=%s from=%s"
		% [stage, __event_kind_name(event.kind), String(event.identity)]
	)

func __send_net_event(e: NetEvent) -> void:
	e.identity = get_local_identity()
	__events_out.append(e)
	__trace_event("enqueue_out", e)

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

func __poll_events(dt: float) -> void:
	if __transport:
		__transport.tick(dt)
	__consume_transport_packets()
	__events_in = __loopback_events_next
	__loopback_events_next = []
	if !__transport_events_in.is_empty():
		__events_in.append_array(__transport_events_in)
		__transport_events_in.clear()
	if !__events_in.is_empty():
		var traceable_count: int = __count_traceable_events(__events_in)
		if traceable_count > 0:
			__trace("__poll_events in_count=%d traceable=%d" % [__events_in.size(), traceable_count])

func __sv_handle_events() -> void:
	if !check_is_host():
		return
	for e: NetEvent in __events_in:
		__trace_event("sv_handle", e)
		if e.kind == EventKind.ENTITY:
			var data: Dictionary = e.data
			if !data.get("to_server", true):
				continue
			var net_id: int = data.get("net_id", NET_ID_EMPTY)
			var ent: IGsomEntity = _get_entity(net_id)
			if !ent:
				continue
			var peer: IGsomPeer = _get_peer(e.identity)
			if !peer:
				continue
			var payload: IGsomEntity.Event = data.get("event", null)
			if !payload:
				continue
			ent._sv_read_event(peer, payload)
		if e.kind == EventKind.CL_PROGRESS:
			var ev_data: EventDataProgress = e.data
			var peer_progress: GsomPeerImpl = _get_peer(e.identity) as GsomPeerImpl
			if peer_progress:
				if ev_data.progress <= 0.0 or ev_data.progress >= 1.0:
					__trace(
						"sv_handle CL_PROGRESS peer=%s epoch=%d progress=%.3f"
						% [String(e.identity), ev_data.epoch_id, ev_data.progress]
					)
				__shared_progress(peer_progress, ev_data)
		if e.kind == EventKind.CL_RESYNC:
			var peer_sync: GsomPeerImpl = _get_peer(e.identity) as GsomPeerImpl
			if peer_sync:
				__trace("sv_handle CL_RESYNC re-dispatch peer update for %s" % String(e.identity))
				__sv_dispatch_peer_update(peer_sync)

func __sv_handle_actions() -> void:
	if !check_is_host():
		return
	for e: NetEvent in __events_in:
		if e.kind != EventKind.CL_ACTION:
			continue
		# Server only accepts actions from other peers
		if e.identity == get_local_identity():
			continue
		var player: IGsomPlayer = _get_player(e.identity)
		if !player:
			continue
		player._sv_apply_actions(e.data)

func __shared_spawn(ev_data: EventDataSpawn) -> IGsomEntity:
	var existing: IGsomEntity = _get_entity(ev_data.net_id)
	if existing:
		__trace(
			"__shared_spawn skip existing net_id=%d content=%s"
			% [ev_data.net_id, String(ev_data.content_id)]
		)
		return existing
	#var gm_id: int = __gm.net_id if __gm else IGsomNetwork.NET_ID_EMPTY
	var ent: IGsomEntity = __svc_spawn.spawn(
		ev_data.net_id, ev_data.content_id, ev_data.layer, ev_data.init_data,
		self,
		ev_data.instigator,
	)
	if !ent:
		__trace(
			"__shared_spawn failed net_id=%d content=%s layer=%d"
			% [ev_data.net_id, String(ev_data.content_id), int(ev_data.layer)]
		)
		return null
	__trace(
		"__shared_spawn ok net_id=%d content=%s layer=%d instigator=%s"
		% [ev_data.net_id, String(ev_data.content_id), int(ev_data.layer), String(ev_data.instigator)]
	)
	if ent is IGsomGameMode:
		__gm = ent
		__trace("gamemode_started net_id=%d content=%s" % [ent.net_id, String(ent.content_id)])
		gamemode_started.emit()
	
	return ent

func __shared_despawn(net_id: int) -> void:
	__trace("__shared_despawn net_id=%d" % net_id)
	if __gm and __gm.net_id == net_id:
		__gm = null
		__svc_spawn.clear()
		__trace("gamemode_ended net_id=%d" % net_id)
		gamemode_ended.emit()
	else:
		__svc_spawn.despawn(net_id)

func __cl_handle_events() -> void:
	for e: NetEvent in __events_in:
		__trace_event("cl_handle", e)
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
		if e.kind == EventKind.SV_INSTIGATOR:
			if check_is_host():
				continue
			var inst_data: EventDataInstigator = e.data
			__cl_apply_instigator_state(inst_data.state)
		if e.kind == EventKind.SV_PEER:
			if check_is_host():
				continue
			var peer_data: EventDataPeer = e.data
			__cl_apply_peer_state(peer_data.state)
		if e.kind == EventKind.SV_SNAPSHOT:
			if check_is_host():
				continue
			var snapshots: Array[EventDataSnapshot] = e.data
			for item: EventDataSnapshot in snapshots:
				var ent: IGsomEntity = _get_entity(item.dest_net_id)
				if !ent:
					continue
				ent._read_snapshot(item.payload)
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

#region Transport

func __init_local_transport() -> void:
	__transport = __LocalTransport.new()
	GsomModapi.scene.add_child(__transport)
	__transport.configure_identity(get_local_identity())
	__transport.packet_received.connect(__on_transport_packet)
	__transport.peer_connected.connect(__on_transport_peer_connected)
	__transport.peer_disconnected.connect(__on_transport_peer_disconnected)
	__transport.connected_to_server.connect(__on_transport_connected_to_server)
	__transport.connection_failed.connect(__on_transport_connection_failed)
	__transport.server_disconnected.connect(__on_transport_server_disconnected)
	var host_started: bool = __transport.start_host()
	if !host_started:
		push_error("Failed to start local host transport.")
		__trace("__init_local_transport failed to start host transport")
		return
	__trace("__init_local_transport host_port=%d" % __transport.get_host_port())
	__transport.begin_discovery()
	__read_network_cmd_args()

func __read_network_cmd_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--gsom-net-no-auto-join":
			__auto_join_enabled = false
			__trace("cmd arg: disabled auto join")

func __on_transport_packet(peer_id: int, payload: Dictionary) -> void:
	var packet: Dictionary = payload.duplicate(true)
	packet["__peer_id"] = peer_id
	__transport_packets.append(packet)
	var packet_type: String = packet.get("type", "")
	if packet_type != "events":
		__trace("transport packet queued type=%s peer_id=%d" % [packet_type, peer_id])

func __on_transport_peer_connected(_peer_id: int) -> void:
	__trace("transport peer_connected peer_id=%d" % _peer_id)

func __on_transport_peer_disconnected(peer_id: int) -> void:
	__trace("transport peer_disconnected peer_id=%d" % peer_id)
	var identity: StringName = __transport_peer_identity.get(peer_id, &"")
	if identity == &"":
		__trace("transport peer_disconnected unknown mapping")
		return
	__transport_peer_identity.erase(peer_id)
	__transport_identity_peer.erase(identity)
	_sv_set_peer_connected(identity, false)

func __on_transport_connected_to_server() -> void:
	if !__transport or check_is_host():
		return
	__trace("transport connected_to_server: sending hello handshake")
	__transport.send_to_server({
		"type": "hello",
		"identity": String(get_local_identity()),
		"handshake": create_handshake(),
	})

func __on_transport_connection_failed() -> void:
	__trace("transport connection_failed")
	__rehost_local_transport()
	if __transport and __transport.start_host():
		__trace("transport connection_failed: restarted local host on port=%d" % __transport.get_host_port())
		__transport.begin_discovery()

func __on_transport_server_disconnected() -> void:
	__trace("transport server_disconnected")
	__rehost_local_transport()

func __rehost_local_transport() -> void:
	__trace("__rehost_local_transport begin")
	host_identity = get_local_identity()
	local_peer.id = PEER_ID_FIRST
	__next_peer_id = PEER_ID_FIRST
	local_peer.net_set_connected(true)
	if __svc_spawn:
		__svc_spawn.clear()
	__gm = null
	var local_identity: StringName = get_local_identity()
	var local_instigator: GsomInstigatorImpl = _get_instigator(local_identity) as GsomInstigatorImpl
	if !local_instigator:
		local_instigator = GsomInstigatorImpl.new()
		local_instigator.net = self
		local_instigator.net_set_identity(local_identity)
		local_instigator.net_set_kind(IGsomInstigator.Kind.PLAYER)
		local_instigator.net_set_label("Player")
	local_peer.net = self
	local_peer.net_set_instigator(local_instigator)
	__instigators.clear()
	__peers.clear()
	__instigators[local_identity] = local_instigator
	__peers[local_identity] = local_peer
	__transport_peer_identity.clear()
	__transport_identity_peer.clear()
	__transport_packets.clear()
	__transport_events_in.clear()
	if __transport:
		__transport.stop_all()
	__trace("__rehost_local_transport done")

func __consume_transport_packets() -> void:
	if __transport_packets.is_empty():
		return
	var packets: Array[Dictionary] = __transport_packets
	__transport_packets = []
	for packet: Dictionary in packets:
		__handle_transport_packet(packet)

func __handle_transport_packet(packet: Dictionary) -> void:
	var packet_type: String = packet.get("type", "")
	var peer_id: int = packet.get("__peer_id", 0)
	if packet_type == "":
		return
	if packet_type != "events":
		__trace("__handle_transport_packet type=%s peer_id=%d" % [packet_type, peer_id])
	if check_is_host():
		if packet_type == "hello":
			__sv_accept_transport_peer(peer_id, packet)
			return
		if packet_type == "events":
			__sv_ingest_transport_events(peer_id, packet)
			return
		return
	if packet_type == "accept":
		__cl_accept_host(packet)
		return
	if packet_type == "reject":
		push_warning("Connection rejected by host: %s" % packet.get("reason", "Rejected."))
		__trace("client received reject reason=%s" % packet.get("reason", ""))
		__rehost_local_transport()
		return
	if packet_type == "events":
		__cl_ingest_transport_events(packet)

func __sv_accept_transport_peer(peer_id: int, packet: Dictionary) -> void:
	if !check_is_host():
		return
	if peer_id <= 1:
		return
	var identity_s: String = packet.get("identity", "")
	if identity_s == "":
		__transport.send_to_peer(peer_id, {"type": "reject", "reason": "Missing identity."})
		__transport.disconnect_peer(peer_id, "Missing identity")
		return
	var identity: StringName = StringName(identity_s)
	var handshake_v: Variant = packet.get("handshake", {})
	if typeof(handshake_v) != TYPE_DICTIONARY:
		__transport.send_to_peer(peer_id, {"type": "reject", "reason": "Bad handshake payload."})
		__transport.disconnect_peer(peer_id, "Bad handshake")
		return
	var handshake: Dictionary = handshake_v
	__trace("sv_accept hello identity=%s peer_id=%d handshake=%s" % [identity_s, peer_id, var_to_str(handshake)])
	var validation_err: String = validate_handshake(handshake)
	if validation_err != "":
		__transport.send_to_peer(peer_id, {"type": "reject", "reason": validation_err})
		__transport.disconnect_peer(peer_id, validation_err)
		return
	var mapped_peer_id: int = __transport_identity_peer.get(identity, 0)
	if mapped_peer_id > 0 and mapped_peer_id != peer_id:
		__transport.send_to_peer(peer_id, {"type": "reject", "reason": "Peer already connected."})
		__transport.disconnect_peer(peer_id, "Peer already connected")
		return
	var peer: GsomPeerImpl = __ensure_peer(identity)
	var was_connected: bool = peer._get_connected()
	peer.net_set_connected(true)
	__transport_peer_identity[peer_id] = identity
	__transport_identity_peer[identity] = peer_id
	if was_connected:
		__trace("sv_accept existing peer reconnect identity=%s id=%d" % [identity_s, peer.id])
		__sv_dispatch_peer_update(peer)
	else:
		__trace("sv_accept new peer identity=%s assigned_id=%d" % [identity_s, peer.id])
		__sv_dispatch_peer_join(peer)
	__sv_emit_instigator_state(_get_instigator(identity) as GsomInstigatorImpl)
	__sv_emit_peer_state(peer)
	prints("#%d" % OS.get_process_id(), "Net accepted peer", peer_id, peer.id)
	var bootstrap_events: Array[NetEvent] = __build_bootstrap_events()
	__trace("sv_accept sending bootstrap events=%d" % bootstrap_events.size())
	__transport.send_to_peer(peer_id, {
		"type": "accept",
		"host_identity": String(host_identity),
		"local_peer_id": peer.id,
		"events": __encode_event_list(bootstrap_events),
	})

func __sv_ingest_transport_events(peer_id: int, packet: Dictionary) -> void:
	var identity: StringName = __transport_peer_identity.get(peer_id, &"")
	if identity == &"":
		return
	var encoded_events: Variant = packet.get("events", [])
	var events: Array[NetEvent] = __decode_event_list(encoded_events)
	if __should_trace_packet_summary(events):
		__trace(
			"sv_ingest_transport_events from=%s peer_id=%d %s"
			% [String(identity), peer_id, __summarize_packet_events(events)]
		)
	for event: NetEvent in events:
		event.identity = identity
		__transport_events_in.append(event)

func __cl_accept_host(packet: Dictionary) -> void:
	__trace("cl_accept_host begin")
	if __svc_spawn:
		__svc_spawn.clear()
	__gm = null
	var local_identity: StringName = get_local_identity()
	var local_instigator: GsomInstigatorImpl = _get_instigator(local_identity) as GsomInstigatorImpl
	if !local_instigator:
		local_instigator = GsomInstigatorImpl.new()
		local_instigator.net = self
		local_instigator.net_set_identity(local_identity)
		local_instigator.net_set_kind(IGsomInstigator.Kind.PLAYER)
		local_instigator.net_set_label("Player")
	local_peer.net = self
	local_peer.net_set_instigator(local_instigator)
	__instigators.clear()
	__peers.clear()
	__instigators[local_identity] = local_instigator
	__peers[local_identity] = local_peer
	var host_identity_v: Variant = packet.get("host_identity", "")
	if typeof(host_identity_v) == TYPE_STRING or typeof(host_identity_v) == TYPE_STRING_NAME:
		host_identity = host_identity_v
	var local_id_v: Variant = packet.get("local_peer_id", local_peer.id)
	if typeof(local_id_v) == TYPE_INT:
		local_peer.id = local_id_v
	local_peer.net_set_connected(true)
	var encoded_events: Variant = packet.get("events", [])
	var events: Array[NetEvent] = __decode_event_list(encoded_events)
	__trace("cl_accept_host host_identity=%s local_peer_id=%d bootstrap_events=%d" % [String(host_identity), local_peer.id, events.size()])
	for event: NetEvent in events:
		__transport_events_in.append(event)
	__auto_join_enabled = false
	prints("#%d" % OS.get_process_id(), "Net joined host", local_peer.id)

func __cl_ingest_transport_events(packet: Dictionary) -> void:
	var encoded_events: Variant = packet.get("events", [])
	var events: Array[NetEvent] = __decode_event_list(encoded_events)
	if __should_trace_packet_summary(events):
		__trace("cl_ingest_transport_events %s" % __summarize_packet_events(events))
	for event: NetEvent in events:
		__transport_events_in.append(event)

func __send_transport_events(events: Array[NetEvent]) -> void:
	if !__transport or events.is_empty():
		return
	if __should_trace_packet_summary(events):
		__trace(
			"send_transport_events is_host=%s %s"
			% ["true" if check_is_host() else "false", __summarize_packet_events(events)]
		)
	var payload: Dictionary = {
		"type": "events",
		"events": __encode_event_list(events),
	}
	if check_is_host():
		__transport.broadcast(payload)
	else:
		__transport.send_to_server(payload)

func __encode_event_list(events: Array[NetEvent]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: NetEvent in events:
		out.append(__encode_net_event(event))
	return out

func __decode_event_list(data_v: Variant) -> Array[NetEvent]:
	var out: Array[NetEvent] = []
	if typeof(data_v) != TYPE_ARRAY:
		return out
	var values: Array = data_v
	for item_v: Variant in values:
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		var item_d: Dictionary = item_v
		var event: NetEvent = __decode_net_event(item_d)
		if !event:
			continue
		out.append(event)
	return out

func __encode_net_event(event: NetEvent) -> Dictionary:
	var out: Dictionary = {
		"kind": int(event.kind),
	}
	match event.kind:
		EventKind.SV_SPAWN:
			var spawn_data: EventDataSpawn = event.data
			out["data"] = {
				"net_id": spawn_data.net_id,
				"instigator": String(spawn_data.instigator),
				"content_id": String(spawn_data.content_id),
				"layer": int(spawn_data.layer),
				"init_data": __encode_variant(spawn_data.init_data),
			}
		EventKind.SV_DESPAWN:
			out["data"] = event.data
		EventKind.CL_ACTION:
			out["data"] = __encode_variant(event.data)
		EventKind.SV_SNAPSHOT:
			var payload: Array[EventDataSnapshot] = event.data
			var snapshots: Array[Dictionary] = []
			for item: EventDataSnapshot in payload:
				snapshots.append({
					"dest_net_id": item.dest_net_id,
					"payload": __encode_variant(item.payload),
				})
			out["data"] = snapshots
		EventKind.ENTITY:
			var entity_data: Dictionary = event.data
			out["data"] = {
				"to_server": entity_data.get("to_server", true),
				"net_id": entity_data.get("net_id", NET_ID_EMPTY),
				"event": __encode_entity_event(entity_data.get("event", null)),
			}
		EventKind.SV_LOAD:
			var load_data: EventDataLoad = event.data
			out["data"] = {
				"epoch_id": load_data.epoch_id,
				"label": load_data.label,
				"resources": __pack_string_name_array(load_data.resources),
			}
		EventKind.SV_PREFETCH:
			var prefetch_data: EventDataPrefetch = event.data
			out["data"] = {
				"epoch_id": prefetch_data.epoch_id,
				"resources": __pack_string_name_array(prefetch_data.resources),
			}
		EventKind.CL_PROGRESS:
			var progress_data: EventDataProgress = event.data
			out["data"] = {
				"epoch_id": progress_data.epoch_id,
				"progress": progress_data.progress,
			}
		EventKind.SV_PEER:
			var peer_data: EventDataPeer = event.data
			out["data"] = {
				"state": __encode_variant(peer_data.state),
			}
		EventKind.SV_INSTIGATOR:
			var inst_data: EventDataInstigator = event.data
			out["data"] = {
				"state": __encode_variant(inst_data.state),
			}
	return out

func __decode_net_event(raw: Dictionary) -> NetEvent:
	var event: NetEvent = NetEvent.new()
	var kind_v: Variant = raw.get("kind", null)
	if typeof(kind_v) != TYPE_INT:
		return null
	var kind_i: EventKind = kind_v
	event.kind = kind_i
	var data_v: Variant = raw.get("data", null)
	match event.kind:
		EventKind.SV_SPAWN:
			if typeof(data_v) != TYPE_DICTIONARY:
				return null
			var data: Dictionary = data_v
			var spawn_data: EventDataSpawn = EventDataSpawn.new()
			spawn_data.net_id = data.get("net_id", NET_ID_EMPTY)
			spawn_data.instigator = data.get("instigator", "")
			spawn_data.content_id = data.get("content_id", "")
			spawn_data.layer = data.get("layer", int(IGsomNetwork.SpawnLayer.WORLD))
			spawn_data.init_data = __decode_variant(data.get("init_data", null))
			event.data = spawn_data
		EventKind.SV_DESPAWN:
			event.data = data_v
		EventKind.CL_ACTION:
			event.data = __decode_variant(data_v)
		EventKind.SV_SNAPSHOT:
			var snapshots: Array[EventDataSnapshot] = []
			if typeof(data_v) == TYPE_ARRAY:
				var data_arr: Array = data_v
				for item_v: Variant in data_arr:
					if typeof(item_v) != TYPE_DICTIONARY:
						continue
					var item: Dictionary = item_v
					var snapshot_data: EventDataSnapshot = EventDataSnapshot.new()
					snapshot_data.dest_net_id = item.get("dest_net_id", NET_ID_EMPTY)
					snapshot_data.payload = __decode_variant(item.get("payload", null))
					snapshots.append(snapshot_data)
			event.data = snapshots
		EventKind.ENTITY:
			if typeof(data_v) != TYPE_DICTIONARY:
				return null
			var entity_data: Dictionary = data_v
			event.data = {
				"to_server": entity_data.get("to_server", true),
				"net_id": entity_data.get("net_id", NET_ID_EMPTY),
				"event": __decode_entity_event(entity_data.get("event", null)),
			}
		EventKind.SV_LOAD:
			if typeof(data_v) != TYPE_DICTIONARY:
				return null
			var load_raw: Dictionary = data_v
			var load_data: EventDataLoad = EventDataLoad.new()
			load_data.epoch_id = load_raw.get("epoch_id", 0)
			load_data.label = load_raw.get("label", "")
			load_data.resources = __unpack_string_name_array(load_raw.get("resources", []))
			event.data = load_data
		EventKind.SV_PREFETCH:
			if typeof(data_v) != TYPE_DICTIONARY:
				return null
			var prefetch_raw: Dictionary = data_v
			var prefetch_data: EventDataPrefetch = EventDataPrefetch.new()
			prefetch_data.epoch_id = prefetch_raw.get("epoch_id", 0)
			prefetch_data.resources = __unpack_string_name_array(prefetch_raw.get("resources", []))
			event.data = prefetch_data
		EventKind.CL_PROGRESS:
			if typeof(data_v) != TYPE_DICTIONARY:
				return null
			var progress_raw: Dictionary = data_v
			var progress_data: EventDataProgress = EventDataProgress.new()
			progress_data.epoch_id = progress_raw.get("epoch_id", 0)
			progress_data.progress = progress_raw.get("progress", 0.0)
			event.data = progress_data
		EventKind.SV_PEER:
			if typeof(data_v) != TYPE_DICTIONARY:
				return null
			var peer_raw: Dictionary = data_v
			var peer_data: EventDataPeer = EventDataPeer.new()
			var peer_state_v: Variant = __decode_variant(peer_raw.get("state", {}))
			if typeof(peer_state_v) == TYPE_DICTIONARY:
				peer_data.state = peer_state_v
			event.data = peer_data
		EventKind.SV_INSTIGATOR:
			if typeof(data_v) != TYPE_DICTIONARY:
				return null
			var inst_raw: Dictionary = data_v
			var inst_data: EventDataInstigator = EventDataInstigator.new()
			var inst_state_v: Variant = __decode_variant(inst_raw.get("state", {}))
			if typeof(inst_state_v) == TYPE_DICTIONARY:
				inst_data.state = inst_state_v
			event.data = inst_data
		_:
			event.data = __decode_variant(data_v)
	return event

func __encode_entity_event(event_v: Variant) -> Variant:
	var event: IGsomEntity.Event = event_v
	if !event:
		return __encode_variant(event_v)
	return {
		"kind": String(event.kind),
		"data": __encode_variant(event.data),
	}

func __decode_entity_event(raw_v: Variant) -> Variant:
	if typeof(raw_v) != TYPE_DICTIONARY:
		return __decode_variant(raw_v)
	var raw: Dictionary = raw_v
	var event: IGsomEntity.Event = IGsomEntity.Event.new()
	event.kind = raw.get("kind", "")
	event.data = __decode_variant(raw.get("data", null))
	return event

func __encode_variant(value: Variant) -> Variant:
	var kind: int = typeof(value)
	if kind == TYPE_DICTIONARY:
		var src: Dictionary = value
		var out_dict: Dictionary = {}
		for key_v: Variant in src.keys():
			var key_s: String = key_v
			out_dict[key_s] = __encode_variant(src[key_v])
		return out_dict
	if kind == TYPE_ARRAY:
		var src_arr: Array = value
		var out_arr: Array = []
		for item: Variant in src_arr:
			out_arr.append(__encode_variant(item))
		return out_arr
	if kind == TYPE_STRING_NAME:
		var value_s: String = value
		return value_s
	if kind == TYPE_OBJECT:
		return __encode_object_props(value)
	return value

func __decode_variant(value: Variant) -> Variant:
	var kind: int = typeof(value)
	if kind == TYPE_DICTIONARY:
		var src: Dictionary = value
		if src.get("__object_props", false):
			return __decode_variant(src.get("props", {}))
		var out_dict: Dictionary = {}
		for key_v: Variant in src.keys():
			var key_s: String = key_v
			out_dict[key_s] = __decode_variant(src[key_v])
		return out_dict
	if kind == TYPE_ARRAY:
		var src_arr: Array = value
		var out_arr: Array = []
		for item: Variant in src_arr:
			out_arr.append(__decode_variant(item))
		return out_arr
	return value

func __encode_object_props(value: Variant) -> Variant:
	if !(value is Object):
		return null
	var object: Object = value
	var props: Dictionary = {}
	for prop_v: Variant in object.get_property_list():
		if typeof(prop_v) != TYPE_DICTIONARY:
			continue
		var prop: Dictionary = prop_v
		var usage: int = prop.get("usage", 0)
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var name_v: Variant = prop.get("name", "")
		if typeof(name_v) != TYPE_STRING and typeof(name_v) != TYPE_STRING_NAME:
			continue
		var prop_name: StringName = name_v
		props[String(prop_name)] = __encode_variant(object.get(prop_name))
	return {
		"__object_props": true,
		"props": props,
	}

func __pack_string_name_array(values: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for value: StringName in values:
		out.append(String(value))
	return out

func __unpack_string_name_array(values_v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if typeof(values_v) != TYPE_ARRAY:
		return out
	var values: Array = values_v
	for value_v: Variant in values:
		if typeof(value_v) != TYPE_STRING and typeof(value_v) != TYPE_STRING_NAME:
			continue
		var value_sn: StringName = value_v
		out.append(value_sn)
	return out

func __ensure_peer(identity: StringName) -> GsomPeerImpl:
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if peer:
		if peer.id == NET_ID_EMPTY:
			peer.id = __alloc_peer_id()
		return peer
	var instigator: GsomInstigatorImpl = _get_instigator(identity) as GsomInstigatorImpl
	if !instigator:
		instigator = _sv_register_instigator(identity, IGsomInstigator.Kind.PLAYER, "Player") as GsomInstigatorImpl
	if !instigator:
		return null
	peer = GsomPeerImpl.new()
	peer.net = self
	peer.net_set_instigator(instigator)
	peer.id = __alloc_peer_id()
	peer.net_set_connected(false)
	__peers[identity] = peer
	return peer

func __alloc_peer_id() -> int:
	__next_peer_id += 1
	return __next_peer_id

func __sv_emit_peer_state(peer: GsomPeerImpl) -> void:
	if !check_is_host() or !peer:
		return
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.SV_PEER
	var data: EventDataPeer = EventDataPeer.new()
	data.state = peer.net_pack_state()
	e.data = data
	__send_net_event(e)

func __sv_emit_instigator_state(instigator: GsomInstigatorImpl) -> void:
	if !check_is_host() or !instigator:
		return
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.SV_INSTIGATOR
	var data: EventDataInstigator = EventDataInstigator.new()
	data.state = instigator.net_pack_state()
	e.data = data
	__send_net_event(e)

func __cl_apply_instigator_state(state: Dictionary) -> void:
	var identity_v: Variant = state.get("identity", "")
	if typeof(identity_v) != TYPE_STRING and typeof(identity_v) != TYPE_STRING_NAME:
		return
	var identity: StringName = identity_v
	var instigator: GsomInstigatorImpl = _get_instigator(identity) as GsomInstigatorImpl
	if !instigator:
		instigator = GsomInstigatorImpl.new()
		instigator.net = self
		__instigators[identity] = instigator
	instigator.net_apply_state(state)

func __cl_apply_peer_state(state: Dictionary) -> void:
	var identity_v: Variant = state.get("identity", "")
	if typeof(identity_v) != TYPE_STRING and typeof(identity_v) != TYPE_STRING_NAME:
		return
	var identity: StringName = identity_v
	var instigator: GsomInstigatorImpl = _get_instigator(identity) as GsomInstigatorImpl
	if !instigator:
		instigator = GsomInstigatorImpl.new()
		instigator.net = self
		instigator.net_set_identity(identity)
		instigator.net_set_kind(IGsomInstigator.Kind.PLAYER)
		instigator.net_set_label("Player")
		__instigators[identity] = instigator
	var peer: GsomPeerImpl = _get_peer(identity) as GsomPeerImpl
	if !peer:
		peer = GsomPeerImpl.new()
		peer.net = self
		peer.net_set_instigator(instigator)
		__peers[identity] = peer
	peer.net_apply_state(state)

func __build_bootstrap_events() -> Array[NetEvent]:
	var events: Array[NetEvent] = []
	for instigator: GsomInstigatorImpl in __instigators.values():
		var inst_event: NetEvent = NetEvent.new()
		inst_event.kind = EventKind.SV_INSTIGATOR
		var inst_data: EventDataInstigator = EventDataInstigator.new()
		inst_data.state = instigator.net_pack_state()
		inst_event.data = inst_data
		events.append(inst_event)
	for peer: GsomPeerImpl in __peers.values():
		var peer_event: NetEvent = NetEvent.new()
		peer_event.kind = EventKind.SV_PEER
		var peer_data: EventDataPeer = EventDataPeer.new()
		peer_data.state = peer.net_pack_state()
		peer_event.data = peer_data
		events.append(peer_event)
	if __load_epoch_next:
		var next_event: NetEvent = NetEvent.new()
		next_event.kind = EventKind.SV_LOAD
		var next_data: EventDataLoad = EventDataLoad.new()
		next_data.epoch_id = __load_epoch_next.epoch_id
		next_data.label = __load_epoch_next.label
		next_data.resources = __dict_keys_to_string_names(__load_epoch_next.resources)
		next_event.data = next_data
		events.append(next_event)
	elif __load_epoch.epoch_id > 0:
		var load_event: NetEvent = NetEvent.new()
		load_event.kind = EventKind.SV_LOAD
		var load_data: EventDataLoad = EventDataLoad.new()
		load_data.epoch_id = __load_epoch.epoch_id
		load_data.label = __load_epoch.label
		load_data.resources = __dict_keys_to_string_names(__load_epoch.resources)
		load_event.data = load_data
		events.append(load_event)
	if !__svc_spawn:
		return events
	var snapshots: Array[EventDataSnapshot] = []
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		var spawn_event: NetEvent = NetEvent.new()
		spawn_event.kind = EventKind.SV_SPAWN
		var spawn_data: EventDataSpawn = EventDataSpawn.new()
		spawn_data.net_id = entity.net_id
		spawn_data.instigator = entity.instigator
		spawn_data.content_id = entity.content_id
		spawn_data.layer = entity.layer
		spawn_data.init_data = entity.init_data
		spawn_event.data = spawn_data
		events.append(spawn_event)
		var snapshot: Variant = entity._write_snapshot(IGsomEntity.RelevancyLod.MAX)
		if snapshot == null:
			continue
		var snapshot_data: EventDataSnapshot = EventDataSnapshot.new()
		snapshot_data.dest_net_id = entity.net_id
		snapshot_data.payload = snapshot
		snapshots.append(snapshot_data)
	if !snapshots.is_empty():
		var snapshot_event: NetEvent = NetEvent.new()
		snapshot_event.kind = EventKind.SV_SNAPSHOT
		snapshot_event.data = snapshots
		events.append(snapshot_event)
	return events

func __try_auto_join_remote_host() -> void:
	if !__auto_join_enabled or !check_is_host():
		return
	if __gm:
		return
	if __transport == null or !__transport.is_host():
		return
	if _get_peers_connected().size() > 1:
		return
	if __auto_join_elapsed_s < __AutoJoinRetryS:
		return
	__auto_join_elapsed_s = 0.0
	var local_identity_s: String = String(get_local_identity())
	var target: Dictionary = {}
	for host: Dictionary in __transport.get_discovered_hosts():
		var identity_v: Variant = host.get("identity", "")
		if typeof(identity_v) != TYPE_STRING and typeof(identity_v) != TYPE_STRING_NAME:
			continue
		var host_identity_s: String = identity_v
		if host_identity_s == "" or host_identity_s == local_identity_s:
			continue
		# Deterministic tie-breaker: only peers with larger identity join smaller host identity.
		if host_identity_s >= local_identity_s:
			continue
		if target.is_empty() or host_identity_s < target.get("identity", ""):
			target = host
	if target.is_empty():
		return
	var address: String = target.get("address", "127.0.0.1")
	var port: int = target.get("port", 0)
	if port <= 0:
		return
	prints("Net auto-join target", target.get("identity", &""), address, port)
	var err: Error = __transport.join_host(address, port)
	if err != OK:
		push_warning("Failed to auto-join host %s:%d (err=%s)." % [address, port, error_string(err)])
		return
	host_identity = &"__pending_host__"

func demo_get_discovered_hosts() -> Array[Dictionary]:
	if !__transport:
		return []
	return __transport.get_discovered_hosts()

func demo_join_host(identity: StringName) -> bool:
	if !__transport:
		return false
	for host: Dictionary in __transport.get_discovered_hosts():
		var host_identity_v: Variant = host.get("identity", &"")
		if typeof(host_identity_v) != TYPE_STRING and typeof(host_identity_v) != TYPE_STRING_NAME:
			continue
		host_identity = host_identity_v
		if host_identity != identity:
			continue
		var address: String = host.get("address", "127.0.0.1")
		var port: int = host.get("port", 0)
		if port <= 0:
			return false
		var err: Error = __transport.join_host(address, port)
		if err != OK:
			push_warning("Join failed to '%s' (%s:%d), err=%s." % [String(identity), address, port, error_string(err)])
			return false
		host_identity = &"__pending_host__"
		return true
	return false

func demo_disconnect_from_host() -> bool:
	if check_is_host():
		return false
	__auto_join_enabled = false
	__rehost_local_transport()
	if !__transport:
		return false
	var started: bool = __transport.start_host()
	if !started:
		push_error("Failed to restart local host transport after disconnect.")
		return false
	__transport.begin_discovery()
	return true

func __dict_keys_to_string_names(dict: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for key_v: Variant in dict.keys():
		if typeof(key_v) != TYPE_STRING and typeof(key_v) != TYPE_STRING_NAME:
			continue
		var key_sn: StringName = key_v
		out.append(key_sn)
	return out

#endregion

#region Tick

func __local_tick(dt: float) -> void:
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		if entity is not IGsomPlayer:
			continue
		var as_player: IGsomPlayer = entity
		if as_player.check_is_local():
			var actions: Variant = as_player._local_tick(dt)
			if actions == null:
				break
			var e: NetEvent = NetEvent.new()
			e.kind = EventKind.CL_ACTION
			e.data = actions
			__send_net_event(e)
			break

func __sv_tick(dt: float) -> void:
	if !check_is_host():
		return
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		entity._sv_tick(dt)
	var snapshots: Array[EventDataSnapshot] = []
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		var snapshot: Variant = entity._write_snapshot(IGsomEntity.RelevancyLod.MAX)
		if snapshot == null:
			continue
		var ev_data: EventDataSnapshot = EventDataSnapshot.new()
		ev_data.dest_net_id = entity.net_id
		ev_data.payload = snapshot
		snapshots.append(ev_data)
	if snapshots.is_empty():
		return
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.SV_SNAPSHOT
	e.data = snapshots
	__send_net_event(e)

func __cl_tick(dt: float) -> void:
	for entity: IGsomEntity in __svc_spawn.entities_by_id.values():
		entity._cl_tick(dt)
	if check_is_host():
		return
	if !__gm:
		__cl_resync_elapsed_s = 0.0
		return
	var local_player: IGsomPlayer = _get_player(get_local_identity())
	if local_player:
		__cl_resync_elapsed_s = 0.0
		return
	__cl_resync_elapsed_s += dt
	if __cl_resync_elapsed_s < 1.0:
		return
	__cl_resync_elapsed_s = 0.0
	var e: NetEvent = NetEvent.new()
	e.kind = EventKind.CL_RESYNC
	e.data = null
	__send_net_event(e)
	__trace("__cl_tick requested CL_RESYNC (missing local player while gm active)")

func __flush_events() -> void:
	__loopback_events_next = __events_out.duplicate(true)
	__send_transport_events(__events_out)
	__events_out = []

func _physics_process(dt: float) -> void:
	__poll_events(dt)
	
	__sv_handle_events()
	__sv_handle_actions()
	__sv_tick(dt)
	
	__cl_handle_events()
	__cl_tick(dt)
	
	__local_tick(dt)
	__auto_join_elapsed_s += dt
	__try_auto_join_remote_host()
	
	__flush_events()

#endregion

func gamemode_start(content_id: StringName) -> void:
	if !check_is_host() or __gm:
		__trace(
			"gamemode_start ignored content=%s is_host=%s has_gm=%s"
			% [
				String(content_id),
				"true" if check_is_host() else "false",
				"true" if __gm != null else "false",
			]
		)
		return
	__trace("gamemode_start content=%s" % String(content_id))
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
	return {
		"protocol": __ProtocolVersion,
		"build": "demo-local",
	}

## Server checks the incoming handshake data during connection.
##
## Return empty string if the peer is allowed to join.
## Non-empty string will be used to display the disconnection reason.
func validate_handshake(data: Dictionary) -> String:
	var protocol: int = data.get("protocol", 0)
	if protocol != __ProtocolVersion:
		return "Protocol mismatch."
	return ""

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
	instigator.net = self
	instigator.net_set_identity(_identity)
	instigator.net_set_kind(_kind)
	instigator.net_set_label(_label)
	if _content_id != &"":
		instigator.net_set_attr_string(&"content_id", String(_content_id))
	__instigators[_identity] = instigator
	__sv_emit_instigator_state(instigator)
	return instigator

func _get_instigator(_identity: StringName) -> IGsomInstigator:
	return __instigators.get(_identity, null)

func _get_instigator_label(identity: StringName) -> String:
	var instigator: IGsomInstigator = _get_instigator(identity)
	return instigator._get_label() if instigator else ""

func _get_instigator_attr_int(identity: StringName, key: StringName) -> int:
	var instigator: IGsomInstigator = _get_instigator(identity)
	return instigator._get_attr_int(key) if instigator else 0

func _get_instigator_attr_bool(identity: StringName, key: StringName) -> bool:
	var instigator: IGsomInstigator = _get_instigator(identity)
	return instigator._get_attr_bool(key) if instigator else false

func _get_instigator_attr_string(identity: StringName, key: StringName) -> String:
	var instigator: IGsomInstigator = _get_instigator(identity)
	return instigator._get_attr_string(key) if instigator else ""

func _get_instigator_attr_float(identity: StringName, key: StringName) -> float:
	var instigator: IGsomInstigator = _get_instigator(identity)
	return instigator._get_attr_float(key) if instigator else 0.0

func _has_instigator_attr_int(identity: StringName, key: StringName) -> bool:
	var instigator: IGsomInstigator = _get_instigator(identity)
	return instigator._has_attr_int(key) if instigator else false

func _has_instigator_attr_bool(identity: StringName, key: StringName) -> bool:
	var instigator: IGsomInstigator = _get_instigator(identity)
	return instigator._has_attr_bool(key) if instigator else false

func _has_instigator_attr_string(identity: StringName, key: StringName) -> bool:
	var instigator: IGsomInstigator = _get_instigator(identity)
	return instigator._has_attr_string(key) if instigator else false

func _has_instigator_attr_float(identity: StringName, key: StringName) -> bool:
	var instigator: IGsomInstigator = _get_instigator(identity)
	return instigator._has_attr_float(key) if instigator else false

func _sv_set_instigator_label(
	_identity: StringName,
	_label: String,
) -> void:
	if !check_is_host():
		return
	var instigator: GsomInstigatorImpl = _get_instigator(_identity) as GsomInstigatorImpl
	if instigator:
		instigator.net_set_label(_label)
		__sv_emit_instigator_state(instigator)

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
		__sv_emit_instigator_state(instigator)

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
		__sv_emit_instigator_state(instigator)

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
		__sv_emit_instigator_state(instigator)

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
		__sv_emit_instigator_state(instigator)

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

func _get_peer_label(identity: StringName) -> String:
	var peer: IGsomPeer = _get_peer(identity)
	return peer._get_label() if peer else ""

func _get_peer_attr_int(identity: StringName, key: StringName) -> int:
	var peer: IGsomPeer = _get_peer(identity)
	return peer._get_attr_int(key) if peer else 0

func _get_peer_attr_bool(identity: StringName, key: StringName) -> bool:
	var peer: IGsomPeer = _get_peer(identity)
	return peer._get_attr_bool(key) if peer else false

func _get_peer_attr_string(identity: StringName, key: StringName) -> String:
	var peer: IGsomPeer = _get_peer(identity)
	return peer._get_attr_string(key) if peer else ""

func _get_peer_attr_float(identity: StringName, key: StringName) -> float:
	var peer: IGsomPeer = _get_peer(identity)
	return peer._get_attr_float(key) if peer else 0.0

func _has_peer_attr_int(identity: StringName, key: StringName) -> bool:
	var peer: IGsomPeer = _get_peer(identity)
	return peer._has_attr_int(key) if peer else false

func _has_peer_attr_bool(identity: StringName, key: StringName) -> bool:
	var peer: IGsomPeer = _get_peer(identity)
	return peer._has_attr_bool(key) if peer else false

func _has_peer_attr_string(identity: StringName, key: StringName) -> bool:
	var peer: IGsomPeer = _get_peer(identity)
	return peer._has_attr_string(key) if peer else false

func _has_peer_attr_float(identity: StringName, key: StringName) -> bool:
	var peer: IGsomPeer = _get_peer(identity)
	return peer._has_attr_float(key) if peer else false

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
	__sv_emit_peer_state(peer)

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
	__sv_emit_peer_state(peer)
	__sv_emit_instigator_state(_get_instigator(identity) as GsomInstigatorImpl)

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
	__sv_emit_peer_state(peer)
	__sv_emit_instigator_state(_get_instigator(identity) as GsomInstigatorImpl)

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
	__sv_emit_peer_state(peer)
	__sv_emit_instigator_state(_get_instigator(identity) as GsomInstigatorImpl)

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
	__sv_emit_peer_state(peer)
	__sv_emit_instigator_state(_get_instigator(identity) as GsomInstigatorImpl)

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
	__sv_emit_peer_state(peer)
	__sv_emit_instigator_state(_get_instigator(identity) as GsomInstigatorImpl)

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
	__trace(
		"__sv_dispatch_peer_join identity=%s connected=%s"
		% [String(peer._get_identity()), "true" if peer._get_connected() else "false"]
	)
	if __gm:
		__gm._sv_peer_join(peer)
	__sv_dispatch_player_peer_update(peer)
	__sv_emit_peer_state(peer as GsomPeerImpl)

func __sv_dispatch_peer_drop(peer: IGsomPeer) -> void:
	if !check_is_host():
		return
	__trace("__sv_dispatch_peer_drop identity=%s" % String(peer._get_identity()))
	if __gm:
		__gm._sv_peer_drop(peer)
	__sv_dispatch_player_peer_update(peer)
	__sv_emit_peer_state(peer as GsomPeerImpl)

func __sv_dispatch_peer_update(peer: IGsomPeer) -> void:
	if !check_is_host():
		return
	__trace(
		"__sv_dispatch_peer_update identity=%s connected=%s"
		% [String(peer._get_identity()), "true" if peer._get_connected() else "false"]
	)
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
	__trace("_sv_load_start label=%s resources=%d" % [label, resources.size()])
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
	__trace("__shared_load epoch=%d label=%s resources=%d" % [ev_data.epoch_id, ev_data.label, ev_data.resources.size()])
	__load_epoch_next = LoadEpoch.new()
	__load_epoch_next.epoch_id = ev_data.epoch_id
	__load_epoch_next.label = ev_data.label
	
	for peer: GsomPeerImpl in __peers.values():
		peer.net_set_load_epoch(ev_data.epoch_id)
		peer.net_set_load_progress(0.0)
		if check_is_host():
			__sv_emit_peer_state(peer)
	
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
	if ev_data.progress >= 1.0 or ev_data.progress <= 0.0:
		__trace(
			"__shared_progress peer=%s epoch=%d progress=%.3f"
			% [String(peer._get_identity()), ev_data.epoch_id, ev_data.progress]
		)
	peer.net_set_load_progress(clampf(ev_data.progress, 0.0, 1.0))
	if check_is_host():
		__sv_emit_peer_state(peer)

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
	__trace("_cl_load_complete epoch=%d" % epoch_id)

#endregion
