extends GsomComponentWeapon
class_name GsomComponentWeaponPistol

const TAG_PISTOL: StringName = &"pistol"
const TAG_WEAPON: StringName = &"weapon"
const ATTR_DAMAGE: StringName = &"damage"
const ATTR_FIRE_RATE: StringName = &"fire_rate"
const CLIP_SIZE: int = 17
const RESERVE_AMMO: int = 200
const RELOAD_TIME: float = 1.2
const RANGE: float = 2048.0
const EYE_HEIGHT: float = 1.55
const PRIMARY_INTERVAL: float = 0.3
const SECONDARY_INTERVAL: float = 0.2
const PRIMARY_SPREAD: float = 0.01
const SECONDARY_SPREAD: float = 0.1

enum FireMode {
	NONE,
	PRIMARY,
	SECONDARY,
}

func _ready() -> void:
	primary_ammo_kind = &"ammo_9mm"
	secondary_ammo_kind = &""
	default_ammo = RESERVE_AMMO
	if clip < 0:
		clip = CLIP_SIZE

func get_pickup_state() -> Dictionary:
	return {
		"ammo_loaded": CLIP_SIZE,
		"ammo_stored": RESERVE_AMMO,
	}

func post_frame(
	owner_replicator: IGsomPawn,
	owner_pawn: Node3D,
	ammo_state: Dictionary,
) -> Dictionary:
	var pawn: CharPlayer = owner_pawn as CharPlayer
	if !owner_replicator or !pawn:
		return ammo_state.duplicate()

	var now_s: float = float(Time.get_ticks_usec()) / 1000000.0
	var primary_held: bool = pawn.pawn_is_shoot_primary_held()
	var secondary_held: bool = pawn.pawn_is_shoot_secondary_held()
	var reload_pressed: bool = pawn.pawn_consume_reload_queued()

	var ammo_loaded: int = __read_ammo_value(ammo_state, "ammo_loaded", clip)
	var ammo_stored: int = __read_ammo_value(ammo_state, "ammo_stored", 0)
	clip = ammo_loaded

	if in_reload and now_s >= next_primary_attack_s:
		var reloaded: Dictionary = __finish_reload(ammo_stored)
		ammo_loaded = reloaded["ammo_loaded"]
		ammo_stored = reloaded["ammo_stored"]
		clip = ammo_loaded

	if in_reload:
		return __pack_ammo(ammo_loaded, ammo_stored)

	var should_auto_reload: bool = ammo_loaded <= 0 and ammo_stored > 0
	var should_reload: bool = reload_pressed or should_auto_reload
	if should_reload and __can_start_reload(ammo_loaded, ammo_stored):
		__start_reload(now_s)
		return __pack_ammo(ammo_loaded, ammo_stored)

	var fire_mode: FireMode = __pick_fire_mode(primary_held, secondary_held)
	if fire_mode == FireMode.NONE:
		return __pack_ammo(ammo_loaded, ammo_stored)
	if ammo_loaded <= 0:
		if ammo_stored > 0 and __can_start_reload(ammo_loaded, ammo_stored):
			__start_reload(now_s)
		return __pack_ammo(ammo_loaded, ammo_stored)

	var can_fire: bool = false
	if fire_mode == FireMode.PRIMARY:
		can_fire = now_s >= next_primary_attack_s
	else:
		can_fire = now_s >= next_secondary_attack_s
	if !can_fire:
		return __pack_ammo(ammo_loaded, ammo_stored)

	var next_attack: float = now_s + __get_fire_interval(fire_mode)
	next_primary_attack_s = next_attack
	next_secondary_attack_s = next_attack
	next_idle_s = next_attack
	play_shot_fx()
	__fire_hitscan(owner_replicator, pawn, fire_mode)
	ammo_loaded = maxi(0, ammo_loaded - 1)
	clip = ammo_loaded
	if ammo_loaded <= 0 and ammo_stored > 0 and __can_start_reload(ammo_loaded, ammo_stored):
		__start_reload(now_s)
	return __pack_ammo(ammo_loaded, ammo_stored)

func __can_start_reload(ammo_loaded: int, ammo_stored: int) -> bool:
	return ammo_loaded < CLIP_SIZE and ammo_stored > 0 and !in_reload

func __start_reload(now_s: float) -> void:
	in_reload = true
	next_primary_attack_s = now_s + RELOAD_TIME
	next_secondary_attack_s = next_primary_attack_s
	next_idle_s = next_primary_attack_s

func __finish_reload(ammo_stored: int) -> Dictionary:
	var need: int = maxi(0, CLIP_SIZE - clip)
	if need <= 0 or ammo_stored <= 0:
		in_reload = false
		return __pack_ammo(clip, ammo_stored)
	var transfer: int = mini(need, ammo_stored)
	clip += transfer
	ammo_stored -= transfer
	in_reload = false
	return __pack_ammo(clip, ammo_stored)

func __pack_ammo(ammo_loaded: int, ammo_stored: int) -> Dictionary:
	return {
		"ammo_loaded": maxi(0, ammo_loaded),
		"ammo_stored": maxi(0, ammo_stored),
	}

func __read_ammo_value(state: Dictionary, key: String, fallback: int) -> int:
	var value_v: Variant = state.get(key, fallback)
	if typeof(value_v) == TYPE_INT:
		var value_i: int = value_v
		return maxi(0, value_i)
	return maxi(0, fallback)

func __pick_fire_mode(primary_held: bool, secondary_held: bool) -> FireMode:
	if secondary_held:
		return FireMode.SECONDARY
	if primary_held:
		return FireMode.PRIMARY
	return FireMode.NONE

func __get_fire_interval(mode: FireMode) -> float:
	var base_interval: float = PRIMARY_INTERVAL if mode == FireMode.PRIMARY else SECONDARY_INTERVAL
	return base_interval

func __get_spread(mode: FireMode) -> float:
	if mode == FireMode.SECONDARY:
		return SECONDARY_SPREAD
	if mode == FireMode.PRIMARY:
		return PRIMARY_SPREAD
	return 0.0

func __play_shot_fx() -> void:
	var weapon_node: Node = get_parent()
	if !weapon_node:
		return
	if weapon_node.has_method("weapon_play_muzzle_flash"):
		weapon_node.call("weapon_play_muzzle_flash")
	if weapon_node.has_method("weapon_play_sfx_shot"):
		weapon_node.call("weapon_play_sfx_shot")

func play_shot_fx() -> void:
	__play_shot_fx()

func play_hit_fx(at: Vector3) -> void:
	__play_hit_fx(at)

func __play_hit_fx(at: Vector3) -> void:
	var weapon_node: Node = get_parent()
	if !weapon_node:
		return
	if weapon_node.has_method("weapon_play_sfx_hit"):
		weapon_node.call("weapon_play_sfx_hit", at)

func __fire_hitscan(
	owner_replicator: IGsomPawn,
	owner_pawn: CharPlayer,
	fire_mode: FireMode,
) -> void:
	var world_3d: World3D = owner_pawn.get_world_3d()
	if !world_3d:
		return
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if !space_state:
		return

	var yaw: float = owner_pawn.pawn_get_aim_yaw()
	var pitch: float = owner_pawn.pawn_get_aim_pitch()
	var yaw_basis: Basis = Basis(Vector3.UP, yaw)
	var forward_flat: Vector3 = (yaw_basis * Vector3.FORWARD).normalized()
	var right: Vector3 = (yaw_basis * Vector3.RIGHT).normalized()
	var pitch_basis: Basis = Basis(right, pitch)
	var forward: Vector3 = (pitch_basis * forward_flat).normalized()
	var up: Vector3 = (right.cross(forward)).normalized()

	var spread: float = __get_spread(fire_mode)
	if spread > 0.0:
		var spread_x: float = randf_range(-spread, spread)
		var spread_y: float = randf_range(-spread, spread)
		forward = (forward + right * spread_x + up * spread_y).normalized()

	var from: Vector3 = owner_pawn.global_transform.origin + Vector3.UP * EYE_HEIGHT
	var to: Vector3 = from + forward * RANGE
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collide_with_areas = false
	query.exclude = [owner_pawn.get_rid()]

	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var at_v: Variant = hit.get("position")
	if at_v:
		var at_v3: Vector3 = at_v
		play_hit_fx(at_v3)
		__replicate_hit_fx(owner_replicator, at_v3)
	var victim: IGsomPawn = __find_hit_pawn(owner_replicator.net, hit.get("collider", null))
	if !victim or victim == owner_replicator:
		return
	var damage: float = 10.0
	__apply_damage(owner_replicator, victim, damage)

func __apply_damage(owner_replicator: IGsomPawn, victim: IGsomPawn, damage: float) -> void:
	if !owner_replicator or !victim:
		return
	if damage <= 0.0:
		return
	if owner_replicator.net.check_is_host():
		if victim.has_method("_sv_apply_damage"):
			victim.call("_sv_apply_damage", damage, owner_replicator.net_id)
		return
	var ev: IGsomEntity.Event = IGsomEntity.Event.new()
	ev.kind = &"apply_damage"
	ev.data = {
		"amount": damage,
		"source_net_id": owner_replicator.net_id,
	}
	owner_replicator.net._cl_send_event(victim.net_id, ev)

func __find_hit_pawn(net: IGsomNetwork, collider_v: Variant) -> IGsomPawn:
	if !net:
		return null
	if !(collider_v is Node):
		return null
	var collider_node: Node = collider_v
	for entity: IGsomEntity in net._get_entities_by_layer(IGsomNetwork.SpawnLayer.ACTORS):
		var pawn: IGsomPawn = entity as IGsomPawn
		if !pawn:
			continue
		var pawn_node: Node = pawn.target
		if !pawn_node:
			continue
		if pawn_node == collider_node or pawn_node.is_ancestor_of(collider_node):
			return pawn
	return null

func __replicate_hit_fx(owner_replicator: IGsomPawn, at: Vector3) -> void:
	if !owner_replicator:
		return
	if !owner_replicator.has_method("_weapon_report_hit_fx"):
		return
	owner_replicator.call("_weapon_report_hit_fx", at)
