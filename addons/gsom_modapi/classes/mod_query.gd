extends Resource
class_name GsomModQuery

## KINDS: restrict search to specific content "kinds"
@export var kinds: Array[StringName] = []

## CAPABILITIES: include / exclude
@export var caps_include: Array[StringName] = []
@export var caps_exclude: Array[StringName] = []

## TAGS: include / exclude
@export var tags_include: Array[StringName] = []
@export var tags_exclude: Array[StringName] = []

## ATTRIBUTES: ranges or exact match
## structure:
##  attr_min["difficulty"] = 2
##  attr_max["difficulty"] = 5
##  attr_equals["biome"] = "snow"
@export var attr_min: Dictionary[StringName, Variant] = {}
@export var attr_max: Dictionary[StringName, Variant] = {}
@export var attr_equals: Dictionary[StringName, Variant] = {}

## DIRECT OVERRIDE: pick a specific ID and skip all filtering
@export var exact_id: StringName = ""

## SORTING: Largest values first, empty values last
@export var sort_attr: StringName = ""
