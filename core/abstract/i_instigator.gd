extends RefCounted
class_name IGsomInstigator

## Base instigator - indirection for loggable entity descriptions.
##
## This is what **Core implements**.
## I.e. opposed to IGsomEntity implementations, shipped by mods.
##
## Instigators are generated and managed by the network service (`_sv_register_instigator`).
## This class reflects the publicly available part of an instigator.
##
## Mods edit the attributes content through `_sv_set_attr_*` (server only).
## And read that data with `_get_attr_*` (on both server and client).
##
## - Identified by what `_get_identity` returns.
## - Can store easily serializable attributes.
## - Intentionally limited to few easily-serializable data types.
## - All attribute types are stored and queried separately, no coercion.
##
## This description persists beyond lifetime of entities.
## The attributes can be stored according to `IGsomIdentified` interface.
##
## Example: a monster throws a grenade and then despawns, later the grenade kills player.
## Now, who killed the player? The persistent indirect instigators are to the rescue.
##
## Note, guideline keywords:
## - [readonly] - if you mutate it, you will face a terrible fate.
## - [core] - it is safe to assume the Core has implemented it.
## - [server] - calling it from non-host will have no effect.

enum Kind {
	PLAYER, AI, WORLD,
}

## [readonly core] A reference to the global Network service.
##
## Injected when this object is being created - before any possible member call.
var net: IGsomNetwork = null

## [core] Source archetype of the instigator - to simplify filtering.
##
## I.e. it may get here from Steam or whatever.
## And changing it is beyond what mods can do from this interface.
func _get_kind() -> Kind:
	assert(false, "Not implemented")
	return Kind.WORLD

## [core] Display label, not stable and not unique, just a label for UI.
func _get_label() -> String:
	assert(false, "Not implemented")
	return ""

## [core server] Update label. Server-only.
func _sv_set_label(_label: String) -> void:
	assert(false, "Not implemented")

## [core] From which mod content the instigator was created.
##
## Not necessarily the same content, but the UI will take texts and icons from there.
## You might as well have special content items for this purpose.
func _get_content_id() -> StringName:
	assert(false, "Not implemented")
	return &""

## [core] Stable identity key, use this to reliably refer to the same item.
func _get_identity() -> StringName:
	assert(false, "Not implemented")
	return &""

## [core server] Set an integer attribute.
##
## This is equivalent for calling `net._sv_set_instigator_attr_int`.
## 
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_attr_int(_key: StringName, _value: int) -> void:
	assert(false, "Not implemented")

## [core server] Set a boolean attribute.
##
## This is equivalent for calling `net._sv_set_instigator_attr_bool`.
## 
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_attr_bool(_key: StringName, _value: bool) -> void:
	assert(false, "Not implemented")

## [core server] Set a string attribute.
##
## This is equivalent for calling `net._sv_set_instigator_attr_string`.
## 
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_attr_string(_key: StringName, _value: String) -> void:
	assert(false, "Not implemented")

## [core server] Set a float attribute.
##
## This is equivalent for calling `net._sv_set_instigator_attr_float`.
## 
## Note: on host, this is effective immediately.
## The clients will receive a reliable broadcast later.
func _sv_set_attr_float(_key: StringName, _value: float) -> void:
	assert(false, "Not implemented")

## [core] Get an integer attribute. Default - `0`.
##
## This is equivalent for calling `net._get_instigator_attr_int`.
func _get_attr_int(_key: StringName) -> int:
	assert(false, "Not implemented")
	return 0

## [core] Get a boolean attribute. Default - `false`.
##
## This is equivalent for calling `net._get_instigator_attr_bool`.
func _get_attr_bool(_key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

## [core] Get a string attribute. Default - `""`.
##
## This is equivalent for calling `net._get_instigator_attr_string`.
func _get_attr_string(_key: StringName) -> String:
	assert(false, "Not implemented")
	return ""

## [core] Get a float attribute. Default - `0.0`.
##
## This is equivalent for calling `net._get_instigator_attr_float`.
func _get_attr_float(_key: StringName) -> float:
	assert(false, "Not implemented")
	return 0

## [core] Check if an integer attribute exists.
##
## This is equivalent for calling `net._has_instigator_attr_int`.
func _has_attr_int(_key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

## [core] Check if a boolean attribute exists.
##
## This is equivalent for calling `net._has_instigator_attr_bool`.
func _has_attr_bool(_key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

## [core] Check if a string attribute exists.
##
## This is equivalent for calling `net._has_instigator_attr_string`.
func _has_attr_string(_key: StringName) -> bool:
	assert(false, "Not implemented")
	return false

## [core] Check if a float attribute exists.
##
## This is equivalent for calling `net._has_instigator_attr_float`.
func _has_attr_float(_key: StringName) -> bool:
	assert(false, "Not implemented")
	return false
