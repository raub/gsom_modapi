extends IGsomPawn

var __sv_reserved: bool = false

func _cl_ready() -> void:
	__apply_spawn_init()
	__apply_reserved_state()

func _sv_ready() -> void:
	__apply_spawn_init()
	__apply_reserved_state()

func _apply_actions(actions: Variant) -> void:
	if typeof(actions) != TYPE_DICTIONARY:
		return
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	var action_dict: Dictionary = actions
	pawn.pawn_apply_actions(action_dict)

func _sv_tick(dt: float) -> void:
	if __sv_reserved:
		return
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	pawn.pawn_tick(dt)

func _cl_tick(dt: float) -> void:
	if net.check_is_host():
		return
	if __sv_reserved:
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
	var player_id_v: Variant = data.get("player_id", player_id)
	if typeof(player_id_v) == TYPE_INT:
		player_id = player_id_v
	var reserved_v: Variant = data.get("reserved", __sv_reserved)
	if typeof(reserved_v) == TYPE_BOOL:
		__sv_reserved = reserved_v
	__apply_reserved_state()
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	if __check_owned_by_local_player() and !__sv_reserved:
		return
	if data.has("xf") and typeof(data["xf"]) == TYPE_TRANSFORM3D:
		pawn.global_transform = data["xf"]
	if data.has("vel") and typeof(data["vel"]) == TYPE_VECTOR3:
		pawn.velocity = data["vel"]

func _sv_pack(_lod: RelevancyLod) -> Variant:
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return null
	return {
		"player_id": player_id,
		"reserved": __sv_reserved,
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

func _sv_set_reserved(reserved: bool) -> void:
	__sv_reserved = reserved
	__apply_reserved_state()

func _cl_pack_authority_state() -> Variant:
	if __sv_reserved:
		return null
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return null
	return {
		"xf": pawn.global_transform,
		"vel": pawn.velocity,
	}

func _sv_apply_authority_state(state: Variant) -> void:
	if __sv_reserved:
		return
	if typeof(state) != TYPE_DICTIONARY:
		return
	var data: Dictionary = state
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	if data.has("xf") and typeof(data["xf"]) == TYPE_TRANSFORM3D:
		pawn.global_transform = data["xf"]
	if data.has("vel") and typeof(data["vel"]) == TYPE_VECTOR3:
		pawn.velocity = data["vel"]

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

func __apply_reserved_state() -> void:
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	pawn.pawn_set_reserved(__sv_reserved)
