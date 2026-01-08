@tool
extends Resource
class_name GsomModContent

const ModUtils = preload("../helpers/mod_utils.gd")

func _property_can_revert(_property: StringName) -> bool:
	return true

func _property_get_revert(property: StringName) -> Variant:
	if property == "tags":
		return _get_default_tags()
	if property == "attrs":
		return _get_default_attrs()
	if property == "caps":
		return _get_default_caps()
	if property in ["ui_title", "ui_tooltip", "ui_summary", "ui_description"]:
		return ""
	if property == "key":
		return &""
	if property == "key_weight":
		return 1.0
	return null

## Assigned by Modapi during registration
var id: StringName

## Assigned by Modapi during registration
var mod: StringName

## Readonly content kind, based on `_get_kind()`
var kind: StringName:
	get: return _get_kind()

## Redefine this in subclasses
func _get_kind() -> StringName:
	return &"unknown"

@export_category("Discoverability")

## Unique name of the content.
##
## Mods can directly override this name to deprecate and replace the old content.
@export var key: StringName = &""

## Content sorting factor - i.e. "version".
##
## The content with identical key and more weight - wins.
@export var key_weight: float = 1.0

## Classify by topic, tone, or function to make content easily searchable.
##
## A list generalized names and references - what is it like, what is it for?
@export var tags: Array[StringName]:
	get: return __get_tags()
	set(v): __set_tags(v)

## Attribute values.
##
## Something you can compare against and sort by.
## Similar to tags but more quantifiable.
@export var attrs: Dictionary[StringName, Variant]:
	get: return __get_attrs()
	set(v): __set_attrs(v)

## Capabilities - compatibility contracts.
##
## E.g. things that have a transform, or can be equipped, or stored to inventory.
@export var caps: Array[StringName]:
	get: return __get_caps()
	set(v): __set_caps(v)

@export_category("UI Display")

## Displayable content name
@export var ui_title: String = ""

## Short tooltip, shown on hover
@export_multiline var ui_tooltip: String = ""

## Short description, 1–2 lines
@export_multiline var ui_summary: String = ""

## Detailed description
@export_multiline var ui_description: String = ""

## Icon for lists/slots/buttons
@export var ui_icon: Texture2D = null

## A preview thumbnail image
@export var ui_thumbnail: Texture2D = null

## Any preview scene for UI purposes
@export var ui_preview: PackedScene = null

@export_category("Instantiation")

## This is the default representation of this content
@export var scene: PackedScene = null

## For network replication, include the replicator script reference.
##
## This is separated from scene because it may have its own class-specific script.
@export var replicator: GDScript = null

const __empty_array: Array[StringName] = []
const __empty_dict: Dictionary[StringName, Variant] = {}

# Cached value that prevents creating new arrays on every get
var __tags_cache: Array[StringName] = __empty_array

# Combines defaults with custom ones
func __get_tags() -> Array[StringName]:
	if __tags_cache.size():
		return __tags_cache
	return _get_default_tags()

# Cache modified tags. Or revert to default after deletions
func __set_tags(v: Array[StringName]) -> void:
	var default_tags: Array[StringName] = _get_default_tags()
	
	var uniq_tags: Array[StringName] = default_tags.duplicate()
	uniq_tags.append_array(v)
	uniq_tags = ModUtils.array_uniq_string_name(uniq_tags)
	
	if uniq_tags.size() > default_tags.size():
		__tags_cache = uniq_tags
	else:
		__tags_cache = __empty_array

## Redefine this in subclasses
func _get_default_tags() -> Array[StringName]:
	return __empty_array

# Cached value that prevents creating new objects on every get
var __attrs_cache: Dictionary[StringName, Variant] = {}

# Combines defaults with custom ones
func __get_attrs() -> Dictionary[StringName, Variant]:
	if __attrs_cache.size():
		return __attrs_cache
	return _get_default_attrs()

# Stores only the custom values
func __set_attrs(v: Dictionary[StringName, Variant]) -> void:
	var default_attrs: Dictionary[StringName, Variant] = _get_default_attrs()
	
	var diff: Dictionary[StringName, Variant] = {}
	for key: StringName in v:
		if !default_attrs.has(key) or default_attrs[key] != v[key]:
			diff[key] = v[key]
	
	if diff.size():
		var new_attrs = default_attrs.duplicate()
		new_attrs.merge(diff, true)
		__attrs_cache = new_attrs
	else:
		__attrs_cache = __empty_dict


## Redefine this in subclasses
func _get_default_attrs() -> Dictionary[StringName, Variant]:
	return __empty_dict

# Custom caps stored privately. These are on top of the default ones.
var __caps_cache: Array[StringName] = __empty_array

# Combines defaults with custom ones
func __get_caps() -> Array[StringName]:
	if __caps_cache.size():
		return __caps_cache
	return _get_default_caps()

# Stores only the custom values
func __set_caps(v: Array[StringName]) -> void:
	var default_caps: Array[StringName] = _get_default_caps()
	
	var uniq_caps: Array[StringName] = default_caps.duplicate()
	uniq_caps.append_array(v)
	uniq_caps = ModUtils.array_uniq_string_name(uniq_caps)
	
	if uniq_caps.size() > default_caps.size():
		__caps_cache = uniq_caps
	else:
		__caps_cache = __empty_array

## Redefine this in subclasses
func _get_default_caps() -> Array[StringName]:
	return __empty_array

# QoL helpers

## Does this tag present?
func has_tag(tag: StringName) -> bool:
	return __get_tags().has(tag)

## Does it has this capability?
func has_cap(cap: StringName) -> bool:
	return __get_caps().has(cap)

## If attribute exists
func has_attr(attr: StringName) -> bool:
	return __get_attrs().has(attr)

## Get attribute value or default
func get_attr(key: StringName, default: Variant = null):
	return __get_attrs().get(key, default)
