extends Node
class_name GsomComponentWeapon

func weapon_get_pickup_state() -> Dictionary:
	return {}

func weapon_fire_tick(
	_owner_replicator: IGsomPawn,
	_owner_pawn: Node3D,
	_now_s: float,
	_primary_held: bool,
	_secondary_held: bool,
	ammo_loaded: int,
) -> Variant:
	return ammo_loaded
