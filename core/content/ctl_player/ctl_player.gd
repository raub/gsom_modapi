extends Node3D
class_name CtlPlayer

## This node captures player controls and applies the actions.
## In terms of Position - it follows the currently controlled pawn.
## For Rotation, it separately rotates "body" for YAW and "head" for PITCH.

class PlayerActions extends RefCounted:
	var move: Vector2 = Vector2.ZERO
	var jump: bool = false
	var yaw: float = 0.0
	var pitch: float = 0.0
	var dt: float = 0.0
	var pawn_state: Variant = null

const __MouseSensitivity: float = 0.0025
const __PitchMin: float = deg_to_rad(-85.0)
const __PitchMax: float = deg_to_rad(85.0)
const __EyeHeight: float = 1.6
const __ActionMoveLeft: StringName = &"move_left"
const __ActionMoveRight: StringName = &"move_right"
const __ActionMoveForward: StringName = &"move_forward"
const __ActionMoveBackward: StringName = &"move_backward"
const __ActionJump: StringName = &"move_jump"
const __ActionToggleMouse: StringName = &"move_toggle_mouse"

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
	if Input.is_action_just_pressed(__ActionToggleMouse) or Input.is_action_just_pressed("ui_cancel"):
		__toggle_mouse_mode()
	__consume_look()
	__sync_to_pawn()
	var move: Vector2 = Input.get_vector(
		__ActionMoveLeft,
		__ActionMoveRight,
		__ActionMoveForward,
		__ActionMoveBackward,
	)
	if move == Vector2.ZERO:
		move = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var actions: PlayerActions = PlayerActions.new()
	actions.move = move
	actions.jump = (
		Input.is_action_just_pressed(__ActionJump)
		or Input.is_action_just_pressed("ui_accept")
	)
	actions.yaw = __yaw
	actions.pitch = __pitch
	return actions

func controller_apply_actions(actions: Variant) -> void:
	var typed: PlayerActions = actions
	if !typed:
		return
	__yaw = typed.yaw
	__pitch = clampf(typed.pitch, __PitchMin, __PitchMax)
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
			__pitch = clampf(pitch_v, __PitchMin, __PitchMax)
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
	__yaw -= __look_accum.x * __MouseSensitivity
	__pitch -= __look_accum.y * __MouseSensitivity
	__pitch = clampf(__pitch, __PitchMin, __PitchMax)
	__look_accum = Vector2.ZERO
	__apply_view()

func __apply_view() -> void:
	__body.rotation.y = __yaw
	__head.rotation.x = __pitch

func __sync_to_pawn() -> void:
	if !__pawn:
		return
	global_position = __pawn.global_position + Vector3.UP * __EyeHeight

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
