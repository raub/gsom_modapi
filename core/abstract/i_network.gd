extends Node
class_name INetwork

enum SpawnLayer {
	WORLD,
	ACTORS,
	ITEMS,
	EFFECTS,
	CONTROLLERS,
	MENU,
}

class Peer:
	var id: int = -1
	var name: String = "Player"
	func _init(new_id: int) -> void:
		id = new_id

var host_id: int = 1
var local_player: Peer = Peer.new(host_id)
var peers: Array[Peer] = [local_player]

## Is this instance the host?
##
## Default true, as you always launch the game as a host.
## Will become false upon successfully joining the game.
var authority: bool = true

## Create an entity.
##
## E.g. you shoot a rocket - `_sv_tick` of the launcher (or of the player) calls this.
## Only server can call it.
func _spawn(_content_id: StringName, _layer: StringName, _data: Variant = null) -> void:
	pass

## Remove an entity.
##
## E.g. a grenade has blown up - `_sv_tick` of the grenade calls this.
## Only server can call it.
func _despawn(_net_id: int) -> void:
	pass

## Send a reliable event to the server instance of `net_id` (usually `sender.net_id`)
##
## On host, this can be called too, from the client code.
func _cl_send_event(_net_id: int, _e: Variant) -> void:
	pass

## Broadcast a reliable event to ALL instances of `net_id` (usually `sender.net_id`)
##
## Only server can call it.
func _sv_send_event(_net_id: int, _e: Variant) -> void:
	pass
