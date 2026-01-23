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

# Fix editor revert buttons
func _property_can_revert(_property: StringName) -> bool:
	return true

var __str_props: Array[StringName] = [
	"ui_title", "ui_tooltip", "ui_summary", "ui_description",
]
var __strn_props: Array[StringName] = [
	"key",
	"path_icon", "path_thumbnail", "path_preview",
	"path_scene", "path_replicator",
]

# Fix revert behavior for arrays
func _property_get_revert(property: StringName) -> Variant:
	if property == "tags":
		return _get_default_tags()
	if property == "attrs":
		return _get_default_attrs()
	if property == "caps":
		return _get_default_caps()
	if property in __str_props:
		return ""
	if property in __strn_props:
		return &""
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

@export_category("UI Text")

## Displayable content name.
@export var ui_title: String = ""

## Short tooltip, shown on hover.
@export_multiline var ui_tooltip: String = ""

## Short description, 1–2 lines.
@export_multiline var ui_summary: String = ""

## Detailed description.
@export_multiline var ui_description: String = ""

@export_category("Res Paths")

## Path to a Texture2D - an icon for lists/slots/buttons.
##
## This is a path, not the resource itself.
## Storing a resource would load actual assets before it is necessary.
##
## Note: don't use UID paths - these won't survive mod PCK.
@export var path_icon: StringName = &""

## Path to a Texture2D - a preview thumbnail image.
##
## This is a path, not the resource itself.
## Storing a resource would load actual assets before it is necessary.
##
## Note: don't use UID paths - these won't survive mod PCK.
@export var path_thumbnail: StringName = &""

## Path to a PackedScene - a preview scene for UI purposes.
##
## This is a path, not the resource itself.
## Storing a resource would load actual assets before it is necessary.
##
## Note: don't use UID paths - these won't survive mod PCK.
@export var path_preview: StringName = &""

## Path to a PackedScene - the default representation of this content.
##
## This is a path, not the resource itself.
## Storing a resource would load actual assets before it is necessary.
##
## Note: don't use UID paths - these won't survive mod PCK.
@export var path_scene: StringName = &""

## Path to a GDScript - an optional separate script for network replication.
##
## This is separated from scene because it may have its own class-specific script.
## This is a path, not the resource itself.
##
## Note: don't use UID paths - these won't survive mod PCK.
@export var path_replicator: StringName = &""

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
	return __empty_array_stringname

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
	return __empty_dict

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
	return __empty_array_stringname

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
func get_attr(attr_key: StringName, default: Variant = null) -> Variant:
	return __get_attrs().get(attr_key, default)
