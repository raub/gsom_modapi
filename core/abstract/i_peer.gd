extends RefCounted
class_name IPeer

## Base peer - representation of network/lobby client.
##
## Peers are generated and managed by the network service.
## This class reflects the publicly available part of a network peer.
##
## Mods edit the peer data content through `_sv_set_attr_*` (server only).
## And read that data with `_get_attr_*` (on both server and client).
## These are intentionally limited to few easily-serializable data types.

## Is this peer online?
##
## All peers start as valid and connected - that's how they get here.
## But they can become temporarily disconnected, and reconnect.
func _get_connected() -> bool:
	assert(false, "Not implemented")
	return false

## Display name, not stable and not unique, just a label - as provided by system.
##
## I.e. it may get here from Steam or whatever.
## And changing it is beyond what mods can do from this interface.
func _get_label() -> String:
	assert(false, "Not implemented")
	return "Player"

## Stable peer identity key, use this to reliably refer to the same peer.
##
## The host may recognize previously connected peers by `identity`.
## The network implementation can preserve identity past disconnection and crash events.
func _get_identity() -> StringName:
	assert(false, "Not implemented")
	return &""

## Set an integer attribute.
func _sv_set_attr_int(_key: StringName, _value: int) -> void:
	assert(false, "Not implemented")

## Set a boolean attribute.
func _sv_set_attr_bool(_key: StringName, _value: bool) -> void:
	assert(false, "Not implemented")

## Set a string attribute.
func _sv_set_attr_string(_key: StringName, _value: String) -> void:
	assert(false, "Not implemented")

## Set a float attribute.
func _sv_set_attr_float(_key: StringName, _value: float) -> void:
	assert(false, "Not implemented")

func _get_attr_int(_key: StringName) -> int:
	assert(false, "Not implemented")
	return 0

func _get_attr_bool(_key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

func _get_attr_string(_key: StringName) -> String:
	assert(false, "Not implemented")
	return ""

func _get_attr_float(_key: StringName) -> float:
	assert(false, "Not implemented")
	return 0
