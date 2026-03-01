extends IGsomPawn

const __EventWeaponFireFx: StringName = &"weapon_fire_fx"

var __sv_reserved: bool = false
var __hp: int = 100
var __ammo_loaded: int = 0
var __ammo_stored: int = 0
var __inventory_item_ids: Array[StringName] = []
var __equipped_weapon_component: GsomComponentWeapon = null

func _cl_ready() -> void:
	__apply_spawn_init()
	__apply_reserved_state()
	__sync_world_weapon_visual()

func _sv_ready() -> void:
	__apply_spawn_init()
	__apply_reserved_state()
	__sync_world_weapon_visual()

func _sv_tick(dt: float) -> void:
	__sync_world_weapon_visual()
	if __sv_reserved:
		return
	if player_id != IGsomNetwork.NET_ID_EMPTY and !__check_owned_by_local_player():
		return
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	pawn.pawn_tick(dt)
	__tick_local_weapon_fire(pawn)

func _cl_tick(dt: float) -> void:
	__sync_world_weapon_visual()
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
	__tick_local_weapon_fire(pawn)

func _read_snapshot(snapshot: Variant) -> void:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return
	var data: Dictionary = snapshot
	if net.check_is_host():
		if __sv_reserved:
			return
		__apply_motion_snapshot(data)
		__apply_client_owned_status_snapshot(data)
		return
	var player_id_v: Variant = data.get("player_id", player_id)
	if typeof(player_id_v) == TYPE_INT:
		player_id = player_id_v
	var reserved_v: Variant = data.get("reserved", __sv_reserved)
	if typeof(reserved_v) == TYPE_BOOL:
		__sv_reserved = reserved_v
	__apply_status_snapshot(data)
	__apply_reserved_state()
	__sync_world_weapon_visual()
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
	if !e:
		return
	if e.kind == &"give_item":
		__sv_read_event_give_item(peer, e)
		return
	if e.kind == &"apply_damage":
		__sv_read_event_apply_damage(peer, e)
		return
	if e.kind == __EventWeaponFireFx:
		__sv_read_event_weapon_fire_fx(peer)
		return

func _cl_read_event(e: Event) -> void:
	if !e:
		return
	if e.kind == __EventWeaponFireFx:
		__play_world_weapon_fire_fx()

func __sv_read_event_give_item(peer: IGsomPeer, e: Event) -> void:
	if !peer or peer._get_identity() != net.get_host_identity():
		return
	if typeof(e.data) != TYPE_DICTIONARY:
		return
	var data: Dictionary = e.data
	var item_id_v: Variant = data.get("item_id", &"")
	if typeof(item_id_v) != TYPE_STRING and typeof(item_id_v) != TYPE_STRING_NAME:
		return
	var ammo_loaded_override: int = -1
	var ammo_loaded_v: Variant = data.get("ammo_loaded", null)
	if typeof(ammo_loaded_v) == TYPE_INT:
		var ammo_loaded_i: int = ammo_loaded_v
		ammo_loaded_override = maxi(0, ammo_loaded_i)
	var ammo_stored_override: int = -1
	var ammo_stored_v: Variant = data.get("ammo_stored", null)
	if typeof(ammo_stored_v) == TYPE_INT:
		var ammo_stored_i: int = ammo_stored_v
		ammo_stored_override = maxi(0, ammo_stored_i)
	var item_id_s: StringName = item_id_v
	__add_item(item_id_s, ammo_loaded_override, ammo_stored_override)

func __sv_read_event_apply_damage(peer: IGsomPeer, e: Event) -> void:
	if !peer:
		return
	if typeof(e.data) != TYPE_DICTIONARY:
		return
	var data: Dictionary = e.data
	var amount_v: Variant = data.get("amount", 0.0)
	if typeof(amount_v) != TYPE_FLOAT and typeof(amount_v) != TYPE_INT:
		return
	var amount: float = amount_v
	var source_net_id: int = IGsomNetwork.NET_ID_EMPTY
	var source_net_id_v: Variant = data.get("source_net_id", source_net_id)
	if typeof(source_net_id_v) == TYPE_INT:
		source_net_id = source_net_id_v
	if !__check_peer_owns_source_pawn(peer, source_net_id):
		return
	_sv_apply_damage(amount, source_net_id)

func __sv_read_event_weapon_fire_fx(peer: IGsomPeer) -> void:
	if !peer:
		return
	if !__check_peer_owns_source_pawn(peer, net_id):
		return
	__broadcast_world_weapon_fire_fx()

func get_inventory_item_ids() -> Array[StringName]:
	return __inventory_item_ids.duplicate()

func get_hp() -> int:
	return __hp

func get_ammo_loaded() -> int:
	return __ammo_loaded

func get_ammo_stored() -> int:
	return __ammo_stored

func _sv_apply_damage(amount: float, _source_net_id: int = IGsomNetwork.NET_ID_EMPTY) -> void:
	if !net.check_is_host():
		return
	if amount <= 0.0:
		return
	var amount_i: int = maxi(0, int(ceilf(amount)))
	if amount_i <= 0:
		return
	__hp = maxi(0, __hp - amount_i)

func __check_peer_owns_source_pawn(peer: IGsomPeer, source_pawn_net_id: int) -> bool:
	if source_pawn_net_id == IGsomNetwork.NET_ID_EMPTY:
		return true
	var source_pawn: IGsomPawn = net._get_entity(source_pawn_net_id) as IGsomPawn
	if !source_pawn:
		return false
	if source_pawn.player_id == IGsomNetwork.NET_ID_EMPTY:
		return false
	var source_player: IGsomPlayer = net._get_entity(source_pawn.player_id) as IGsomPlayer
	if !source_player:
		return false
	return source_player.peer_identity == peer._get_identity()

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
	__sync_equipped_weapon_component()
	__sync_world_weapon_visual()

func __apply_client_owned_status_snapshot(data: Dictionary) -> void:
	var ammo_loaded_v: Variant = data.get("ammo_loaded", __ammo_loaded)
	if typeof(ammo_loaded_v) == TYPE_INT:
		var ammo_loaded_i: int = ammo_loaded_v
		__ammo_loaded = maxi(0, ammo_loaded_i)

	var ammo_stored_v: Variant = data.get("ammo_stored", __ammo_stored)
	if typeof(ammo_stored_v) == TYPE_INT:
		var ammo_stored_i: int = ammo_stored_v
		__ammo_stored = maxi(0, ammo_stored_i)

func __add_item(
	item_id: StringName,
	ammo_loaded_override: int = -1,
	ammo_stored_override: int = -1,
) -> void:
	if item_id == &"":
		return
	__inventory_item_ids.append(item_id)
	if ammo_loaded_override >= 0:
		__ammo_loaded = maxi(0, ammo_loaded_override)
	if ammo_stored_override >= 0:
		__ammo_stored = maxi(0, ammo_stored_override)
	__sync_equipped_weapon_component()
	__sync_world_weapon_visual()

func __tick_local_weapon_fire(pawn: CharPlayer) -> void:
	__sync_equipped_weapon_component()
	if !__equipped_weapon_component:
		return
	var ammo_loaded_before: int = __ammo_loaded
	var ammo_state_in: Dictionary = {
		"ammo_loaded": __ammo_loaded,
		"ammo_stored": __ammo_stored,
	}
	var ammo_state_v: Variant = __equipped_weapon_component.post_frame(
		self,
		pawn,
		ammo_state_in,
	)
	if typeof(ammo_state_v) != TYPE_DICTIONARY:
		return
	var ammo_state: Dictionary = ammo_state_v
	var ammo_loaded_v: Variant = ammo_state.get("ammo_loaded", __ammo_loaded)
	if typeof(ammo_loaded_v) == TYPE_INT:
		var ammo_loaded_i: int = ammo_loaded_v
		__ammo_loaded = maxi(0, ammo_loaded_i)
	var ammo_stored_v: Variant = ammo_state.get("ammo_stored", __ammo_stored)
	if typeof(ammo_stored_v) == TYPE_INT:
		var ammo_stored_i: int = ammo_stored_v
		__ammo_stored = maxi(0, ammo_stored_i)
	if __ammo_loaded < ammo_loaded_before:
		__play_world_weapon_fire_fx()
		if net.check_is_host():
			__broadcast_world_weapon_fire_fx()
		else:
			var fire_event: Event = Event.new()
			fire_event.kind = __EventWeaponFireFx
			net._cl_send_event(net_id, fire_event)

func __sync_equipped_weapon_component() -> void:
	var controller: CtlPlayer = __get_owner_controller()
	if !controller:
		__equipped_weapon_component = null
		return
	__equipped_weapon_component = controller.controller_get_equipped_weapon_component()

func __get_owner_controller() -> CtlPlayer:
	if player_id == IGsomNetwork.NET_ID_EMPTY:
		return null
	var player: IGsomPlayer = net._get_entity(player_id) as IGsomPlayer
	if !player:
		return null
	if player.target is not CtlPlayer:
		return null
	return player.target as CtlPlayer

func __sync_world_weapon_visual() -> void:
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	var is_local_owned: bool = __check_owned_by_local_player()
	pawn.pawn_set_local_owned(is_local_owned)
	var equipped_item_id: StringName = &""
	if !__inventory_item_ids.is_empty():
		equipped_item_id = __inventory_item_ids[__inventory_item_ids.size() - 1]
	pawn.pawn_set_world_weapon_item(equipped_item_id, is_local_owned)

func __play_world_weapon_fire_fx() -> void:
	var pawn: CharPlayer = target as CharPlayer
	if !pawn:
		return
	pawn.pawn_play_world_weapon_flash()

func __broadcast_world_weapon_fire_fx() -> void:
	if !net.check_is_host():
		return
	var fire_event: Event = Event.new()
	fire_event.kind = __EventWeaponFireFx
	net._sv_send_event(net_id, fire_event)
