extends Node
class_name IReplicator

## Base for network replication adapters.
##
## A replicator is injected as direct child of the content node.
## This allows using any custom nodes for the game objects (e.g. RigidBody3D).
## You will also use IReplicator subtypes, such as IPlayer.
## Because there is no multiple inheritance, this is how topology is resolved.
## You can also reuse a single replicator script for multiple similar content.
##
## Replicator only implements snapshot/event sync.
## If you need to run client/server logic on every tick, use `IController`.
##
## Note: [readonly] means if you mutate it, you will face a terrible fate.
## There is no need for over-engineered precautions, you've been warned.

class Event:
	var kind: StringName = &""
	var data: Variant = null

## [readonly] A reference to the global Network service.
##
## It is never `null` during runtime - assigned upon creation, before `_ready`.
var net: INetwork = null

## [readonly] From which mod content it was created.
var content_id: StringName = &""

## [readonly] Server-assigned network ID.
var net_id: int = INetwork.NET_ID_EMPTY

## Instigator key - whoever is accountable for what this entity does.
##
## Answers who instigated this entity - used for stats, doesn't grant authority.
## This may change dynamically during lifetime of the entity.
var instigator_key: StringName = &""

## [readonly] The scene layer this replicator's target belongs to
var layer: INetwork.SpawnLayer = INetwork.SpawnLayer.WORLD

## [readonly] Optional construction parameters.
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
	## Sends snapshots according purely to `relevancy_base`, ignoring distance and occlusion
	ALWAYS,
	## Never sends snapshots
	NEVER,
	## Calculates relevancy for each peer
	RELEVANT,
}

## Data packing level of detail
enum RelevancyLod {
	MAX,
	MID,
	MIN,
}

# Can't be obscured by an override. Really, check the official doc.
# "this method is called automatically for every script that overrides it"
func _notification(what: int) -> void:
	# Same as `_ready`
	if what == NOTIFICATION_READY:
		assert(net != null, "IReplicator.net must be injected by INetwork before _ready.")
		if net.is_host:
			_sv_init()
		_cl_init()

## Client side init - you can use it instead of `_ready`.
##
## Called for each client. Host calls both `_sv_init` and `_cl_init`.
## On host, `_sv_init` is called before `_cl_init`.
##
## This is where you would utilize `init_data`, if any.
func _cl_init() -> void:
	pass

## Server side init - you can use it instead of `_ready`.
##
## Only called for the host. Host calls both `_sv_init` and `_cl_init`.
## On host, `_sv_init` is called before `_cl_init`.
##
## This is where you would utilize `init_data`, if any.
func _sv_init() -> void:
	pass

## Accept an update snapshot.
##
## The data format will be whatever your `_sv_pack` has produced on the server.
func _cl_unpack(_snapshot: Variant) -> void:
	pass

## Create an update snapshot.
##
## Ideally, it should be efficiently packed, but a simple Dictionary will also work.
## No format requirement, but make sure to implement reading it in `_cl_unpack`.
func _sv_pack(_lod: RelevancyLod) -> Variant:
	return null

## On server, read a reliable event from a client.
##
## Such events are sent through `_cl_send_event` by one of the peers.
## The `Event.data` format is not constrained.
## You can use `Event.kind` to identify the specific event types.
func _sv_read_event(_peer: IPeer, _e: Event) -> void:
	pass

## On client, read a reliable event from the server.
##
## Such events are sent through `_sv_send_event` by the server.
## The `Event.data` format is not constrained.
## You can use `Event.kind` to identify the specific event types.
func _cl_read_event(_e: Event) -> void:
	pass
