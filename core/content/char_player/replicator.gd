extends IGsomPawn

func _cl_ready() -> void:
	__apply_spawn_init()

func _sv_ready() -> void:
	__apply_spawn_init()

func _apply_actions(actions: Variant) -> void:
	if typeof(actions) != TYPE_DICTIONARY:
		return
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	var action_dict: Dictionary = actions
	pawn.pawn_apply_actions(action_dict)

func _sv_tick(dt: float) -> void:
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	pawn.pawn_tick(dt)

func _cl_tick(dt: float) -> void:
	if net.check_is_host():
		return
	if !__check_owned_by_local_player():
		return
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	pawn.pawn_tick(dt)

func _cl_unpack(snapshot: Variant) -> void:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return
	var data: Dictionary = snapshot
	player_id = data.get("player_id", player_id)
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	if __check_owned_by_local_player():
		return
	if data.has("xf"):
		pawn.global_transform = data["xf"]
	if data.has("vel"):
		pawn.velocity = data["vel"]

func _sv_pack(_lod: RelevancyLod) -> Variant:
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return null
	return {
		"player_id": player_id,
		"xf": pawn.global_transform,
		"vel": pawn.velocity,
	}

func _sv_posessed() -> void:
	var pawn: CharPlayer = target as CharPlayer
	if pawn:
		pawn.pawn_reset_actions()

func _sv_dismissed() -> void:
	var pawn: CharPlayer = target as CharPlayer
	if pawn:
		pawn.pawn_reset_actions()

func __check_owned_by_local_player() -> bool:
	if player_id == IGsomNetwork.NET_ID_EMPTY:
		return false
	var player: IGsomPlayer = net._get_entity(player_id) as IGsomPlayer
	if !player:
		return false
	return player.check_is_local()

func __apply_spawn_init() -> void:
	if typeof(init_data) != TYPE_DICTIONARY:
		return
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	var data: Dictionary = init_data
	if data.has("xf") and typeof(data["xf"]) == TYPE_TRANSFORM3D:
		pawn.global_transform = data["xf"]
