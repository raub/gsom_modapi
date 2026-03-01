extends Node3D
class_name CtlPlayer

signal inventory_changed(item_ids: Array[StringName])

@onready var __hand: Node3D = $Body/Head/Camera3D/Hand
@onready var __hud: Control = $Hud
@onready var __item_log: Label = $Hud/ItemLog
@onready var __ammo: Label = $Hud/Ammo
@onready var __hp: Label = $Hud/Hp
@onready var __flash: ColorRect = $Hud/Flash
@onready var __cross: CenterContainer = $Hud/CrossContainer

## This node captures player controls and applies the actions.
## In terms of Position - it follows the currently controlled pawn.
## For Rotation, it separately rotates "body" for YAW and "head" for PITCH.

class PlayerInput extends RefCounted:
	var move: Vector2 = Vector2.ZERO
	var jump: bool = false
	var yaw: float = 0.0
	var pitch: float = 0.0
	var shoot_primary: bool = false
	var shoot_secondary: bool = false
	var reload: bool = false

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
const __ACTION_SHOOT_PRIMARY: StringName = &"shoot_primary"
const __ACTION_SHOOT_SECONDARY: StringName = &"shoot_secondary"
const __ACTION_RELOAD: StringName = &"weapon_reload"
const __ITEM_LOG_LINE_LIFETIME: float = 3.0
const __DEFAULT_STUB_HP: int = 100

@onready var __body: Node3D = $Body
@onready var __head: Node3D = $Body/Head
@onready var __camera: Camera3D = $Body/Head/Camera3D

var __is_local: bool = false
var __is_enabled: bool = true
var __pawn: Node3D = null
var __yaw: float = 0.0
var __pitch: float = 0.0
var __look_accum: Vector2 = Vector2.ZERO
var __inventory_item_ids: Array[StringName] = []
var __item_log_lines: Array[String] = []
var __item_log_countdown: float = -1.0
var __flash_tween: Tween = null
var __view_model_item_id: StringName = &""
var __view_model_instance: Node = null
var __view_model_weapon_component: GsomComponentWeapon = null
var __hp_value: int = __DEFAULT_STUB_HP
var __ammo_loaded_value: int = 0
var __ammo_stored_value: int = 0

func _ready() -> void:
	__setup_hud_nodes()
	__apply_local_camera_state()
	__apply_view()
	__refresh_hud_values()
	__refresh_item_log()
	__refresh_view_model()

func _process(delta: float) -> void:
	__tick_item_log(delta)

func _exit_tree() -> void:
	if __is_local and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if __view_model_instance:
		__view_model_instance.queue_free()
		__view_model_instance = null
	__view_model_weapon_component = null

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

func controller_set_inventory_ids(item_ids: Array[StringName]) -> void:
	if __inventory_item_ids == item_ids:
		return
	var previous: Array[StringName] = __inventory_item_ids.duplicate()
	__inventory_item_ids = item_ids.duplicate()
	__on_inventory_changed(previous, __inventory_item_ids)
	inventory_changed.emit(__inventory_item_ids.duplicate())

func controller_get_inventory_ids() -> Array[StringName]:
	return __inventory_item_ids.duplicate()

func controller_get_equipped_weapon_component() -> GsomComponentWeapon:
	return __view_model_weapon_component

func controller_set_hp(value: int) -> void:
	var hp_next: int = maxi(0, value)
	if __hp_value == hp_next:
		return
	__hp_value = hp_next
	__refresh_hud_values()

func controller_set_ammo(loaded: int, stored: int) -> void:
	var loaded_next: int = maxi(0, loaded)
	var stored_next: int = maxi(0, stored)
	if __ammo_loaded_value == loaded_next and __ammo_stored_value == stored_next:
		return
	__ammo_loaded_value = loaded_next
	__ammo_stored_value = stored_next
	__refresh_hud_values()

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
	input.pitch = __pitch
	input.shoot_primary = Input.is_action_pressed(__ACTION_SHOOT_PRIMARY)
	input.shoot_secondary = Input.is_action_pressed(__ACTION_SHOOT_SECONDARY)
	input.reload = Input.is_action_just_pressed(__ACTION_RELOAD)
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
	__hand.visible = is_local_active
	__hud.visible = __is_local
	if is_local_active:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func __setup_hud_nodes() -> void:
	__flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	__flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	__flash.visible = false

func __on_inventory_changed(previous: Array[StringName], current: Array[StringName]) -> void:
	for item_id: StringName in current:
		if previous.has(item_id):
			continue
		__on_item_added(item_id)
	__refresh_view_model()

func __on_item_added(item_id: StringName) -> void:
	var content: GsomModContent = GsomModapi.content_by_id(item_id)
	var item_name: String = String(item_id)
	if content:
		if content.ui_title.strip_edges() != "":
			item_name = content.ui_title
		elif content.kind != &"":
			item_name = String(content.kind)
	__push_item_log("Picked up: %s" % item_name)
	__play_pickup_flash()

func __refresh_view_model() -> void:
	var desired_item_id: StringName = &""
	if !__inventory_item_ids.is_empty():
		desired_item_id = __inventory_item_ids[__inventory_item_ids.size() - 1]
	if desired_item_id == __view_model_item_id:
		return

	__view_model_item_id = desired_item_id
	if __view_model_instance:
		__view_model_instance.queue_free()
		__view_model_instance = null
	__view_model_weapon_component = null

	if desired_item_id == &"":
		return

	var content: GsomModContent = GsomModapi.content_by_id(desired_item_id)
	if !content or content.path_scene == &"":
		return
	var scene: PackedScene = load(content.path_scene) as PackedScene
	if !scene:
		return
	var instance: Node = scene.instantiate()
	__hand.add_child(instance)
	__view_model_instance = instance
	__view_model_weapon_component = __find_weapon_component(instance)
	
	if instance is Node3D:
		var as_3d: Node3D = instance as Node3D
		as_3d.transform = Transform3D.IDENTITY

func __find_weapon_component(instance: Node) -> GsomComponentWeapon:
	for child: Node in instance.get_children():
		if child is GsomComponentWeapon:
			return child as GsomComponentWeapon
	return null

func __push_item_log(line: String) -> void:
	if line.strip_edges() == "":
		return
	__item_log_lines.append(line)
	if __item_log_lines.size() == 1:
		__item_log_countdown = __ITEM_LOG_LINE_LIFETIME
	__refresh_item_log()

func __tick_item_log(delta: float) -> void:
	if __item_log_lines.is_empty():
		__item_log_countdown = -1.0
		return

	if __item_log_countdown < 0.0:
		__item_log_countdown = __ITEM_LOG_LINE_LIFETIME
	__item_log_countdown -= delta
	if __item_log_countdown > 0.0:
		return

	__item_log_lines.remove_at(0)
	if __item_log_lines.is_empty():
		__item_log_countdown = -1.0
	else:
		__item_log_countdown = __ITEM_LOG_LINE_LIFETIME
	__refresh_item_log()

func __refresh_item_log() -> void:
	if __item_log_lines.is_empty():
		__item_log.hide()
		__item_log.text = ""
		return
	__item_log.show()
	__item_log.text = "\n".join(__item_log_lines)

func __refresh_hud_values() -> void:
	__hp.text = "%d" % [maxi(0, __hp_value)]
	__ammo.text = "%d | %d" % [maxi(0, __ammo_loaded_value), maxi(0, __ammo_stored_value)]

func __play_pickup_flash() -> void:
	if __flash_tween:
		__flash_tween.kill()
	__flash.show()
	__flash.modulate = Color(0.7, 1.0, 0.7, 0.0)
	__flash_tween = create_tween()
	__flash_tween.set_trans(Tween.TRANS_SINE)
	__flash_tween.tween_property(__flash, "modulate", Color(0.7, 1.0, 0.7, 0.3), 0.08)
	__flash_tween.tween_property(__flash, "modulate", Color(0.7, 1.0, 0.7, 0.0), 0.18)
	__flash_tween.finished.connect(func() -> void:
		__flash.hide()
	)
