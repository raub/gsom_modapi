extends CharacterBody3D
class_name CharPlayer


const SPEED: float = 5.0
const JUMP_VELOCITY: float = 4.5

var __move_input: Vector2 = Vector2.ZERO
var __jump_queued: bool = false
var __move_yaw: float = 0.0

func pawn_apply_actions(actions: Dictionary) -> void:
	if actions.has("move") and typeof(actions["move"]) == TYPE_VECTOR2:
		var wish_vec: Vector2 = actions["move"]
		__move_input = wish_vec.limit_length(1.0)
	if actions.get("jump", false):
		__jump_queued = true
	if actions.has("yaw"):
		__move_yaw = actions["yaw"]

func pawn_tick(delta: float) -> void:
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
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
