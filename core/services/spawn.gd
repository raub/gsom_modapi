extends Node
class_name SvcSpawn

var scenes: Scenes = Scenes.new()
var scenesDict: Dictionary[StringName, Node] = {}

class Scenes:
	var world: Node = null
	var actors: Node = null
	var items: Node = null
	var effects: Node = null
	var controllers: Node = null
	var menu: Node = null

class Entity:
	var content_id: StringName
	var net_id: int
	var data: Variant
	var node: IReplicated
	var layer: StringName

var spawned: Dictionary[int, Entity] = {}

func _ready() -> void:
	__create_scenes()

func __detach_scenes() -> void:
	if scenes.world:
		GsomModapi.scene.remove_child(scenes.world)
		scenesDict["world"] = null
		scenes.world = null
	if scenes.actors:
		GsomModapi.scene.remove_child(scenes.actors)
		scenesDict["actors"] = null
		scenes.actors = null
	if scenes.items:
		GsomModapi.scene.remove_child(scenes.items)
		scenesDict["items"] = null
		scenes.items = null
	if scenes.effects:
		GsomModapi.scene.remove_child(scenes.effects)
		scenesDict["effects"] = null
		scenes.effects = null
	if scenes.controllers:
		GsomModapi.scene.remove_child(scenes.controllers)
		scenesDict["controllers"] = null
		scenes.controllers = null
	if scenes.menu:
		GsomModapi.scene.remove_child(scenes.menu)
		scenesDict["menu"] = null
		scenes.menu = null

func __create_scenes() -> void:
	scenes.world = Node.new()
	GsomModapi.scene.add_child(scenes.world)
	scenesDict["world"] = scenes.world
	scenes.actors = Node.new()
	GsomModapi.scene.add_child(scenes.actors)
	scenesDict["actors"] = scenes.actors
	scenes.items = Node.new()
	GsomModapi.scene.add_child(scenes.items)
	scenesDict["items"] = scenes.items
	scenes.effects = Node.new()
	GsomModapi.scene.add_child(scenes.effects)
	scenesDict["effects"] = scenes.effects
	scenes.controllers = Node.new()
	GsomModapi.scene.add_child(scenes.controllers)
	scenesDict["controllers"] = scenes.controllers
	scenes.menu = Node.new()
	GsomModapi.scene.add_child(scenes.menu)
	scenesDict["menu"] = scenes.menu

func spawn(net_id: int, content_id: StringName, layer: StringName, data: Variant) -> Entity:
	var content: GsomModContent = GsomModapi.content_by_id(content_id)
	if !content:
		push_error("Content not found by ID '%s'." % content_id)
		return null
	if !content.scene:
		push_error("Content ID '%s' has no scene." % content_id)
		return null
	
	var instance: IReplicated = content.scene.instantiate() as IReplicated
	if !instance:
		push_error("Content ID '%s' can't spawn IReplicated." % content_id)
		return null
	
	var ent: Entity = Entity.new()
	ent.content_id = content_id
	ent.net_id = net_id
	ent.data = data
	ent.node = instance
	ent.layer = layer
	
	ent.node._cl_init(data)
	
	if scenesDict.has(layer):
		scenesDict[layer].add_child(ent.node)
	else:
		scenesDict["world"].add_child(ent.node)
	spawned[net_id] = ent
	
	return ent

func despawn(net_id: int) -> void:
	if !spawned.has(net_id):
		return
	var ent: Entity = spawned[net_id]
	ent.node.get_parent().remove_child(ent.node)
	ent.node.queue_free.call_deferred()
	ent.node = null
	
	spawned.erase(net_id)

func clear() -> void:
	for net_id: int in spawned:
		despawn(net_id)
	__detach_scenes()
	__create_scenes()
