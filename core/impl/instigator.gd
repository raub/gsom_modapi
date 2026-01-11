extends IGsomInstigator
class_name GsomInstigatorImpl

var __label: String = ""
var __kind: IGsomInstigator.Kind = IGsomInstigator.Kind.WORLD
var __identity: StringName = &""
var __attrs_int: Dictionary[StringName, int] = {}
var __attrs_float: Dictionary[StringName, float] = {}
var __attrs_bool: Dictionary[StringName, bool] = {}
var __attrs_string: Dictionary[StringName, String] = {}

# Mods don't know about this
func net_set_identity(identity: StringName) -> void:
	__identity = identity

# Mods don't know about this
func net_set_kind(kind: IGsomInstigator.Kind) -> void:
	__kind = kind

# Mods don't know about this
func net_set_label(label: String) -> void:
	__label = label

func _sv_set_label(label: String) -> void:
	net._sv_set_instigator_label(__identity, label)

func _get_label() -> String:
	return __label

func _get_identity() -> StringName:
	return __identity

func _sv_set_attr_int(key: StringName, value: int) -> void:
	net._sv_set_instigator_attr_int(__identity, key, value)

func _sv_set_attr_bool(key: StringName, value: bool) -> void:
	net._sv_set_instigator_attr_bool(__identity, key, value)

func _sv_set_attr_string(key: StringName, value: String) -> void:
	net._sv_set_instigator_attr_string(__identity, key, value)

func _sv_set_attr_float(key: StringName, value: float) -> void:
	net._sv_set_instigator_attr_float(__identity, key, value)

# Only called by net service directly
func net_set_attr_int(key: StringName, value: int) -> void:
	__attrs_int.set(key, value)

# Only called by net service directly
func net_set_attr_bool(key: StringName, value: bool) -> void:
	__attrs_bool.set(key, value)

# Only called by net service directly
func net_set_attr_string(key: StringName, value: String) -> void:
	__attrs_string.set(key, value)

# Only called by net service directly
func net_set_attr_float(key: StringName, value: float) -> void:
	__attrs_float.set(key, value)

func _get_attr_int(key: StringName) -> int:
	return __attrs_int.get(key, 0)

func _get_attr_bool(key: StringName) -> bool:
	return __attrs_bool.get(key, false)

func _get_attr_string(key: StringName) -> String:
	return __attrs_string.get(key, "")

func _get_attr_float(key: StringName) -> float:
	return __attrs_float.get(key, 0.0)

func _has_attr_int(key: StringName) -> bool:
	return __attrs_int.has(key)

func _has_attr_bool(key: StringName) -> bool:
	return __attrs_bool.has(key)

func _has_attr_string(key: StringName) -> bool:
	return __attrs_string.has(key)

func _has_attr_float(key: StringName) -> bool:
	return __attrs_float.has(key)
