extends IGsomGameMode

var __sv_wait_epoch: int = 0
var __sv_pending_spawn: bool = false
var __sv_started: bool = false

var __sv_room_content_id: StringName = &""
var __sv_controller_content_id: StringName = &""
var __sv_pawn_content_id: StringName = &""

func _sv_ready() -> void:
	__sv_room_content_id = __pick_content_id(&"room", [&"dungeon"])
	__sv_controller_content_id = __pick_content_id(&"controller", [&"player", &"fps"])
	__sv_pawn_content_id = __pick_content_id(&"actor", [&"dungeon", &"player", &"character"])
	
	__sv_wait_epoch = net.get_local_peer()._get_load_epoch() + 1
	__sv_pending_spawn = true
	__sv_started = false
	
	var resources: Array[StringName] = __build_load_resources()
	net._sv_load_start("dungeon:start", resources)

func _sv_load_start(_label: String) -> void:
	__sv_started = false

func _cl_load_complete() -> void:
	net._cl_load_complete()

func _sv_read_event(peer: IGsomPeer, e: Event) -> void:
	if !net.check_is_host():
		return
	if !peer or peer._get_identity() != net.get_host_identity():
		return
	if !e or e.kind != &"item_picked":
		return
	if typeof(e.data) != TYPE_DICTIONARY:
		return
	var data: Dictionary = e.data
	var item_net_id_v: Variant = data.get("item_net_id", IGsomNetwork.NET_ID_EMPTY)
	if typeof(item_net_id_v) != TYPE_INT:
		return
	var item_net_id: int = item_net_id_v
	if item_net_id == IGsomNetwork.NET_ID_EMPTY:
		return
	net._sv_despawn(item_net_id)

func _sv_peer_join(peer: IGsomPeer) -> void:
	if !peer:
		return
	if !__sv_started:
		return
	if peer._get_connected():
		__sv_ensure_peer_entities(peer._get_identity())
	__sv_apply_peer_state(peer)

func _sv_peer_drop(peer: IGsomPeer) -> void:
	if !peer:
		return
	if !__sv_started:
		return
	__sv_apply_peer_state(peer)

func _sv_peer_update(peer: IGsomPeer) -> void:
	if !peer:
		return
	if !__sv_started:
		return
	if peer._get_connected():
		__sv_ensure_peer_entities(peer._get_identity())
	__sv_apply_peer_state(peer)

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
		__sv_spawn_items_from_selectors.call_deferred()
	
	if __sv_controller_content_id == &"":
		push_error("Dungeon mode has no player controller content with required tags.")
		return
	if __sv_pawn_content_id == &"":
		push_error("Dungeon mode has no player pawn content with required tags.")
		return
	
	var peers: Array[IGsomPeer] = net._get_peers_connected()
	for peer: IGsomPeer in peers:
		_sv_peer_join(peer)

func __sv_spawn_items_from_selectors() -> void:
	var selectors: Array[GsomModSpawnSelector] = GsomModSpawnSelector.find_all(get_tree())
	for selector_node: GsomModSpawnSelector in selectors:
		var content_id_to_spawn: StringName = selector_node.pick_content_id()
		if content_id_to_spawn == &"":
			continue
		prints("spawning", content_id_to_spawn, selector_node.global_transform.origin)
		net._sv_spawn(
			content_id_to_spawn,
			IGsomNetwork.SpawnLayer.WORLD,
			{
				"xf": selector_node.global_transform,
			},
		)

func __sv_player_spawn_transform(slot_index: int) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	# RoomLabs has blocking geometry around the origin; spawn in clear space.
	xf.origin = Vector3(-2.0 + float(slot_index) * 1.5, 1.2, 2.0)
	return xf

func __sv_possess_player(player: IGsomPlayer, pawn: IGsomPawn) -> void:
	if !player or !pawn:
		return
	player._sv_possess_pawn(pawn)

func __sv_ensure_peer_entities(peer_identity: StringName) -> void:
	var player: IGsomPlayer = net._get_player(peer_identity)
	if !player:
		player = __sv_spawn_controller(peer_identity)
	var pawn: IGsomPawn = __sv_get_peer_pawn(peer_identity, player)
	if !pawn:
		var spawn_slot_index: int = net._get_players().size() - 1
		if spawn_slot_index < 0:
			spawn_slot_index = 0
		pawn = __sv_spawn_pawn(peer_identity, spawn_slot_index)
	if player and pawn:
		__sv_possess_player(player, pawn)

func __sv_apply_peer_state(peer: IGsomPeer) -> void:
	var peer_identity: StringName = peer._get_identity()
	var reserved: bool = !peer._get_connected()
	var player: IGsomPlayer = net._get_player(peer_identity)
	var pawn: IGsomPawn = __sv_get_peer_pawn(peer_identity, player)
	if player:
		__sv_call_optional_reserved(player, reserved)
	if pawn:
		__sv_call_optional_reserved(pawn, reserved)
	if !reserved and player and pawn:
		__sv_possess_player(player, pawn)

func __sv_get_peer_pawn(peer_identity: StringName, player: IGsomPlayer = null) -> IGsomPawn:
	if player:
		var owned: IGsomPawn = player._get_pawn()
		if owned:
			return owned
	for entity: IGsomEntity in net._get_entities_by_layer(IGsomNetwork.SpawnLayer.ACTORS):
		var pawn: IGsomPawn = entity as IGsomPawn
		if !pawn:
			continue
		if pawn.instigator == peer_identity:
			return pawn
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

func __sv_call_optional_reserved(entity: IGsomEntity, reserved: bool) -> void:
	if entity and entity.has_method("_sv_set_reserved"):
		entity.call("_sv_set_reserved", reserved)
