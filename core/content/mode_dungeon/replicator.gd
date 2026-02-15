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

func _sv_ready() -> void:
	__sv_room_content_id = __pick_content_id(&"room", [__TagDungeon])
	__sv_controller_content_id = __pick_content_id(&"controller", [__TagPlayer, __TagFps])
	__sv_pawn_content_id = __pick_content_id(&"actor", [__TagDungeon, __TagPlayer, &"character"])
	
	__sv_wait_epoch = net.get_local_peer()._get_load_epoch() + 1
	__sv_pending_spawn = true
	__sv_started = false
	
	var resources: Array[StringName] = __build_load_resources()
	net._sv_load_start("dungeon:start", resources)

func _sv_load_start(_label: String) -> void:
	__sv_started = false

func _cl_load_complete() -> void:
	net._cl_load_complete()

func _sv_tick(_dt: float) -> void:
	if !__sv_pending_spawn or __sv_started:
		return
	if !__all_peers_ready(__sv_wait_epoch):
		return
	__spawn_game_start()
	__sv_pending_spawn = false
	__sv_started = true

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
	
	for peer: IGsomPeer in net._get_peers_connected():
		__sv_spawn_player_session(peer._get_identity())

func __sv_spawn_player_session(peer_identity: StringName) -> void:
	var player: IGsomPlayer = net._sv_spawn(
		__sv_controller_content_id,
		IGsomNetwork.SpawnLayer.CONTROLLERS,
		null,
		peer_identity,
	) as IGsomPlayer
	if !player:
		push_error("Dungeon mode failed to spawn controller for peer '%s'." % String(peer_identity))
		return
	var pawn: IGsomPawn = net._sv_spawn(
		__sv_pawn_content_id,
		IGsomNetwork.SpawnLayer.ACTORS,
		null,
		peer_identity,
	) as IGsomPawn
	if !pawn:
		push_error("Dungeon mode failed to spawn pawn for peer '%s'." % peer_identity)
		return
	__sv_possess_player(player, pawn)

func __sv_possess_player(player: IGsomPlayer, pawn: IGsomPawn) -> void:
	if !player or !pawn:
		return
	player._sv_possess_pawn(pawn)

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

func __load_replicator_script(content: GsomModContent) -> Script:
	if !content or content.path_replicator == &"":
		return null
	return load(content.path_replicator) as Script

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
