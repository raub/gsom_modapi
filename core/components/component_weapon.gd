extends Node
class_name GsomComponentWeapon

## Half-Life style baseline weapon state.
var in_special_reload: bool = false
var next_primary_attack_s: float = 0.0
var next_secondary_attack_s: float = 0.0
var next_idle_s: float = 0.0
var primary_ammo_kind: StringName = &""
var secondary_ammo_kind: StringName = &""
var clip: int = -1
var in_reload: bool = false
var default_ammo: int = 0

func get_pickup_state() -> Dictionary:
	return {}

func post_frame(
	_owner_replicator: IGsomPawn,
	_owner_pawn: Node3D,
	ammo_state: Dictionary,
) -> Dictionary:
	return ammo_state.duplicate()

func play_shot_fx() -> void:
	pass

func play_hit_fx(_at: Vector3) -> void:
	pass
