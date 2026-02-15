extends Node3D
class_name CtlPlayer

## This node captures player controls and applies the actions.
## In terms of Position - it follows the currently controlled pawn.
## For Rotation, this node only uses YAW, and Head - only PITCH.

const __MouseSensitivity: float = 0.0025
const __PitchMin: float = deg_to_rad(-85.0)
const __PitchMax: float = deg_to_rad(85.0)
const __EyeHeight: float = 1.6

@onready var __body: Node3D = $Body
@onready var __head: Node3D = $Body/Head
@onready var __camera: Camera3D = $Body/Head/Camera3D

var __is_local: bool = false
var __pawn: Node3D = null
var __yaw: float = 0.0
var __pitch: float = 0.0
var __look_accum: Vector2 = Vector2.ZERO

func _ready() -> void:
	__camera.current = false
	__apply_view()

func _exit_tree() -> void:
	if __is_local and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if !__is_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		__look_accum += motion.relative

func controller_set_local(is_local: bool) -> void:
	__is_local = is_local
	__camera.current = is_local
	if is_local and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func controller_set_pawn(pawn: Node3D) -> void:
	__pawn = pawn
	__sync_to_pawn()

func controller_local_tick(_delta: float) -> Dictionary:
	if !__is_local:
		return {}
	if Input.is_action_just_pressed("ui_cancel"):
		__toggle_mouse_mode()
	__consume_look()
	__sync_to_pawn()
	return {
		"move": Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down"),
		"jump": Input.is_action_just_pressed("ui_accept"),
		"yaw": __yaw,
		"pitch": __pitch,
	}

func controller_apply_actions(actions: Dictionary) -> void:
	if actions.has("yaw"):
		__yaw = actions["yaw"]
	if actions.has("pitch"):
		var pitch: float = actions["pitch"]
		__pitch = clampf(pitch, __PitchMin, __PitchMax)
	__apply_view()
	__sync_to_pawn()

func controller_pack_snapshot() -> Dictionary:
	return {
		"yaw": __yaw,
		"pitch": __pitch,
	}

func controller_unpack_snapshot(snapshot: Dictionary, can_override_view: bool) -> void:
	if can_override_view:
		if snapshot.has("yaw"):
			__yaw = snapshot["yaw"]
		if snapshot.has("pitch"):
			var pitch: float = snapshot["pitch"]
			__pitch = clampf(pitch, __PitchMin, __PitchMax)
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
