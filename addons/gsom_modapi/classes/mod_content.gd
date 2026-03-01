@tool
extends Resource
class_name GsomModContent

## Base class for mod content.
##
## All game content can be shipped by mods. This is the 
##
## Note, guideline keywords:
## - [readonly] - if you mutate it, you will face a terrible fate.
## - [core] - it is safe to assume the Core has implemented it.
## - [required] - there is no "default" implementation.
## - [optional] - it's ok to omit implementation.

const ModUtils = preload("../helpers/mod_utils.gd")
const TEXT_TITLE: StringName = &"title"
const TEXT_TOOLTIP: StringName = &"tooltip"
const TEXT_SUMMARY: StringName = &"summary"
const TEXT_DESCRIPTION: StringName = &"description"
const PATH_ICON: StringName = &"icon"
const PATH_THUMBNAIL: StringName = &"thumbnail"
const PATH_PREVIEW: StringName = &"preview"
const PATH_SCENE: StringName = &"scene"
const PATH_REPLICATOR: StringName = &"replicator"

# Fix editor revert buttons
func _property_can_revert(_property: StringName) -> bool:
	return true

var __strn_props: Array[StringName] = [
	"key",
]

# Fix revert behavior for arrays
func _property_get_revert(property: StringName) -> Variant:
	if property == "tags":
		return _get_default_tags()
	if property == "attrs":
		return _get_default_attrs()
	if property == "caps":
		return _get_default_caps()
	if property in __strn_props:
		return &""
	if property == "texts":
		return _get_default_texts()
	if property == "paths":
		return _get_default_paths()
	if property == "key_weight":
		return 1.0
	if property == "deps":
		return __empty_array_query
	return null

## [readonly core] Assigned by Modapi during registration
var id: StringName

## [readonly core] Assigned by Modapi during registration
var mod: StringName

## [readonly] Readonly content kind, based on `_get_kind()`
var kind: StringName:
	get: return _get_kind()

## [required] Redefine this in subclasses
func _get_kind() -> StringName:
	return &"unknown"

@export_category("Query Search")

## Unique name of the content.
##
## Mods can directly override this name to deprecate and replace content.
@export var key: StringName = &""

## Content sorting factor - i.e. "version".
##
## The content with identical key and more weight - wins.
@export var key_weight: float = 1.0

## Classify by topic, tone, or function to make content easily searchable.
##
## A list of generalized names and references - what is it like, what is it for?
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

@export_category("Payload")

## Arbitrary text slots used by this content.
##
## Suggested conventional keys:
## - title
## - tooltip
## - summary
## - description
##
## Games and components are free to define more keys.
@export var texts: Dictionary[StringName, String]:
	get: return __get_texts()
	set(v): __set_texts(v)

## Arbitrary resource paths used by this content.
##
## Suggested conventional keys:
## - icon
## - thumbnail
## - preview
## - scene
## - replicator
##
## Games and components are free to define more keys (e.g. crosshair).
## This is a path map, not loaded resources.
@export var paths: Dictionary[StringName, StringName]:
	get: return __get_paths()
	set(v): __set_paths(v)

@export_category("Dependencies")

## Pre-cache another resource by a Queries.
##
## This is how game "loading" knows what to load.
## Traverses all nested content resources and their subdependencies.
@export var dep_query: GsomModQueryBase = null

## Pre-cache other resources by an array of Queries.
##
## This is how game "loading" knows what to load.
## Traverses all nested content resources and their subdependencies.
@export var dep_queries: Array[GsomModQueryBase] = __empty_array_query

## Pre-cache other resources by a Selector.
##
## This is how game "loading" knows what to load.
## Traverses all nested content resources and their subdependencies.
@export var dep_selector: GsomModSelector = null

var __empty_array_query: Array[GsomModQueryBase] = []
var __empty_array_stringname: Array[StringName] = []
var __empty_dict: Dictionary[StringName, Variant] = {}
var __empty_dict_string: Dictionary[StringName, String] = {}
var __empty_dict_stringname: Dictionary[StringName, StringName] = {}

# Cached value that prevents creating new arrays on every get
var __tags_cache: Array[StringName] = __empty_array_stringname
var __has_tags_cache: bool = false

func __get_tags() -> Array[StringName]:
	if !__has_tags_cache:
		__tags_cache = _get_default_tags()
		__has_tags_cache = true
	return __tags_cache

# Stores into cache
func __set_tags(v: Array[StringName]) -> void:
	__tags_cache = ModUtils.array_uniq_string_name(v)
	__has_tags_cache = true

## [optional] Redefine this in subclasses
func _get_default_tags() -> Array[StringName]:
	return __empty_array_stringname.duplicate()

# Cached value that prevents creating new objects on every get
var __attrs_cache: Dictionary[StringName, Variant] = {}
var __has_attrs_cache: bool = false

func __get_attrs() -> Dictionary[StringName, Variant]:
	if !__has_attrs_cache:
		__attrs_cache = _get_default_attrs()
		__has_attrs_cache = true
	return __attrs_cache

# Stores into cache
func __set_attrs(v: Dictionary[StringName, Variant]) -> void:
	__attrs_cache = v
	__has_attrs_cache = true

## [optional] Redefine this in subclasses
func _get_default_attrs() -> Dictionary[StringName, Variant]:
	return __empty_dict.duplicate(true)

# Custom caps stored privately. These are on top of the default ones.
var __caps_cache: Array[StringName] = __empty_array_stringname
var __has_caps_cache: bool = false

func __get_caps() -> Array[StringName]:
	if !__has_caps_cache:
		__caps_cache = _get_default_caps()
		__has_caps_cache = true
	return __caps_cache

# Stores into cache
func __set_caps(v: Array[StringName]) -> void:
	__caps_cache = ModUtils.array_uniq_string_name(v)
	__has_caps_cache = true

## [optional] Redefine this in subclasses
func _get_default_caps() -> Array[StringName]:
	return __empty_array_stringname.duplicate()

# Cached value that prevents creating new objects on every get
var __texts_cache: Dictionary[StringName, String] = {}
var __has_texts_cache: bool = false

func __get_texts() -> Dictionary[StringName, String]:
	if !__has_texts_cache:
		__texts_cache = _get_default_texts()
		__has_texts_cache = true
	return __texts_cache

func __set_texts(v: Dictionary[StringName, String]) -> void:
	var normalized: Dictionary[StringName, String] = {}
	for key_v: Variant in v.keys():
		if typeof(key_v) != TYPE_STRING and typeof(key_v) != TYPE_STRING_NAME:
			continue
		var value_v: Variant = v[key_v]
		if typeof(value_v) != TYPE_STRING and typeof(value_v) != TYPE_STRING_NAME:
			continue
		var key_s: StringName = key_v
		var value_s: String = value_v
		if key_s == &"":
			continue
		if value_s.strip_edges() == "":
			continue
		normalized[key_s] = value_s
	__texts_cache = normalized
	__has_texts_cache = true

## [optional] Redefine this in subclasses
func _get_default_texts() -> Dictionary[StringName, String]:
	return __empty_dict_string.duplicate()

# Cached value that prevents creating new objects on every get
var __paths_cache: Dictionary[StringName, StringName] = {}
var __has_paths_cache: bool = false

func __get_paths() -> Dictionary[StringName, StringName]:
	if !__has_paths_cache:
		__paths_cache = _get_default_paths()
		__has_paths_cache = true
	return __paths_cache

func __set_paths(v: Dictionary[StringName, StringName]) -> void:
	var normalized: Dictionary[StringName, StringName] = {}
	for key_v: Variant in v.keys():
		if typeof(key_v) != TYPE_STRING and typeof(key_v) != TYPE_STRING_NAME:
			continue
		var value_v: Variant = v[key_v]
		if typeof(value_v) != TYPE_STRING and typeof(value_v) != TYPE_STRING_NAME:
			continue
		var key_s: StringName = key_v
		var value_s: StringName = value_v
		if key_s == &"" or value_s == &"":
			continue
		normalized[key_s] = value_s
	__paths_cache = normalized
	__has_paths_cache = true

## [optional] Redefine this in subclasses
func _get_default_paths() -> Dictionary[StringName, StringName]:
	return __empty_dict_stringname.duplicate()

# QoL helpers

## Is this tag present?
func has_tag(tag: StringName) -> bool:
	return __get_tags().has(tag)

## Does it has this capability?
func has_cap(cap: StringName) -> bool:
	return __get_caps().has(cap)

## If attribute exists
func has_attr(attr: StringName) -> bool:
	return __get_attrs().has(attr)

## Get attribute value or default
func get_attr(attr_key: StringName, default: Variant = null) -> Variant:
	return __get_attrs().get(attr_key, default)

## Lookup one resource path by key.
func get_path_slot(path_key: StringName, default: StringName = &"") -> StringName:
	return __get_paths().get(path_key, default)

## Lookup one text value by key.
func get_text_slot(text_key: StringName, default: String = "") -> String:
	return __get_texts().get(text_key, default)

## Set or clear one resource path key.
func set_path_slot(path_key: StringName, path_value: StringName) -> void:
	var copy: Dictionary[StringName, StringName] = __get_paths().duplicate()
	if path_key == &"":
		return
	if path_value == &"":
		copy.erase(path_key)
	else:
		copy[path_key] = path_value
	__set_paths(copy)

## Set or clear one text key.
func set_text_slot(text_key: StringName, text_value: String) -> void:
	if text_key == &"":
		return
	var copy: Dictionary[StringName, String] = __get_texts().duplicate()
	if text_value.strip_edges() == "":
		copy.erase(text_key)
	else:
		copy[text_key] = text_value
	__set_texts(copy)

## Flat list of all registered resource paths.
func list_paths() -> Array[StringName]:
	var result: Array[StringName] = []
	for value: StringName in __get_paths().values():
		if value != &"":
			result.append(value)
	return result

## Copy of all registered text slots.
func list_text_slots() -> Dictionary[StringName, String]:
	return __get_texts().duplicate()

## Add more tags
func add_tags(new_tags: Array[StringName]) -> void:
	var combined: Array[StringName] = __get_tags().duplicate()
	combined.append_array(new_tags)
	__set_tags(combined)

## Add more caps
func add_caps(new_caps: Array[StringName]) -> void:
	var combined: Array[StringName] = __get_caps().duplicate()
	combined.append_array(new_caps)
	__set_caps(combined)

## Add/override attrs
func add_attrs(new_attrs: Dictionary[StringName, Variant]) -> void:
	var combined: Dictionary[StringName, Variant] = __get_attrs().duplicate()
	combined.merge(new_attrs, true)
	__set_attrs(combined)
