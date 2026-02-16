extends CharacterBody3D
class_name CharPlayer


const SPEED: float = 5.0
const DECELERATION: float = 20.0
const JUMP_VELOCITY: float = 4.5

var __move_input: Vector2 = Vector2.ZERO
var __jump_queued: bool = false
var __move_yaw: float = 0.0
var __is_reserved: bool = false
var __saved_collision_layer: int = 0
var __saved_collision_mask: int = 0
var __has_saved_collision: bool = false

func pawn_reset_actions() -> void:
	__move_input = Vector2.ZERO
	__jump_queued = false

func pawn_apply_actions(actions: Dictionary) -> void:
	var move_v: Variant = actions.get("move", null)
	if typeof(move_v) == TYPE_VECTOR2:
		var wish_vec: Vector2 = move_v
		__move_input = wish_vec.limit_length(1.0)
	var jump_v: Variant = actions.get("jump", null)
	if typeof(jump_v) == TYPE_BOOL and jump_v:
		__jump_queued = true
	var yaw_v: Variant = actions.get("yaw", null)
	if typeof(yaw_v) == TYPE_FLOAT or typeof(yaw_v) == TYPE_INT:
		__move_yaw = yaw_v

func pawn_set_reserved(reserved: bool) -> void:
	if __is_reserved == reserved:
		return
	__is_reserved = reserved
	pawn_reset_actions()
	if reserved:
		velocity = Vector3.ZERO
		if !__has_saved_collision:
			__saved_collision_layer = collision_layer
			__saved_collision_mask = collision_mask
			__has_saved_collision = true
		collision_layer = 0
		collision_mask = 0
	elif __has_saved_collision:
		collision_layer = __saved_collision_layer
		collision_mask = __saved_collision_mask

func pawn_tick(delta: float) -> void:
	if __is_reserved:
		return
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if __jump_queued and is_on_floor():
		velocity.y = JUMP_VELOCITY
	__jump_queued = false

	var move_basis: Basis = Basis(Vector3.UP, __move_yaw)
	var direction: Vector3 = (move_basis * Vector3(__move_input.x, 0, __move_input.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECELERATION * delta)
	move_and_slide()
