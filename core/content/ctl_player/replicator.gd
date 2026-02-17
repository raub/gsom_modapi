extends IGsomPlayer

const __EventInput: StringName = &"input"

var pawn_id: int = IGsomNetwork.NET_ID_EMPTY

var __sv_actions: CtlPlayer.PlayerActions = null
var __sv_reserved: bool = false

func _local_tick(dt: float) -> Variant:
	if !check_is_local():
		return null
	var ctl: CtlPlayer = target as CtlPlayer
	if !ctl:
		return null
	var actions: CtlPlayer.PlayerActions = ctl.controller_local_tick(dt)
	if !actions:
		return null
	var pawn_state: Variant = __cl_pack_owned_pawn_state()
	if pawn_state != null:
		actions.pawn_state = pawn_state
	actions.dt = dt
	_apply_actions(actions) # local prediction (also host-immediate response)
	if net.check_is_host():
		return actions
	var e: Event = Event.new()
	e.kind = __EventInput
	e.data = actions
	net._cl_send_event(net_id, e)
	return actions

func _apply_actions(actions: Variant) -> void:
	var typed: CtlPlayer.PlayerActions = actions
	if !typed:
		return
	var ctl: CtlPlayer = target as CtlPlayer
	if ctl:
		ctl.controller_apply_actions(typed)
	var pawn: IGsomPawn = _get_pawn()
	if pawn:
		pawn._apply_actions(typed)

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
	if __sv_reserved:
		__sv_actions = null
		return
	if __sv_actions:
		var actions: CtlPlayer.PlayerActions = __sv_actions
		__sv_actions = null
		_apply_actions(actions)
		var pawn: IGsomPawn = _get_pawn()
		if pawn:
			pawn._sv_apply_authority_state(actions.pawn_state)

func _cl_tick(_dt: float) -> void:
	__sync_target_pawn()

func _cl_ready() -> void:
	if peer_identity == &"":
		peer_identity = instigator
	var ctl: CtlPlayer = target as CtlPlayer
	if ctl:
		ctl.controller_set_local(check_is_local())
		ctl.controller_set_enabled(!__sv_reserved)
	__sync_target_pawn()

func _sv_ready() -> void:
	if peer_identity == &"":
		peer_identity = instigator
	__sync_target_pawn()

func _cl_unpack(snapshot: Variant) -> void:
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
	var ctl: CtlPlayer = target as CtlPlayer
	if ctl:
		var view: Dictionary = {}
		if typeof(data.get("view", null)) == TYPE_DICTIONARY:
			view = data["view"]
		ctl.controller_unpack_snapshot(view, !check_is_local())
		ctl.controller_set_enabled(!__sv_reserved)
	__sync_target_pawn()

func _sv_pack(_lod: RelevancyLod) -> Variant:
	var ctl: CtlPlayer = target as CtlPlayer
	var view: Dictionary = ctl.controller_pack_snapshot() if ctl else {}
	return {
		"peer_identity": String(peer_identity),
		"pawn_id": pawn_id,
		"reserved": __sv_reserved,
		"view": view,
	}

func _sv_read_event(_peer: IGsomPeer, _e: Event) -> void:
	if _e.kind != __EventInput:
		return
	if _peer._get_identity() != peer_identity:
		return
	var typed: CtlPlayer.PlayerActions = _e.data
	if !typed:
		return
	__sv_actions = typed

func _cl_read_event(_e: Event) -> void:
	pass

func _sv_set_reserved(reserved: bool) -> void:
	if !net.check_is_host():
		return
	__sv_reserved = reserved
	if reserved:
		__sv_actions = null
	var ctl: CtlPlayer = target as CtlPlayer
	if ctl:
		ctl.controller_set_enabled(!reserved)
	var pawn: IGsomPawn = _get_pawn()
	if pawn:
		pawn._sv_set_reserved(reserved)

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
		pawn._sv_set_reserved(__sv_reserved)
		__sync_target_pawn()
		return
	_sv_dismiss_pawn()
	pawn_id = pawn.net_id
	pawn.player_id = net_id
	pawn._sv_set_reserved(__sv_reserved)
	pawn._sv_posessed()
	__sync_target_pawn()

func _sv_dismiss_pawn() -> void:
	if !net.check_is_host():
		return
	var pawn: IGsomPawn = _get_pawn()
	if pawn:
		pawn._sv_dismissed()
		pawn._sv_set_reserved(false)
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

func __cl_pack_owned_pawn_state() -> Variant:
	var pawn: IGsomPawn = _get_pawn()
	if !pawn:
		return null
	return pawn._cl_pack_authority_state()
