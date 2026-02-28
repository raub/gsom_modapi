extends IGsomEntity

const PICKUP_RADIUS: float = 1.25
const PICKUP_RADIUS_SQ: float = PICKUP_RADIUS * PICKUP_RADIUS
const BOB_HEIGHT: float = 0.1
const BOB_SPEED: float = 2.2
const SPIN_SPEED: float = 1.8

var __collected: bool = false
var __base_origin: Vector3 = Vector3.ZERO
var __bob_phase: float = 0.0

func _sv_ready() -> void:
	__apply_spawn_init()

func _cl_ready() -> void:
	__apply_spawn_init()

func _sv_tick(_dt: float) -> void:
	if __collected:
		return

	var weapon_node: Node3D = target as Node3D
	if !weapon_node:
		return

	var pickup_origin: Vector3 = weapon_node.global_transform.origin

	for entity: IGsomEntity in net._get_entities_by_layer(IGsomNetwork.SpawnLayer.ACTORS):
		var pawn: IGsomPawn = entity as IGsomPawn
		if !pawn:
			continue
		# Only players should pick this up.
		if pawn.player_id == IGsomNetwork.NET_ID_EMPTY:
			continue
		var pawn_node: Node3D = pawn.target as Node3D
		if !pawn_node:
			continue
		if pawn_node.global_transform.origin.distance_squared_to(pickup_origin) > PICKUP_RADIUS_SQ:
			continue
		__collected = true
		net._sv_despawn(net_id)
		return

func _cl_tick(dt: float) -> void:
	var weapon_node: Node3D = target as Node3D
	if !weapon_node:
		return
	__bob_phase += dt * BOB_SPEED
	var xf: Transform3D = weapon_node.global_transform
	xf.origin = __base_origin + Vector3(0.0, sin(__bob_phase) * BOB_HEIGHT, 0.0)
	weapon_node.global_transform = xf
	weapon_node.rotate_y(SPIN_SPEED * dt)

func __apply_spawn_init() -> void:
	var weapon_node: Node3D = target as Node3D
	if !weapon_node:
		return

	if typeof(init_data) == TYPE_DICTIONARY:
		var data: Dictionary = init_data
		if data.has("xf") and typeof(data["xf"]) == TYPE_TRANSFORM3D:
			weapon_node.global_transform = data["xf"]

	__base_origin = weapon_node.global_transform.origin
	__bob_phase = (float(net_id % 1024) / 1024.0) * TAU
