extends GsomModQueryBase
class_name GsomModQueryFilter

## Restrict search to specific content "kinds"
@export var kinds: Array[StringName] = []

## Require at least 1 capability match
@export var caps_any: Array[StringName] = []

## Require all listed capabilities to be present
@export var caps_all: Array[StringName] = []

## Exclude content with these capabilities
@export var caps_exclude: Array[StringName] = []

## Require at least 1 tag match
@export var tags_any: Array[StringName] = []

## Require all listed tags to be present
@export var tags_all: Array[StringName] = []

## Exclude content with these tags
@export var tags_exclude: Array[StringName] = []

## ATTRIBUTES: ranges or exact match
## structure:
##  attr_min["difficulty"] = 2
##  attr_max["difficulty"] = 5
##  attr_equals["biome"] = "snow"

## Require minimum values for these attributes
@export var attr_min: Dictionary[StringName, Variant] = {}

## Exclude content with attributes exceeding these values
@export var attr_max: Dictionary[StringName, Variant] = {}

## Require the attribute values to match exactly
@export var attr_equals: Dictionary[StringName, Variant] = {}

## Filter out specific items by their IDs
@export var id_exclude: Array[StringName] = []

## Ban specific content keys
@export var key_exclude: Array[StringName] = []
