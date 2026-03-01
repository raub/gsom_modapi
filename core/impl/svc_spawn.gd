extends Node
class_name SvcSpawn

const __PassiveReplicator: GDScript = preload("res://core/impl/replicator_passive.gd")

## A scene for each layer: `{ [WORLD]: Node, [ACTORS]: Node, ... }`
var scenes_by_layer: Dictionary[IGsomNetwork.SpawnLayer, Node] = {}

## Currently existing entities: `{ [net_id]: IGsomEntity }`
var entities_by_id: Dictionary[int, IGsomEntity] = {}

## Same as `entities_by_id`, but separated into layers
var entities_by_layer: Dictionary[IGsomNetwork.SpawnLayer, Dictionary] = {}

func _ready() -> void:
	__alloc_layers()

func __dealloc_layers() -> void:
	for layer: IGsomNetwork.SpawnLayer in IGsomNetwork.SpawnLayer.values():
		entities_by_layer.erase(layer)
		
		GsomModapi.scene.remove_child(scenes_by_layer[layer])
		scenes_by_layer.erase(layer)

func __alloc_layers() -> void:
	for layer: IGsomNetwork.SpawnLayer in IGsomNetwork.SpawnLayer.values():
		entities_by_layer[layer] = {}
		
		var scene: Node = Node.new()
		GsomModapi.scene.add_child(scene)
		scenes_by_layer[layer] = scene

func spawn(
	net_id: int,
	content_id: StringName,
	layer: IGsomNetwork.SpawnLayer,
	data: Variant,
	net: IGsomNetwork,
	instigator: StringName,
) -> IGsomEntity:
	var content: GsomModContent = GsomModapi.content_by_id(content_id)
	if !content:
		push_error("Content not found by ID '%s'." % content_id)
		return null
	var path_scene: StringName = content.get_path_slot(GsomModContent.PATH_SCENE)
	if path_scene == &"":
		push_error("Content ID '%s' has no scene." % content_id)
		return null
	
	var scene: PackedScene = load(path_scene)
	var instance: Node = scene.instantiate()
	scenes_by_layer[layer].add_child(instance)
	
	var path_replicator: StringName = content.get_path_slot(GsomModContent.PATH_REPLICATOR)
	var replicator: GDScript = null
	if path_replicator == &"":
		replicator = __PassiveReplicator
	else:
		replicator = load(path_replicator)
	if !replicator:
		push_error("Content ID '%s' has invalid replicator '%s'." % [content_id, String(path_replicator)])
		instance.queue_free()
		return null
	var ent: IGsomEntity = replicator.new()
	if !ent:
		push_error("Content ID '%s' replicator did not create an IGsomEntity." % content_id)
		instance.queue_free()
		return null
	ent.content_id = content_id
	ent.net_id = net_id
	ent.layer = layer
	ent.init_data = data
	ent.net = net
	ent.instigator = instigator
	instance.add_child(ent)
	
	entities_by_layer[layer][net_id] = ent
	entities_by_id[net_id] = ent
	
	return ent

func despawn(net_id: int) -> void:
	if !entities_by_id.has(net_id):
		return
	var ent: IGsomEntity = entities_by_id[net_id]
	ent.get_parent().queue_free()
	
	entities_by_layer[ent.layer].erase(net_id)
	entities_by_id.erase(net_id)

func clear() -> void:
	for net_id: int in entities_by_id:
		despawn(net_id)
	__dealloc_layers()
	__alloc_layers()
