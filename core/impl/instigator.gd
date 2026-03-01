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

func _get_kind() -> Kind:
	return __kind

func _get_content_id() -> StringName:
	var content_id: String = __attrs_string.get(&"content_id", "")
	return StringName(content_id)

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

func net_pack_state() -> Dictionary:
	return {
		"identity": String(__identity),
		"kind": int(__kind),
		"label": __label,
		"attrs_int": __attrs_int.duplicate(true),
		"attrs_float": __attrs_float.duplicate(true),
		"attrs_bool": __attrs_bool.duplicate(true),
		"attrs_string": __attrs_string.duplicate(true),
	}

func net_apply_state(state: Dictionary) -> void:
	var identity_v: Variant = state.get("identity", "")
	if typeof(identity_v) == TYPE_STRING or typeof(identity_v) == TYPE_STRING_NAME:
		__identity = identity_v
	var kind_i: int = state.get("kind", int(__kind))
	if kind_i >= int(Kind.PLAYER) and kind_i <= int(Kind.WORLD):
		__kind = Kind.values()[kind_i]
	var label_v: Variant = state.get("label", __label)
	if typeof(label_v) == TYPE_STRING:
		__label = label_v
	__attrs_int = __unpack_attrs_int(state.get("attrs_int", __attrs_int))
	__attrs_float = __unpack_attrs_float(state.get("attrs_float", __attrs_float))
	__attrs_bool = __unpack_attrs_bool(state.get("attrs_bool", __attrs_bool))
	__attrs_string = __unpack_attrs_string(state.get("attrs_string", __attrs_string))

func __unpack_attrs_int(source_v: Variant) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if typeof(source_v) != TYPE_DICTIONARY:
		return out
	var source: Dictionary = source_v
	for key_v: Variant in source.keys():
		if typeof(key_v) != TYPE_STRING and typeof(key_v) != TYPE_STRING_NAME:
			continue
		var value_v: Variant = source[key_v]
		if typeof(value_v) != TYPE_INT:
			continue
		var key: StringName = key_v
		out[key] = value_v
	return out

func __unpack_attrs_float(source_v: Variant) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	if typeof(source_v) != TYPE_DICTIONARY:
		return out
	var source: Dictionary = source_v
	for key_v: Variant in source.keys():
		if typeof(key_v) != TYPE_STRING and typeof(key_v) != TYPE_STRING_NAME:
			continue
		var value_v: Variant = source[key_v]
		if typeof(value_v) != TYPE_FLOAT and typeof(value_v) != TYPE_INT:
			continue
		var key: StringName = key_v
		var value_f: float = value_v
		out[key] = value_f
	return out

func __unpack_attrs_bool(source_v: Variant) -> Dictionary[StringName, bool]:
	var out: Dictionary[StringName, bool] = {}
	if typeof(source_v) != TYPE_DICTIONARY:
		return out
	var source: Dictionary = source_v
	for key_v: Variant in source.keys():
		if typeof(key_v) != TYPE_STRING and typeof(key_v) != TYPE_STRING_NAME:
			continue
		var value_v: Variant = source[key_v]
		if typeof(value_v) != TYPE_BOOL:
			continue
		var key: StringName = key_v
		out[key] = value_v
	return out

func __unpack_attrs_string(source_v: Variant) -> Dictionary[StringName, String]:
	var out: Dictionary[StringName, String] = {}
	if typeof(source_v) != TYPE_DICTIONARY:
		return out
	var source: Dictionary = source_v
	for key_v: Variant in source.keys():
		if typeof(key_v) != TYPE_STRING and typeof(key_v) != TYPE_STRING_NAME:
			continue
		var value_v: Variant = source[key_v]
		if typeof(value_v) != TYPE_STRING and typeof(value_v) != TYPE_STRING_NAME:
			continue
		var key: StringName = key_v
		var value_s: String = value_v
		out[key] = value_s
	return out
