extends IGsomPeer
class_name GsomPeerImpl

var id: int = IGsomNetwork.NET_ID_EMPTY

var __instigator: GsomInstigatorImpl = null
var __connected: bool = true

# Mods don't know about this
func net_set_instigator(instigator: GsomInstigatorImpl) -> void:
	__instigator = instigator

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
