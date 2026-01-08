extends Node
class_name SvcSpawn

var scenesDict: Dictionary[INetwork.SpawnLayer, Node] = {}

## Currently existing entities: `{ [net_id]: IReplicator }`
var spawned: Dictionary[int, IReplicator] = {}

func _ready() -> void:
	__create_scenes()

func __detach_scenes() -> void:
	for layer: INetwork.SpawnLayer in INetwork.SpawnLayer.values():
		GsomModapi.scene.remove_child(scenesDict[layer])
		scenesDict.erase(layer)

func __create_scenes() -> void:
	for layer: INetwork.SpawnLayer in INetwork.SpawnLayer.values():
		var scene: Node = Node.new()
		GsomModapi.scene.add_child(scene)
		scenesDict[layer] = scene

func spawn(
	net_id: int,
	content_id: StringName,
	layer: INetwork.SpawnLayer,
	data: Variant,
	net: INetwork,
	instigator_key: StringName,
) -> IReplicator:
	var content: GsomModContent = GsomModapi.content_by_id(content_id)
	if !content:
		push_error("Content not found by ID '%s'." % content_id)
		return null
	if !content.scene:
		push_error("Content ID '%s' has no scene." % content_id)
		return null
	
	var instance: Node = content.scene.instantiate()
	
	if scenesDict.has(layer):
		scenesDict[layer].add_child(instance)
	else:
		scenesDict[INetwork.SpawnLayer.WORLD].add_child(instance)
	
	if !content.replicator:
		return null
	
	var ent: IReplicator = content.replicator.new()
	ent.content_id = content_id
	ent.net_id = net_id
	ent.layer = layer
	ent.init_data = data
	ent.net = net
	ent.instigator_key = instigator_key
	instance.add_child(ent)
	
	spawned[net_id] = ent
	
	return ent

func despawn(net_id: int) -> void:
	if !spawned.has(net_id):
		return
	var ent: IReplicator = spawned[net_id]
	ent.get_parent().queue_free()
	
	spawned.erase(net_id)

func clear() -> void:
	for net_id: int in spawned:
		despawn(net_id)
	__detach_scenes()
	__create_scenes()
