extends IGsomPawn

var __sv_reserved: bool = false
var __hp: int = 100
var __ammo_loaded: int = 0
var __ammo_stored: int = 0
var __inventory_item_ids: Array[StringName] = []

func _cl_ready() -> void:
	__apply_spawn_init()
	__apply_reserved_state()

func _sv_ready() -> void:
	__apply_spawn_init()
	__apply_reserved_state()

func _sv_tick(dt: float) -> void:
	if __sv_reserved:
		return
	if player_id != IGsomNetwork.NET_ID_EMPTY and !__check_owned_by_local_player():
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

func _read_snapshot(snapshot: Variant) -> void:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return
	var data: Dictionary = snapshot
	if net.check_is_host():
		if __sv_reserved:
			return
		__apply_motion_snapshot(data)
		return
	var player_id_v: Variant = data.get("player_id", player_id)
	if typeof(player_id_v) == TYPE_INT:
		player_id = player_id_v
	var reserved_v: Variant = data.get("reserved", __sv_reserved)
	if typeof(reserved_v) == TYPE_BOOL:
		__sv_reserved = reserved_v
	__apply_status_snapshot(data)
	__apply_reserved_state()
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	if __check_owned_by_local_player() and !__sv_reserved:
		return
	__apply_motion_snapshot(data)

func _write_snapshot(_lod: RelevancyLod) -> Variant:
	return __pack_snapshot()

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

func _sv_read_event(peer: IGsomPeer, e: Event) -> void:
	if !net.check_is_host():
		return
	if !peer or peer._get_identity() != net.get_host_identity():
		return
	if !e or e.kind != &"give_item":
		return
	if typeof(e.data) != TYPE_DICTIONARY:
		return
	var data: Dictionary = e.data
	var item_id_v: Variant = data.get("item_id", &"")
	if typeof(item_id_v) != TYPE_STRING and typeof(item_id_v) != TYPE_STRING_NAME:
		return
	var item_id_s: StringName = item_id_v
	__add_item(item_id_s)

func get_inventory_item_ids() -> Array[StringName]:
	return __inventory_item_ids.duplicate()

func get_hp() -> int:
	return __hp

func get_ammo_loaded() -> int:
	return __ammo_loaded

func get_ammo_stored() -> int:
	return __ammo_stored

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

func __pack_snapshot() -> Variant:
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return null
	return {
		"player_id": player_id,
		"reserved": __sv_reserved,
		"xf": pawn.global_transform,
		"vel": pawn.velocity,
		"hp": __hp,
		"ammo_loaded": __ammo_loaded,
		"ammo_stored": __ammo_stored,
		"inventory_item_ids": __inventory_item_ids.duplicate(),
	}

func __apply_motion_snapshot(data: Dictionary) -> void:
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	if data.has("xf") and typeof(data["xf"]) == TYPE_TRANSFORM3D:
		pawn.global_transform = data["xf"]
	if data.has("vel") and typeof(data["vel"]) == TYPE_VECTOR3:
		pawn.velocity = data["vel"]

func __apply_status_snapshot(data: Dictionary) -> void:
	var hp_v: Variant = data.get("hp", __hp)
	if typeof(hp_v) == TYPE_INT:
		var hp_i: int = hp_v
		__hp = maxi(0, hp_i)

	var ammo_loaded_v: Variant = data.get("ammo_loaded", __ammo_loaded)
	if typeof(ammo_loaded_v) == TYPE_INT:
		var ammo_loaded_i: int = ammo_loaded_v
		__ammo_loaded = maxi(0, ammo_loaded_i)

	var ammo_stored_v: Variant = data.get("ammo_stored", __ammo_stored)
	if typeof(ammo_stored_v) == TYPE_INT:
		var ammo_stored_i: int = ammo_stored_v
		__ammo_stored = maxi(0, ammo_stored_i)

	var inventory_v: Variant = data.get("inventory_item_ids", __inventory_item_ids)
	if typeof(inventory_v) == TYPE_ARRAY:
		var item_ids: Array[StringName] = []
		var values: Array = inventory_v
		for value: Variant in values:
			if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
				continue
			var value_s: StringName = value
			item_ids.append(value_s)
		__inventory_item_ids = item_ids

func __add_item(item_id: StringName) -> void:
	if item_id == &"":
		return
	__inventory_item_ids.append(item_id)
	var content: GsomModContent = GsomModapi.content_by_id(item_id)
	if content and content.kind == &"weapon":
		__ammo_loaded = 12
		__ammo_stored = 200
