extends GsomComponentWeapon
class_name GsomComponentWeaponPistol

const TAG_PISTOL: StringName = &"pistol"
const TAG_WEAPON: StringName = &"weapon"
const ATTR_DAMAGE: StringName = &"damage"
const ATTR_FIRE_RATE: StringName = &"fire_rate"
const CLIP_SIZE: int = 17
const RESERVE_AMMO: int = 200
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

var __next_attack_time_s: float = 0.0

func weapon_get_pickup_state() -> Dictionary:
	return {
		"ammo_loaded": CLIP_SIZE,
		"ammo_stored": RESERVE_AMMO,
	}

func weapon_fire_tick(
	owner_replicator: IGsomPawn,
	owner_pawn: Node3D,
	now_s: float,
	primary_held: bool,
	secondary_held: bool,
	ammo_loaded: int,
) -> Variant:
	var pawn: CharPlayer = owner_pawn as CharPlayer
	if !owner_replicator or !pawn:
		return ammo_loaded
	var fire_mode: FireMode = __pick_fire_mode(primary_held, secondary_held)
	if fire_mode == FireMode.NONE:
		return ammo_loaded
	if ammo_loaded <= 0:
		return ammo_loaded
	if now_s < __next_attack_time_s:
		return ammo_loaded

	__next_attack_time_s = now_s + __get_fire_interval(fire_mode)
	__fire_hitscan(owner_replicator, pawn, fire_mode)
	return maxi(0, ammo_loaded - 1)

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
