extends CharacterBody3D
class_name CharPlayer

@onready var __mesh: MeshInstance3D = $Mesh
@onready var __hand: Marker3D = $Mesh/Hand

const SPEED: float = 5.0
const DECELERATION: float = 20.0
const JUMP_VELOCITY: float = 4.5
const __PATH_SLOT_SCENE: StringName = GsomModContent.PATH_SCENE

var __move_input: Vector2 = Vector2.ZERO
var __jump_queued: bool = false
var __move_yaw: float = 0.0
var __aim_pitch: float = 0.0
var __shoot_primary_held: bool = false
var __shoot_secondary_held: bool = false
var __reload_queued: bool = false
var __is_reserved: bool = false
var __saved_collision_layer: int = 0
var __saved_collision_mask: int = 0
var __has_saved_collision: bool = false
var __world_weapon_item_id: StringName = &""
var __world_weapon_hidden: bool = false
var __world_weapon_instance: Node = null
var __world_weapon_component: GsomComponentWeapon = null
var __is_local_owned: bool = false

func pawn_reset_actions() -> void:
	__move_input = Vector2.ZERO
	__jump_queued = false
	__shoot_primary_held = false
	__shoot_secondary_held = false
	__reload_queued = false

func pawn_apply_actions(input: CtlPlayer.PlayerInput) -> void:
	__move_input = input.move.limit_length(1.0)
	if input.jump:
		__jump_queued = true
	__move_yaw = input.yaw
	__aim_pitch = input.pitch
	rotation.y = __move_yaw
	__shoot_primary_held = input.shoot_primary
	__shoot_secondary_held = input.shoot_secondary
	if input.reload:
		__reload_queued = true

func pawn_get_aim_yaw() -> float:
	return __move_yaw

func pawn_get_aim_pitch() -> float:
	return __aim_pitch

func pawn_is_shoot_primary_held() -> bool:
	return __shoot_primary_held

func pawn_is_shoot_secondary_held() -> bool:
	return __shoot_secondary_held

func pawn_consume_reload_queued() -> bool:
	var queued: bool = __reload_queued
	__reload_queued = false
	return queued

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

func pawn_set_world_weapon_item(item_id: StringName, hidden: bool) -> void:
	if __world_weapon_item_id != item_id:
		__world_weapon_item_id = item_id
		__refresh_world_weapon_instance()
	if __world_weapon_hidden != hidden:
		__world_weapon_hidden = hidden
		__set_world_weapon_hidden(hidden)

func pawn_set_local_owned(local_owned: bool) -> void:
	__is_local_owned = local_owned
	if __mesh:
		__mesh.visible = !local_owned

func pawn_play_world_weapon_flash() -> void:
	if !__world_weapon_instance:
		return
	if __world_weapon_hidden:
		return
	if __world_weapon_component:
		__world_weapon_component.play_shot_fx()
		return
	if !__world_weapon_instance.has_method("weapon_play_muzzle_flash"):
		return
	__world_weapon_instance.call("weapon_play_muzzle_flash")

func pawn_play_world_weapon_hit_fx(at: Vector3) -> void:
	if !__world_weapon_instance:
		return
	if __world_weapon_component:
		__world_weapon_component.play_hit_fx(at)
		return
	if __world_weapon_instance.has_method("weapon_play_sfx_hit"):
		__world_weapon_instance.call("weapon_play_sfx_hit", at)

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

func __refresh_world_weapon_instance() -> void:
	if __world_weapon_instance:
		__world_weapon_instance.queue_free()
		__world_weapon_instance = null
	__world_weapon_component = null
	if !__hand:
		return
	if __world_weapon_item_id == &"":
		return
	var content: GsomModContent = GsomModapi.content_by_id(__world_weapon_item_id)
	if !content:
		return
	var scene_path: StringName = content.get_path_slot(__PATH_SLOT_SCENE)
	if scene_path == &"":
		return
	var scene: PackedScene = load(scene_path) as PackedScene
	if !scene:
		return
	var instance: Node = scene.instantiate()
	__hand.add_child(instance)
	if instance is Node3D:
		var instance_3d: Node3D = instance as Node3D
		instance_3d.transform = Transform3D.IDENTITY
	__world_weapon_instance = instance
	__world_weapon_component = __find_weapon_component(instance)
	__set_world_weapon_hidden(__world_weapon_hidden)

func __set_world_weapon_hidden(hidden: bool) -> void:
	if !__world_weapon_instance:
		return
	if __world_weapon_instance is Node3D:
		var instance_3d: Node3D = __world_weapon_instance as Node3D
		instance_3d.visible = !hidden

func __find_weapon_component(node: Node) -> GsomComponentWeapon:
	if node is GsomComponentWeapon:
		return node as GsomComponentWeapon
	for child: Node in node.get_children():
		var found: GsomComponentWeapon = __find_weapon_component(child)
		if found:
			return found
	return null
