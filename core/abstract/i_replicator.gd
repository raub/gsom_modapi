extends Node
class_name IReplicator

## Base for network replication adaptors.
##
## A replicator is injected as direct child of the content node.
## This allows using any custom nodes for the game objects (e.g. RigidBody3D).
## You will also use IReplicator subtypes, such as IPlayer.
## Because there is no multiple inheritance, this is how topology is resolved.
## You can also reuse a single replicator script for multiple similar content.

## The global Network service
var net: INetwork = null

## From which mod content it was created
var content_id: StringName = &""

## Server-assigned network ID
var net_id: int = -1

## Controller net_id - who caused this entity, used for stats, doesn't grant authority
var instigator_id: int = -1

## The scene layer this replicator's target belongs to
var layer: INetwork.SpawnLayer = INetwork.SpawnLayer.WORLD

## Optional construction parameters, such as "transform" or any specifics like "hp"
var init_data: Variant = null

## How important is updating this entity for a smooth experience?
var relevancy_base: float = 1

## Always relevant/irrelevant, or simply relevant
var relevancy_mode: RelevancyMode = RelevancyMode.RELEVANT

## How relevancy falls off with distance increase
var relevancy_bias: float = 1

enum RelevancyMode {
	## Sends snapshots according purely to `relevancy_base`, by default - every frame
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

## Accept an update snapshot
func _cl_unpack(_snapshot: Variant) -> void:
	pass

## Create an update snapshot
func _sv_pack(_lod: RelevancyLod) -> Variant:
	return null
