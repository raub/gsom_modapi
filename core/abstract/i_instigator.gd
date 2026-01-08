extends RefCounted
class_name IInstigator

## Base instigator - indirection for loggable entity description.
##
## Instigators can be registered and referenced by `key`.
## This description persists beyond lifetime of entities.
##
## Example: a monster throws a grenade and then despawns, later the grenade kills player.
## Now, who killed the player? The persistent indirect instigators are to the rescue.
##
## This class only defines critical instigator fields.
## It is a good idea to define a game-specific subclass and use it instead.
##
## Note: [readonly] means if you mutate it, you will face a terrible fate.
## There is no need for over-engineered precautions, you've been warned.

enum SourceKind {
	PLAYER, AI, WORLD,
}

## [readonly] Unique instigator identifier.
##
## Registering the same key will override the instigator data.
var key: StringName = &""

## [readonly] Source archetype of the instigator - to simplify filtering.
var kind: SourceKind = SourceKind.WORLD

## [readonly] From which mod content the instigator was created.
##
## Not necessarily the same content, but the UI will take texts and icons from there.
## You might as well have special content items for this purpose.
var content_id: StringName = &""
