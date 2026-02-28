extends IGsomEntity

const PICKUP_RADIUS: float = 1.25
const PICKUP_RADIUS_SQ: float = PICKUP_RADIUS * PICKUP_RADIUS
const BOB_HEIGHT: float = 0.1
const BOB_SPEED: float = 2.2
const SPIN_SPEED: float = 1.8
const __ComponentWeaponPistol = preload("res://core/content/wpn_pistol/component_weapon.gd")

var __collected: bool = false
var __base_origin: Vector3 = Vector3.ZERO
var __bob_phase: float = 0.0

func _sv_ready() -> void:
	__apply_spawn_init()
	__apply_collected_state()

func _cl_ready() -> void:
	__apply_spawn_init()
	__apply_collected_state()

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
		__set_collected(true)
		__broadcast_collected_event()
		__send_give_item_event(pawn.net_id)
		__send_item_picked_event_to_gamemode(pawn.net_id)
		return

func _cl_tick(dt: float) -> void:
	if __collected:
		return
	var weapon_node: Node3D = target as Node3D
	if !weapon_node:
		return
	__bob_phase += dt * BOB_SPEED
	var xf: Transform3D = weapon_node.global_transform
	xf.origin = __base_origin + Vector3(0.0, sin(__bob_phase) * BOB_HEIGHT, 0.0)
	weapon_node.global_transform = xf
	weapon_node.rotate_y(SPIN_SPEED * dt)

func _cl_read_event(e: Event) -> void:
	if !e or e.kind != &"set_collected":
		return
	if typeof(e.data) != TYPE_DICTIONARY:
		return
	var data: Dictionary = e.data
	var collected_v: Variant = data.get("collected", __collected)
	if typeof(collected_v) != TYPE_BOOL:
		return
	var collected_b: bool = collected_v
	__set_collected(collected_b)

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

func __set_collected(collected: bool) -> void:
	__collected = collected
	__apply_collected_state()

func __broadcast_collected_event() -> void:
	var ev: Event = Event.new()
	ev.kind = &"set_collected"
	ev.data = {
		"collected": __collected,
	}
	net._sv_send_event(net_id, ev)

func __apply_collected_state() -> void:
	var weapon_node: Node3D = target as Node3D
	if !weapon_node:
		return
	weapon_node.visible = !__collected

func __send_give_item_event(pawn_net_id: int) -> void:
	if pawn_net_id == IGsomNetwork.NET_ID_EMPTY:
		return
	var ev: Event = Event.new()
	ev.kind = &"give_item"
	ev.data = {
		"item_id": content_id,
		"item_net_id": net_id,
		"ammo_loaded": __ComponentWeaponPistol.CLIP_SIZE,
		"ammo_stored": __ComponentWeaponPistol.RESERVE_AMMO,
	}
	net._cl_send_event(pawn_net_id, ev)

func __send_item_picked_event_to_gamemode(pawn_net_id: int) -> void:
	var game_mode: IGsomGameMode = net._get_game_mode()
	if !game_mode:
		return
	var ev: Event = Event.new()
	ev.kind = &"item_picked"
	ev.data = {
		"item_id": content_id,
		"item_net_id": net_id,
		"picker_pawn_net_id": pawn_net_id,
	}
	net._cl_send_event(game_mode.net_id, ev)
