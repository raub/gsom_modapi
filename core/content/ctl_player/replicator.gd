extends IGsomPlayer

signal inventory_changed(item_ids: Array[StringName])

var pawn_id: int = IGsomNetwork.NET_ID_EMPTY

var __sv_reserved: bool = false
var __inventory_item_ids: Array[StringName] = []

func _local_tick(dt: float) -> Variant:
	var ctl: CtlPlayer = target as CtlPlayer
	if !ctl:
		return null
	var input: CtlPlayer.PlayerInput = ctl.controller_local_tick(dt)
	if !input:
		return null
	__apply_input_to_owned_pawn(input)
	var actions: CtlPlayer.PlayerActions = ctl.controller_compose_actions(dt)
	var pawn_state: Variant = __pack_owned_pawn_snapshot()
	if pawn_state != null:
		actions.pawn_state = pawn_state
	_apply_actions(actions)
	return actions

func _apply_actions(actions: Variant) -> void:
	var typed: CtlPlayer.PlayerActions = actions
	if !typed:
		return
	var ctl: CtlPlayer = target as CtlPlayer
	if ctl:
		ctl.controller_apply_actions(typed)

func _sv_peer_update(_peer: IGsomPeer) -> void:
	if !net.check_is_host():
		return
	if _peer._get_identity() != peer_identity:
		return
	__sync_target_pawn()

func _sv_tick(_dt: float) -> void:
	if !net.check_is_host():
		return
	__sv_sync_pawn_link()

func _sv_apply_actions(actions: Variant) -> void:
	if !net.check_is_host():
		return
	__sv_sync_pawn_link()
	if __sv_reserved:
		return
	var typed: CtlPlayer.PlayerActions = actions
	if !typed:
		return
	_apply_actions(typed)
	__sv_apply_owned_pawn_snapshot(typed.pawn_state)

func _cl_tick(_dt: float) -> void:
	__sync_target_pawn()

func _cl_ready() -> void:
	if peer_identity == &"":
		peer_identity = instigator
	var ctl: CtlPlayer = target as CtlPlayer
	if ctl:
		ctl.controller_set_local(check_is_local())
		ctl.controller_set_enabled(!__sv_reserved)
		ctl.controller_set_inventory_ids(__inventory_item_ids)
	__sync_target_pawn()

func _sv_ready() -> void:
	if peer_identity == &"":
		peer_identity = instigator
	__push_inventory_to_controller()
	__sync_target_pawn()

func _read_snapshot(snapshot: Variant) -> void:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return
	var data: Dictionary = snapshot
	var identity_v: Variant = data.get("peer_identity", null)
	if typeof(identity_v) == TYPE_STRING or typeof(identity_v) == TYPE_STRING_NAME:
		peer_identity = identity_v
	var pawn_id_v: Variant = data.get("pawn_id", pawn_id)
	if typeof(pawn_id_v) == TYPE_INT:
		pawn_id = pawn_id_v
	var reserved_v: Variant = data.get("reserved", __sv_reserved)
	if typeof(reserved_v) == TYPE_BOOL:
		__sv_reserved = reserved_v
	var inventory_v: Variant = data.get("inventory_item_ids", __inventory_item_ids)
	__set_inventory_from_variant(inventory_v)
	var ctl: CtlPlayer = target as CtlPlayer
	if ctl:
		var view: Dictionary = {}
		if typeof(data.get("view", null)) == TYPE_DICTIONARY:
			view = data["view"]
		ctl.controller_unpack_snapshot(view, !check_is_local())
		ctl.controller_set_enabled(!__sv_reserved)
	__sync_target_pawn()

func _write_snapshot(_lod: RelevancyLod) -> Variant:
	var ctl: CtlPlayer = target as CtlPlayer
	var view: Dictionary = ctl.controller_pack_snapshot() if ctl else {}
	return {
		"peer_identity": String(peer_identity),
		"pawn_id": pawn_id,
		"reserved": __sv_reserved,
		"inventory_item_ids": __inventory_item_ids.duplicate(),
		"view": view,
	}

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
	__inventory_item_ids.append(item_id_s)
	__emit_inventory_changed()

func _cl_read_event(_e: Event) -> void:
	pass

func _sv_set_reserved(reserved: bool) -> void:
	if !net.check_is_host():
		return
	__sv_reserved = reserved
	var ctl: CtlPlayer = target as CtlPlayer
	if ctl:
		ctl.controller_set_enabled(!reserved)
	var pawn: IGsomPawn = _get_pawn()
	if pawn:
		__call_optional_reserved(pawn, reserved)

func __sync_target_pawn() -> void:
	var ctl: CtlPlayer = target as CtlPlayer
	if !ctl:
		return
	var pawn: IGsomPawn = _get_pawn()
	if !pawn or pawn.target is not Node3D:
		ctl.controller_set_pawn(null)
		return
	ctl.controller_set_pawn(pawn.target as Node3D)

func _get_pawn() -> IGsomPawn:
	if pawn_id == IGsomNetwork.NET_ID_EMPTY:
		return null
	return net._get_entity(pawn_id) as IGsomPawn

func _sv_possess_pawn(pawn: IGsomPawn) -> void:
	if !net.check_is_host():
		return
	if !pawn:
		return
	if pawn.player_id != IGsomNetwork.NET_ID_EMPTY and pawn.player_id != net_id:
		var other_owner: IGsomPlayer = net._get_entity(pawn.player_id) as IGsomPlayer
		if other_owner:
			other_owner._sv_dismiss_pawn()
		else:
			pawn.player_id = IGsomNetwork.NET_ID_EMPTY
	if pawn_id == pawn.net_id:
		if pawn.player_id != net_id:
			pawn.player_id = net_id
		__call_optional_reserved(pawn, __sv_reserved)
		__sync_target_pawn()
		return
	_sv_dismiss_pawn()
	pawn_id = pawn.net_id
	pawn.player_id = net_id
	__call_optional_reserved(pawn, __sv_reserved)
	pawn._sv_posessed()
	__sync_target_pawn()

func _sv_dismiss_pawn() -> void:
	if !net.check_is_host():
		return
	var pawn: IGsomPawn = _get_pawn()
	if pawn:
		pawn._sv_dismissed()
		__call_optional_reserved(pawn, false)
		pawn.player_id = IGsomNetwork.NET_ID_EMPTY
	pawn_id = IGsomNetwork.NET_ID_EMPTY
	__sync_target_pawn()

func __sv_sync_pawn_link() -> void:
	var pawn: IGsomPawn = _get_pawn()
	if !pawn:
		pawn_id = IGsomNetwork.NET_ID_EMPTY
		return
	if pawn.player_id != net_id:
		pawn.player_id = net_id

func __pack_owned_pawn_snapshot() -> Variant:
	var pawn: IGsomPawn = _get_pawn()
	if !pawn:
		return null
	return pawn._write_snapshot(IGsomEntity.RelevancyLod.MAX)

func __apply_input_to_owned_pawn(input: CtlPlayer.PlayerInput) -> void:
	var pawn: IGsomPawn = _get_pawn()
	if !pawn or !pawn.target or !pawn.target.has_method("pawn_apply_actions"):
		return
	pawn.target.call("pawn_apply_actions", input)

func __sv_apply_owned_pawn_snapshot(snapshot: Variant) -> void:
	var pawn: IGsomPawn = _get_pawn()
	if !pawn:
		return
	pawn._read_snapshot(snapshot)

func __call_optional_reserved(entity: IGsomEntity, reserved: bool) -> void:
	if entity and entity.has_method("_sv_set_reserved"):
		entity.call("_sv_set_reserved", reserved)

func __set_inventory_from_variant(raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	var item_ids: Array[StringName] = []
	var values: Array = raw
	for value: Variant in values:
		if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
			continue
		var value_s: StringName = value
		item_ids.append(value_s)
	if __inventory_item_ids == item_ids:
		return
	__inventory_item_ids = item_ids
	__emit_inventory_changed()

func __emit_inventory_changed() -> void:
	inventory_changed.emit(__inventory_item_ids.duplicate())
	__push_inventory_to_controller()

func __push_inventory_to_controller() -> void:
	var ctl: CtlPlayer = target as CtlPlayer
	if !ctl:
		return
	ctl.controller_set_inventory_ids(__inventory_item_ids)
