extends Node3D
class_name CtlPlayer

## This node captures player controls and applies the actions.
## In terms of Position - it follows the currently controlled pawn.
## For Rotation, it separately rotates "body" for YAW and "head" for PITCH.

class PlayerInput extends RefCounted:
	var move: Vector2 = Vector2.ZERO
	var jump: bool = false
	var yaw: float = 0.0

class PlayerActions extends RefCounted:
	var yaw: float = 0.0
	var pitch: float = 0.0
	var dt: float = 0.0
	var pawn_state: Variant = null

const __MOUSE_SENSITIVITY: float = 0.0025
const __PITCH_MIN: float = deg_to_rad(-85.0)
const __PITCH_MAX: float = deg_to_rad(85.0)
const __EYE_HEIGHT: float = 1.6
const __ACTION_MOVELEFT: StringName = &"move_left"
const __ACTION_MOVERIGHT: StringName = &"move_right"
const __ACTION_MOVEFORWARD: StringName = &"move_forward"
const __ACTION_MOVEBACKWARD: StringName = &"move_backward"
const __ACTION_JUMP: StringName = &"move_jump"
const __ACTION_TOGGLEMOUSE: StringName = &"move_toggle_mouse"

@onready var __body: Node3D = $Body
@onready var __head: Node3D = $Body/Head
@onready var __camera: Camera3D = $Body/Head/Camera3D

var __is_local: bool = false
var __is_enabled: bool = true
var __pawn: Node3D = null
var __yaw: float = 0.0
var __pitch: float = 0.0
var __look_accum: Vector2 = Vector2.ZERO

func _ready() -> void:
	__apply_local_camera_state()
	__apply_view()

func _exit_tree() -> void:
	if __is_local and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if !__check_local_active():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		__look_accum += motion.relative

func controller_set_local(is_local: bool) -> void:
	__is_local = is_local
	__apply_local_camera_state()

func controller_set_enabled(enabled: bool) -> void:
	__is_enabled = enabled
	__apply_local_camera_state()

func controller_set_pawn(pawn: Node3D) -> void:
	__pawn = pawn
	__sync_to_pawn()

func controller_local_tick(_delta: float) -> Variant:
	if !__check_local_active():
		return null
	if Input.is_action_just_pressed(__ACTION_TOGGLEMOUSE) or Input.is_action_just_pressed("ui_cancel"):
		__toggle_mouse_mode()
	__consume_look()
	__sync_to_pawn()
	var move: Vector2 = Input.get_vector(
		__ACTION_MOVELEFT,
		__ACTION_MOVERIGHT,
		__ACTION_MOVEFORWARD,
		__ACTION_MOVEBACKWARD,
	)
	if move == Vector2.ZERO:
		move = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input: PlayerInput = PlayerInput.new()
	input.move = move
	input.jump = (
		Input.is_action_just_pressed(__ACTION_JUMP)
		or Input.is_action_just_pressed("ui_accept")
	)
	input.yaw = __yaw
	return input

func controller_compose_actions(delta: float) -> PlayerActions:
	var actions: PlayerActions = PlayerActions.new()
	actions.dt = delta
	actions.yaw = __yaw
	actions.pitch = __pitch
	return actions

func controller_apply_actions(actions: Variant) -> void:
	var typed: PlayerActions = actions
	if !typed:
		return
	__yaw = typed.yaw
	__pitch = clampf(typed.pitch, __PITCH_MIN, __PITCH_MAX)
	__apply_view()
	__sync_to_pawn()

func controller_pack_snapshot() -> Dictionary:
	return {
		"yaw": __yaw,
		"pitch": __pitch,
	}

func controller_unpack_snapshot(snapshot: Dictionary, can_override_view: bool) -> void:
	if can_override_view:
		var yaw_v: Variant = snapshot.get("yaw", null)
		if typeof(yaw_v) == TYPE_FLOAT or typeof(yaw_v) == TYPE_INT:
			__yaw = yaw_v
		var pitch_v: Variant = snapshot.get("pitch", null)
		if typeof(pitch_v) == TYPE_FLOAT or typeof(pitch_v) == TYPE_INT:
			var pitch_f: float = pitch_v
			__pitch = clampf(pitch_f, __PITCH_MIN, __PITCH_MAX)
		__apply_view()
	__sync_to_pawn()

func _local_tick(_delta: float) -> void:
	pass

func _sv_tick(_delta: float) -> void:
	__sync_to_pawn()

func _cl_tick(_delta: float) -> void:
	__sync_to_pawn()

func __consume_look() -> void:
	if __look_accum == Vector2.ZERO:
		return
	__yaw -= __look_accum.x * __MOUSE_SENSITIVITY
	__pitch -= __look_accum.y * __MOUSE_SENSITIVITY
	__pitch = clampf(__pitch, __PITCH_MIN, __PITCH_MAX)
	__look_accum = Vector2.ZERO
	__apply_view()

func __apply_view() -> void:
	__body.rotation.y = __yaw
	__head.rotation.x = __pitch

func __sync_to_pawn() -> void:
	if !__pawn:
		return
	global_position = __pawn.global_position + Vector3.UP * __EYE_HEIGHT

func __toggle_mouse_mode() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func __check_local_active() -> bool:
	return __is_local and __is_enabled

func __apply_local_camera_state() -> void:
	var is_local_active: bool = __check_local_active()
	__camera.current = is_local_active
	if is_local_active:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
