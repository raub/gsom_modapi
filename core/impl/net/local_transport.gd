extends Node
class_name GsomLocalTransport

signal packet_received(peer_id: int, payload: Dictionary)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connected_to_server()
signal connection_failed()
signal server_disconnected()
signal host_discovered(info: Dictionary)

const PROTOCOL_VERSION: int = 1
const MAX_CLIENTS: int = 16
const PORT_MIN: int = 39100
const PORT_MAX: int = 39131
const DISCOVERY_PORT_OFFSET: int = 2000
const DISCOVERY_INTERVAL_S: float = 1.0
const DISCOVERY_STALE_MS: int = 3500
const __TraceTransport: bool = true

var __identity: StringName = &""
var __is_host: bool = false
var __host_port: int = 0
var __enet: ENetMultiplayerPeer = null
var __mode_switch_in_progress: bool = false

var __discovery_listener: PacketPeerUDP = null
var __discovery_scanner: PacketPeerUDP = null
var __discovery_elapsed_s: float = 0.0
var __scan_request_id: int = 0
var __hosts: Dictionary[StringName, Dictionary] = {}

func __trace(message: String) -> void:
	if !__TraceTransport:
		return
	var mode: String = "SV" if __is_host else "CL"
	prints("#%d" % OS.get_process_id(), "[T]", mode, message)

func _ready() -> void:
	multiplayer.peer_connected.connect(__on_peer_connected)
	multiplayer.peer_disconnected.connect(__on_peer_disconnected)
	multiplayer.connected_to_server.connect(__on_connected_to_server)
	multiplayer.connection_failed.connect(__on_connection_failed)
	multiplayer.server_disconnected.connect(__on_server_disconnected)

func configure_identity(identity: StringName) -> void:
	__identity = identity

func start_host() -> bool:
	stop_all()
	var ports: Array[int] = []
	for port_i: int in range(PORT_MIN, PORT_MAX + 1):
		ports.append(port_i)
	ports.shuffle()
	for port: int in ports:
		var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
		var err: Error = peer.create_server(port, MAX_CLIENTS)
		if err != OK:
			continue
		__enet = peer
		__host_port = port
		__is_host = true
		multiplayer.multiplayer_peer = __enet
		__bind_discovery_listener()
		__trace("start_host success port=%d" % port)
		return true
	__trace("start_host failed all ports busy")
	return false

func begin_discovery() -> void:
	if __discovery_scanner:
		return
	var scanner: PacketPeerUDP = PacketPeerUDP.new()
	var err: Error = scanner.bind(0, "*")
	if err != OK:
		push_warning("Failed to bind discovery scanner socket: %s" % error_string(err))
		__trace("begin_discovery bind failed err=%s" % error_string(err))
		return
	scanner.set_broadcast_enabled(true)
	__discovery_scanner = scanner
	__trace("begin_discovery ok")
	__send_discovery_probe()

func tick(dt: float) -> void:
	__poll_discovery_listener()
	__poll_discovery_scanner()
	if __discovery_scanner:
		__discovery_elapsed_s += dt
		if __discovery_elapsed_s >= DISCOVERY_INTERVAL_S:
			__discovery_elapsed_s = 0.0
			__send_discovery_probe()
	__prune_discovered_hosts()

func stop_all() -> void:
	__trace("stop_all begin")
	if __enet:
		__enet.close()
		__enet = null
	multiplayer.multiplayer_peer = null
	__is_host = false
	__host_port = 0
	if __discovery_listener:
		__discovery_listener.close()
		__discovery_listener = null
	if __discovery_scanner:
		__discovery_scanner.close()
		__discovery_scanner = null
	__trace("stop_all done")

func is_host() -> bool:
	return __is_host

func check_connected() -> bool:
	return __enet != null and multiplayer.multiplayer_peer != null

func get_host_port() -> int:
	return __host_port

func get_discovered_hosts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for info: Dictionary in __hosts.values():
		out.append(info.duplicate(true))
	return out

func join_host(address: String, port: int) -> Error:
	__trace("join_host target=%s:%d" % [address, port])
	__mode_switch_in_progress = true
	stop_all()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		__mode_switch_in_progress = false
		__trace("join_host create_client failed err=%s" % error_string(err))
		return err
	__enet = peer
	__is_host = false
	__host_port = 0
	multiplayer.multiplayer_peer = __enet
	call_deferred("__clear_mode_switch_flag")
	__trace("join_host create_client ok")
	return OK

func send_to_server(payload: Dictionary) -> void:
	if __is_host:
		return
	if !__enet or !multiplayer.multiplayer_peer:
		return
	__trace("send_to_server type=%s" % String(payload.get("type", "")))
	rpc_id(1, "__rpc_transport_packet", payload)

func send_to_peer(peer_id: int, payload: Dictionary) -> void:
	if !__is_host:
		return
	if !__enet or !multiplayer.multiplayer_peer:
		return
	if peer_id <= 1:
		return
	__trace("send_to_peer peer_id=%d type=%s" % [peer_id, String(payload.get("type", ""))])
	rpc_id(peer_id, "__rpc_transport_packet", payload)

func broadcast(payload: Dictionary) -> void:
	if !__is_host:
		return
	if !__enet or !multiplayer.multiplayer_peer:
		return
	for peer_id: int in multiplayer.get_peers():
		send_to_peer(peer_id, payload)

func disconnect_peer(peer_id: int, _reason: String = "") -> void:
	if !__is_host or !__enet:
		return
	__enet.disconnect_peer(peer_id, 0)

@rpc("any_peer", "reliable")
func __rpc_transport_packet(payload: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	__trace("rpc_packet_in from=%d type=%s" % [sender_id, String(payload.get("type", ""))])
	packet_received.emit(sender_id, payload)

func __bind_discovery_listener() -> void:
	if __discovery_listener:
		__discovery_listener.close()
		__discovery_listener = null
	if __host_port <= 0:
		return
	var listener: PacketPeerUDP = PacketPeerUDP.new()
	var discovery_port: int = __host_port + DISCOVERY_PORT_OFFSET
	var err: Error = listener.bind(discovery_port, "*")
	if err != OK:
		push_warning("Failed to bind discovery listener on port %d (err=%s)." % [discovery_port, error_string(err)])
		return
	__discovery_listener = listener

func __send_discovery_probe() -> void:
	if !__discovery_scanner:
		return
	__scan_request_id += 1
	var probe: Dictionary = {
		"type": "discover",
		"protocol": PROTOCOL_VERSION,
		"request_id": __scan_request_id,
		"sender_identity": String(__identity),
	}
	var packet: PackedByteArray = var_to_bytes(probe)
	for host_port: int in range(PORT_MIN, PORT_MAX + 1):
		var discovery_port: int = host_port + DISCOVERY_PORT_OFFSET
		__discovery_scanner.set_dest_address("127.0.0.1", discovery_port)
		__discovery_scanner.put_packet(packet)
		__discovery_scanner.set_dest_address("255.255.255.255", discovery_port)
		__discovery_scanner.put_packet(packet)

func __poll_discovery_listener() -> void:
	if !__discovery_listener:
		return
	while __discovery_listener.get_available_packet_count() > 0:
		var packet: PackedByteArray = __discovery_listener.get_packet()
		var sender_ip: String = __discovery_listener.get_packet_ip()
		var sender_port: int = __discovery_listener.get_packet_port()
		var data_v: Variant = bytes_to_var(packet)
		if typeof(data_v) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = data_v
		if data.get("type", "") != "discover":
			continue
		if data.get("protocol", 0) != PROTOCOL_VERSION:
			continue
		var response: Dictionary = {
			"type": "offer",
			"protocol": PROTOCOL_VERSION,
			"request_id": data.get("request_id", 0),
			"host_identity": String(__identity),
			"host_port": __host_port,
		}
		__discovery_listener.set_dest_address(sender_ip, sender_port)
		__discovery_listener.put_packet(var_to_bytes(response))

func __poll_discovery_scanner() -> void:
	if !__discovery_scanner:
		return
	while __discovery_scanner.get_available_packet_count() > 0:
		var packet: PackedByteArray = __discovery_scanner.get_packet()
		var sender_ip: String = __discovery_scanner.get_packet_ip()
		var data_v: Variant = bytes_to_var(packet)
		if typeof(data_v) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = data_v
		if data.get("type", "") != "offer":
			continue
		if data.get("protocol", 0) != PROTOCOL_VERSION:
			continue
		var identity_s: String = data.get("host_identity", "")
		if identity_s == "":
			continue
		var identity: StringName = StringName(identity_s)
		var port: int = data.get("host_port", 0)
		if port <= 0:
			continue
		if identity == __identity and port == __host_port:
			continue
		var now_ms: int = Time.get_ticks_msec()
		var info: Dictionary = {
			"identity": identity,
			"address": "127.0.0.1",
			"source_address": sender_ip,
			"port": port,
			"last_seen_ms": now_ms,
		}
		var is_new: bool = !__hosts.has(identity)
		__hosts[identity] = info
		if is_new:
			host_discovered.emit(info.duplicate(true))

func __prune_discovered_hosts() -> void:
	if __hosts.is_empty():
		return
	var now_ms: int = Time.get_ticks_msec()
	var stale: Array[StringName] = []
	for identity: StringName in __hosts.keys():
		var info: Dictionary = __hosts[identity]
		var seen_ms: int = info.get("last_seen_ms", 0)
		if seen_ms <= 0:
			stale.append(identity)
			continue
		if now_ms - seen_ms > DISCOVERY_STALE_MS:
			stale.append(identity)
	for identity: StringName in stale:
		__hosts.erase(identity)

func __on_peer_connected(peer_id: int) -> void:
	if !__is_host:
		return
	__trace("peer_connected peer_id=%d" % peer_id)
	peer_connected.emit(peer_id)

func __on_peer_disconnected(peer_id: int) -> void:
	if __is_host:
		__trace("peer_disconnected peer_id=%d" % peer_id)
		peer_disconnected.emit(peer_id)

func __on_connected_to_server() -> void:
	__mode_switch_in_progress = false
	__trace("connected_to_server")
	connected_to_server.emit()

func __on_connection_failed() -> void:
	if __mode_switch_in_progress:
		__mode_switch_in_progress = false
		__trace("connection_failed ignored due to mode switch")
		return
	__trace("connection_failed")
	connection_failed.emit()
	stop_all()

func __on_server_disconnected() -> void:
	if __mode_switch_in_progress:
		__mode_switch_in_progress = false
		__trace("server_disconnected ignored due to mode switch")
		return
	if __is_host:
		__trace("server_disconnected ignored on host")
		return
	__trace("server_disconnected")
	server_disconnected.emit()
	stop_all()

func __clear_mode_switch_flag() -> void:
	__trace("mode_switch flag cleared")
	__mode_switch_in_progress = false
