extends IGsomPlayer

const __EventInput: StringName = &"input"

var pawn_id: int = IGsomNetwork.NET_ID_EMPTY

var __sv_actions: Dictionary = {}
var __local_actions_host: Dictionary = {}

func _local_tick(dt: float) -> Variant:
	if !check_is_local():
		return null
	var ctl: CtlPlayer = target as CtlPlayer
	if !ctl:
		return null
	var actions: Dictionary = ctl.controller_local_tick(dt)
	if actions.is_empty():
		return null
	actions["dt"] = dt
	__local_actions_host = actions
	if net.check_is_host():
		return actions
	_apply_actions(actions) # client prediction
	var e: Event = Event.new()
	e.kind = __EventInput
	e.data = actions
	net._cl_send_event(net_id, e)
	return actions

func _apply_actions(actions: Variant) -> void:
	if typeof(actions) != TYPE_DICTIONARY:
		return
	var actions_dict: Dictionary = actions
	var ctl: CtlPlayer = target as CtlPlayer
	if ctl:
		ctl.controller_apply_actions(actions_dict)
	var pawn: IGsomPawn = _get_pawn()
	if pawn:
		pawn._apply_actions(actions_dict)

func _sv_peer_update(_peer: IGsomPeer) -> void:
	if !net.check_is_host():
		return
	if _peer._get_identity() != peer_identity:
		return
	if !_peer._get_connected():
		_sv_dismiss_pawn()
		return

func _sv_tick(_dt: float) -> void:
	if !net.check_is_host():
		return
	__sv_sync_pawn_link()
	if check_is_local() and !__local_actions_host.is_empty():
		__sv_actions = __local_actions_host
		__local_actions_host = {}
	if !__sv_actions.is_empty():
		_apply_actions(__sv_actions)
		__sv_actions = {}

func _cl_tick(_dt: float) -> void:
	__sync_target_pawn()

func _cl_ready() -> void:
	if peer_identity == &"":
		peer_identity = instigator
	var ctl: CtlPlayer = target as CtlPlayer
	if ctl:
		ctl.controller_set_local(check_is_local())
	__sync_target_pawn()

func _sv_ready() -> void:
	if peer_identity == &"":
		peer_identity = instigator
	__sync_target_pawn()

func _cl_unpack(snapshot: Variant) -> void:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return
	var data: Dictionary = snapshot
	if data.has("peer_identity"):
		peer_identity = data["peer_identity"]
	pawn_id = data.get("pawn_id", pawn_id)
	var ctl: CtlPlayer = target as CtlPlayer
	if ctl:
		var view: Dictionary = {}
		if typeof(data.get("view", null)) == TYPE_DICTIONARY:
			view = data["view"]
		ctl.controller_unpack_snapshot(view, !check_is_local())
	__sync_target_pawn()

func _sv_pack(_lod: RelevancyLod) -> Variant:
	var ctl: CtlPlayer = target as CtlPlayer
	var view: Dictionary = ctl.controller_pack_snapshot() if ctl else {}
	return {
		"peer_identity": String(peer_identity),
		"pawn_id": pawn_id,
		"view": view,
	}

func _sv_read_event(_peer: IGsomPeer, _e: Event) -> void:
	if _e.kind != __EventInput:
		return
	if _peer._get_identity() != peer_identity:
		return
	if typeof(_e.data) != TYPE_DICTIONARY:
		return
	__sv_actions = _e.data

func _cl_read_event(_e: Event) -> void:
	pass

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
	if pawn_id == pawn.net_id:
		if pawn.player_id != net_id:
			pawn.player_id = net_id
		__sync_target_pawn()
		return
	_sv_dismiss_pawn()
	pawn_id = pawn.net_id
	pawn.player_id = net_id
	pawn._sv_posessed()
	__sync_target_pawn()

func _sv_dismiss_pawn() -> void:
	if !net.check_is_host():
		return
	var pawn: IGsomPawn = _get_pawn()
	if pawn:
		pawn._sv_dismissed()
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
