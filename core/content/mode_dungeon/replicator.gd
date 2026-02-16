extends IGsomGameMode

const __TagDungeon: StringName = &"dungeon"
const __TagPlayer: StringName = &"player"
const __TagFps: StringName = &"fps"

var __sv_wait_epoch: int = 0
var __sv_pending_spawn: bool = false
var __sv_started: bool = false

var __sv_room_content_id: StringName = &""
var __sv_controller_content_id: StringName = &""
var __sv_pawn_content_id: StringName = &""
var __sv_next_slot_index: int = 0

class Session:
	var peer_identity: StringName = &""
	var slot_index: int = -1
	var player_id: int = IGsomNetwork.NET_ID_EMPTY
	var pawn_id: int = IGsomNetwork.NET_ID_EMPTY
	var reserved: bool = false

var __sv_sessions: Dictionary = {}

func _sv_ready() -> void:
	__sv_room_content_id = __pick_content_id(&"room", [__TagDungeon])
	__sv_controller_content_id = __pick_content_id(&"controller", [__TagPlayer, __TagFps])
	__sv_pawn_content_id = __pick_content_id(&"actor", [__TagDungeon, __TagPlayer, &"character"])
	__sv_sessions.clear()
	__sv_next_slot_index = 0
	
	__sv_wait_epoch = net.get_local_peer()._get_load_epoch() + 1
	__sv_pending_spawn = true
	__sv_started = false
	
	var resources: Array[StringName] = __build_load_resources()
	net._sv_load_start("dungeon:start", resources)

func _sv_load_start(_label: String) -> void:
	__sv_started = false

func _cl_load_complete() -> void:
	net._cl_load_complete()

func _sv_peer_join(peer: IGsomPeer) -> void:
	if !peer:
		return
	if !__sv_started:
		return
	var session: Session = __sv_get_or_create_session(peer._get_identity())
	__sv_ensure_session_entities(session)
	session.reserved = !peer._get_connected()
	__sv_apply_session_state(session)

func _sv_peer_drop(peer: IGsomPeer) -> void:
	if !peer:
		return
	if !__sv_sessions.has(peer._get_identity()):
		return
	var session: Session = __sv_sessions[peer._get_identity()]
	session.reserved = true
	__sv_apply_session_state(session)

func _sv_peer_update(peer: IGsomPeer) -> void:
	if !peer:
		return
	if !__sv_started:
		return
	var peer_identity: StringName = peer._get_identity()
	if !__sv_sessions.has(peer_identity):
		if peer._get_connected():
			_sv_peer_join(peer)
		return
	var session: Session = __sv_sessions[peer_identity]
	__sv_ensure_session_entities(session)
	session.reserved = !peer._get_connected()
	__sv_apply_session_state(session)

func _sv_tick(_dt: float) -> void:
	if !__sv_pending_spawn or __sv_started:
		return
	if !__all_peers_ready(__sv_wait_epoch):
		return
	__sv_started = true
	__spawn_game_start()
	__sv_pending_spawn = false

func __spawn_game_start() -> void:
	if __sv_room_content_id == &"":
		push_error("Dungeon mode has no room content with required tags.")
	else:
		net._sv_spawn(__sv_room_content_id, IGsomNetwork.SpawnLayer.WORLD)
	
	if __sv_controller_content_id == &"":
		push_error("Dungeon mode has no player controller content with required tags.")
		return
	if __sv_pawn_content_id == &"":
		push_error("Dungeon mode has no player pawn content with required tags.")
		return
	
	var peers: Array[IGsomPeer] = net._get_peers_connected()
	for peer: IGsomPeer in peers:
		_sv_peer_join(peer)

func __sv_player_spawn_transform(slot_index: int) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	# RoomLabs has blocking geometry around the origin; spawn in clear space.
	xf.origin = Vector3(-2.0 + float(slot_index) * 1.5, 1.2, 2.0)
	return xf

func __sv_possess_player(player: IGsomPlayer, pawn: IGsomPawn) -> void:
	if !player or !pawn:
		return
	player._sv_possess_pawn(pawn)

func __sv_get_or_create_session(peer_identity: StringName) -> Session:
	if __sv_sessions.has(peer_identity):
		return __sv_sessions[peer_identity]
	var session: Session = Session.new()
	session.peer_identity = peer_identity
	session.slot_index = __sv_next_slot_index
	__sv_next_slot_index += 1
	__sv_sessions[peer_identity] = session
	return session

func __sv_ensure_session_entities(session: Session) -> void:
	var player: IGsomPlayer = __sv_get_session_player(session)
	if !player:
		player = __sv_spawn_controller(session.peer_identity)
		if player:
			session.player_id = player.net_id
	var pawn: IGsomPawn = __sv_get_session_pawn(session)
	if !pawn:
		pawn = __sv_spawn_pawn(session.peer_identity, session.slot_index)
		if pawn:
			session.pawn_id = pawn.net_id
	if player and pawn:
		__sv_possess_player(player, pawn)

func __sv_apply_session_state(session: Session) -> void:
	var player: IGsomPlayer = __sv_get_session_player(session)
	var pawn: IGsomPawn = __sv_get_session_pawn(session)
	if player:
		player._sv_set_reserved(session.reserved)
	if pawn:
		pawn._sv_set_reserved(session.reserved)
	if !session.reserved and player and pawn:
		__sv_possess_player(player, pawn)

func __sv_get_session_player(session: Session) -> IGsomPlayer:
	if session.player_id != IGsomNetwork.NET_ID_EMPTY:
		var by_id: IGsomPlayer = net._get_entity(session.player_id) as IGsomPlayer
		if by_id:
			return by_id
		session.player_id = IGsomNetwork.NET_ID_EMPTY
	var by_peer: IGsomPlayer = net._get_player(session.peer_identity)
	if by_peer:
		session.player_id = by_peer.net_id
	return by_peer

func __sv_get_session_pawn(session: Session) -> IGsomPawn:
	if session.pawn_id == IGsomNetwork.NET_ID_EMPTY:
		return null
	var pawn: IGsomPawn = net._get_entity(session.pawn_id) as IGsomPawn
	if pawn:
		return pawn
	session.pawn_id = IGsomNetwork.NET_ID_EMPTY
	return null

func __sv_spawn_controller(peer_identity: StringName) -> IGsomPlayer:
	var player: IGsomPlayer = net._sv_spawn(
		__sv_controller_content_id,
		IGsomNetwork.SpawnLayer.CONTROLLERS,
		null,
		peer_identity,
	) as IGsomPlayer
	if !player:
		push_error("Dungeon mode failed to spawn controller for peer '%s'." % String(peer_identity))
	return player

func __sv_spawn_pawn(peer_identity: StringName, slot_index: int) -> IGsomPawn:
	var pawn_init_data: Dictionary = {
		"xf": __sv_player_spawn_transform(slot_index),
	}
	var pawn: IGsomPawn = net._sv_spawn(
		__sv_pawn_content_id,
		IGsomNetwork.SpawnLayer.ACTORS,
		pawn_init_data,
		peer_identity,
	) as IGsomPawn
	if !pawn:
		push_error("Dungeon mode failed to spawn pawn for peer '%s'." % String(peer_identity))
	return pawn

func __all_peers_ready(epoch_id: int) -> bool:
	for peer: IGsomPeer in net._get_peers_connected():
		if peer._get_load_epoch() < epoch_id:
			return false
		if peer._get_load_progress() < 1.0:
			return false
	return true

func __pick_content_id(kind: StringName, required_tags: Array[StringName]) -> StringName:
	var query: GsomModQueryFilter = GsomModQueryFilter.new()
	query.kinds = [kind]
	query.tags_all = required_tags.duplicate()
	var options: Array[GsomModContent] = GsomModapi.content_by_query(query)
	if options.is_empty():
		return &""
	return options[0].id

func __build_load_resources() -> Array[StringName]:
	var resources: Array[StringName] = []
	var mode_content: GsomModContent = GsomModapi.content_by_id(content_id)
	if mode_content:
		resources.append_array(GsomModapi.traverse_content(mode_content))
	
	__append_content_resources(__sv_room_content_id, resources)
	__append_content_resources(__sv_controller_content_id, resources)
	__append_content_resources(__sv_pawn_content_id, resources)
	
	return __uniq_resources(resources)

func __append_content_resources(content_id_to_add: StringName, into: Array[StringName]) -> void:
	if content_id_to_add == &"":
		return
	var content: GsomModContent = GsomModapi.content_by_id(content_id_to_add)
	if !content:
		return
	into.append_array(GsomModapi.traverse_content(content))

func __uniq_resources(resources: Array[StringName]) -> Array[StringName]:
	var uniq: Array[StringName] = []
	var seen: Dictionary[StringName, bool] = {}
	for path: StringName in resources:
		if path == &"" or seen.has(path):
			continue
		seen[path] = true
		uniq.append(path)
	return uniq
