extends IGsomPeer
class_name GsomPeerImpl

var id: int = IGsomNetwork.NET_ID_EMPTY

var __instigator: GsomInstigatorImpl = null
var __connected: bool = true

var __epoch_id: int = 0
var __progress: float = 0

# "net_" - Mods don't know about this

func net_set_instigator(instigator: GsomInstigatorImpl) -> void:
	__instigator = instigator

func net_set_load_epoch(epoch_id: int) -> void:
	__epoch_id = epoch_id

func net_set_load_progress(progress: float) -> void:
	__progress = progress

func net_set_connected(connected: bool) -> void:
	__connected = connected

func _get_id() -> int:
	return id

func _get_connected() -> bool:
	return __connected

func net_set_label(label: String) -> void:
	__instigator.net_set_label(label)

func _sv_set_label(label: String) -> void:
	__instigator._sv_set_label(label)

func _get_label() -> String:
	return __instigator._get_label()

func _get_identity() -> StringName:
	return __instigator._get_identity()

func _sv_set_attr_int(key: StringName, value: int) -> void:
	__instigator._sv_set_attr_int(key, value)

func _sv_set_attr_bool(key: StringName, value: bool) -> void:
	__instigator._sv_set_attr_bool(key, value)

func _sv_set_attr_string(key: StringName, value: String) -> void:
	__instigator._sv_set_attr_string(key, value)

func _sv_set_attr_float(key: StringName, value: float) -> void:
	__instigator._sv_set_attr_float(key, value)

func net_set_attr_int(key: StringName, value: int) -> void:
	__instigator.net_set_attr_int(key, value)

func net_set_attr_bool(key: StringName, value: bool) -> void:
	__instigator.net_set_attr_bool(key, value)

func net_set_attr_string(key: StringName, value: String) -> void:
	__instigator.net_set_attr_string(key, value)

func net_set_attr_float(key: StringName, value: float) -> void:
	__instigator.net_set_attr_float(key, value)

func _get_attr_int(key: StringName) -> int:
	return __instigator._get_attr_int(key)

func _get_attr_bool(key: StringName) -> bool:
	return __instigator._get_attr_bool(key)

func _get_attr_string(key: StringName) -> String:
	return __instigator._get_attr_string(key)

func _get_attr_float(key: StringName) -> float:
	return __instigator._get_attr_float(key)

func _has_attr_int(key: StringName) -> bool:
	return __instigator._has_attr_int(key)

func _has_attr_bool(key: StringName) -> bool:
	return __instigator._has_attr_bool(key)

func _has_attr_string(key: StringName) -> bool:
	return __instigator._has_attr_string(key)

func _has_attr_float(key: StringName) -> bool:
	return __instigator._has_attr_float(key)

func _get_load_epoch() -> int:
	return __epoch_id

func _get_load_progress() -> float:
	return __progress

func net_pack_state() -> Dictionary:
	return {
		"identity": String(_get_identity()),
		"id": id,
		"connected": __connected,
		"load_epoch": __epoch_id,
		"load_progress": __progress,
	}

func net_apply_state(state: Dictionary) -> void:
	var id_v: Variant = state.get("id", id)
	if typeof(id_v) == TYPE_INT:
		id = id_v
	var connected_v: Variant = state.get("connected", __connected)
	if typeof(connected_v) == TYPE_BOOL:
		__connected = connected_v
	var epoch_v: Variant = state.get("load_epoch", __epoch_id)
	if typeof(epoch_v) == TYPE_INT:
		__epoch_id = epoch_v
	var progress_v: Variant = state.get("load_progress", __progress)
	if typeof(progress_v) == TYPE_FLOAT or typeof(progress_v) == TYPE_INT:
		var progress_f: float = progress_v
		__progress = clampf(progress_f, 0.0, 1.0)
