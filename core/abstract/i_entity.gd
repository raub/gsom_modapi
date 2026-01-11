extends Node
class_name IGsomEntity

## Base for network replication adapters - entities.
##
## This is what **mods should implement** for network-enabled content.
## I.e. opposed to IGsomNetwork and IGsomPeer implementations, shipped by the Core.
##
## A replicator is injected as direct child of the content node.
## This allows using any custom nodes for the game objects (e.g. RigidBody3D).
## You will also use IGsomEntity subtypes, such as IGsomPlayer.
## Because there is no multiple inheritance, this is how topology is resolved.
## You can also reuse a single replicator script for multiple similar content.
##
## Entity only implements snapshot/event sync.
## If you need to run client/server logic on every tick, use `IGsomController`.
##
## Note, guideline keywords:
## - [readonly] - if you mutate it, you will face a terrible fate.
## - [optional] - it's ok to omit implementation.
## - [server] - this will not be called on clients.
## - [core] - it is safe to assume the Core has implemented it.

class Event:
	var kind: StringName = &""
	var data: Variant = null

## [readonly core] The parent node is always the replication target.
var target: Node:
	get: return get_parent()

## [readonly core] A reference to the global Network service.
##
## Injected before `_ready` (before `_sv_ready` and `_cl_ready`).
var net: IGsomNetwork = null

## [readonly core] Server-assigned network ID.
##
## Injected before `_ready` (before `_sv_ready` and `_cl_ready`).
var net_id: int = IGsomNetwork.NET_ID_EMPTY

## [readonly core] From which mod content it was created.
##
## Injected before `_ready` (before `_sv_ready` and `_cl_ready`).
var content_id: StringName = &""

## [readonly core] Instigator identity. Who is accountable for what this entity does.
##
## Injected before `_ready` (before `_sv_ready` and `_cl_ready`).
## Answers who instigated this entity - used for stats, doesn't grant authority.
##
## This value can be used against `IGsomNetwork._get_instigator`,
## and other instigator-related methods accepting identity.
var instigator: StringName = &""

## [readonly core] The scene layer this replicator's target belongs to
##
## Injected before `_ready` (before `_sv_ready` and `_cl_ready`).
var layer: IGsomNetwork.SpawnLayer = IGsomNetwork.SpawnLayer.WORLD

## [readonly core] Optional construction parameters.
##
## Such as "transform" or any specifics like "hp".
## It is assigned upon creation (if provided), before `_ready`.
## Ideally, this data should be efficiently packed, but a simple Dictionary will also work.
var init_data: Variant = null

## How important is updating this entity for a smooth experience?
##
## The expected range is 0..1 inclusive.
## Anything below 0 will works as 0, above 1 works as 1 (effectively clamped).
## This value can be changed dynamically with every server frame.
var relevancy_base: float = 1

## Always relevant/irrelevant, or simply relevant.
##
## This value can be changed dynamically with every server frame.
var relevancy_mode: RelevancyMode = RelevancyMode.RELEVANT

## How relevancy falls off with distance increase.
##
## Similar to Mesh LOD bias:
## - > 1.0 - transitions happen later (higher quality, lower performance).
## - < 1.0 - transitions happen sooner (lower quality, higher performance).
## This value can be changed dynamically with every server frame.
var relevancy_bias: float = 1

enum RelevancyMode {
	## Ignores distance (etc). But "always" is NOT full-rate. Respects `relevancy_base`.
	ALWAYS,
	## Never sends snapshots. Until re-enabled by changing to a different mode.
	NEVER,
	## Calculates relevancy for each peer, based on game mode and player logic.
	RELEVANT,
}

## Data packing level of detail
enum RelevancyLod {
	MAX,
	MID,
	MIN,
}

# IMPORTANT:
# `_notification` is used instead of `_ready()` because it is the only callback
# guaranteed by Godot to run across the entire script inheritance chain without
# requiring `super` calls. There is no need to call it manually from a subclass,
# or to validate that such call was made.
#
# Subclasses can "override" `_notification` in any way, but this hook will still run.
# GDScript guarantees that all `_notification` callbacks are called,
# throughout the whole inheritance chain.
#
# Override `_sv_ready` and `_cl_ready` for proper entity initialization.
func _notification(what: int) -> void:
	if what == NOTIFICATION_READY: # same as `_ready`
		assert(net != null, "IGsomEntity.net must be injected before _ready.")
		assert(
			net_id != IGsomNetwork.NET_ID_EMPTY,
			"IGsomEntity.net_id must be injected before _ready.",
		)
		assert(content_id != &"", "IGsomEntity.content_id must be injected before _ready.")
		
		if net.check_is_host():
			_sv_ready()
		
		_cl_ready()

## [optional] Client side init - you can use it instead of `_ready`.
##
## Called on clients.
## Host calls both `_sv_ready` and `_cl_ready` - in this order.
##
## This is where you would utilize `init_data`, if any.
func _cl_ready() -> void:
	pass

## [server, optional] Server side init - you can use it instead of `_ready`.
##
## Host calls both `_sv_ready` and `_cl_ready` - in this order.
##
## This is where you would utilize `init_data`, if any.
func _sv_ready() -> void:
	pass

## [optional] Accept an update snapshot.
##
## The data format will be whatever your `_sv_pack` has produced on the server.
func _cl_unpack(_snapshot: Variant) -> void:
	pass

## [server, optional] Create an update snapshot.
##
## Ideally, it should be efficiently packed, but a simple Dictionary will also work.
## No format requirement, but make sure to implement reading it in `_cl_unpack`.
func _sv_pack(_lod: RelevancyLod) -> Variant:
	return null

## [server, optional] Read a reliable event from a client.
##
## Such events are sent through `_cl_send_event` by one of the peers.
## The `Event.data` format is not constrained.
## You can use `Event.kind` to identify the specific event types.
func _sv_read_event(_peer: IGsomPeer, _e: Event) -> void:
	pass

## [optional] On client, read a reliable event from the server.
##
## Such events are sent through `_sv_send_event` by the server.
## The `Event.data` format is not constrained.
## You can use `Event.kind` to identify the specific event types.
func _cl_read_event(_e: Event) -> void:
	pass
