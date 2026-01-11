extends Node
class_name SvcSpawn

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
	if !content.path_scene:
		push_error("Content ID '%s' has no scene." % content_id)
		return null
	
	var scene: PackedScene = load(content.path_scene)
	var instance: Node = scene.instantiate()
	scenes_by_layer[layer].add_child(instance)
	
	if !content.path_replicator:
		return null
	
	var replicator: GDScript = load(content.path_replicator)
	var ent: IGsomEntity = replicator.new()
	ent.content_id = content_id
	ent.net_id = net_id
	ent.layer = layer
	ent.init_data = data
	ent.net = net
	ent.instigator = instigator
	instance.add_child(ent)
	
	entities_by_id[net_id] = ent
	
	return ent

func despawn(net_id: int) -> void:
	if !entities_by_id.has(net_id):
		return
	var ent: IGsomEntity = entities_by_id[net_id]
	ent.get_parent().queue_free()
	
	entities_by_id.erase(net_id)

func clear() -> void:
	for net_id: int in entities_by_id:
		despawn(net_id)
	__dealloc_layers()
	__alloc_layers()
