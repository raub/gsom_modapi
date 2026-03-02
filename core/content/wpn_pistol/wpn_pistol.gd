extends Node3D
class_name WpnPistol

@onready var __muzzle_flash: MeshInstance3D = $MuzzleFlash

const __MUZZLE_FLASH_TIME: float = 0.045
const __SFX_SHOT_1: StringName = &"res://core/content/wpn_pistol/sfx/pl_gun3.wav"
const __SFX_HIT_1: StringName = &"res://core/content/wpn_pistol/sfx/bullet_hit1.wav"
const __SFX_HIT_2: StringName = &"res://core/content/wpn_pistol/sfx/bullet_hit2.wav"

var __muzzle_flash_tween: Tween = null

func _ready() -> void:
	if __muzzle_flash:
		__muzzle_flash.visible = false

func weapon_play_muzzle_flash(duration: float = __MUZZLE_FLASH_TIME) -> void:
	if !__muzzle_flash:
		return
	if __muzzle_flash_tween:
		__muzzle_flash_tween.kill()
		__muzzle_flash_tween = null
	__muzzle_flash.visible = true
	var flash_time: float = maxf(0.01, duration)
	__muzzle_flash_tween = create_tween()
	__muzzle_flash_tween.tween_interval(flash_time)
	__muzzle_flash_tween.finished.connect(func() -> void:
		if __muzzle_flash:
			__muzzle_flash.visible = false
		__muzzle_flash_tween = null
	)

func weapon_play_sfx_shot() -> void:
	SvcAudio.play3d(__SFX_SHOT_1, global_position)

func weapon_play_sfx_hit(at: Vector3) -> void:
	if randi() % 2:
		SvcAudio.play3d(__SFX_HIT_1, at)
	else:
		SvcAudio.play3d(__SFX_HIT_2, at)

static func register() -> void:
	var wpn_pistol: GsomModContentWeapon = GsomModContentWeapon.new()
	wpn_pistol.add_tags([&"core", &"weapon", &"pistol"])
	wpn_pistol.set_path_slot(GsomModContent.PATH_SCENE, &"res://core/content/wpn_pistol/wpn_pistol.tscn")
	wpn_pistol.set_path_slot(GsomModContent.PATH_REPLICATOR, &"res://core/content/wpn_pistol/replicator.gd")
	wpn_pistol.set_path_slot(&"crosshair", &"res://core/content/wpn_pistol/crosshair.tscn")
	wpn_pistol.set_path_slot(&"sfx_shot_1", __SFX_SHOT_1)
	wpn_pistol.set_path_slot(&"sfx_hit_1", __SFX_HIT_1)
	wpn_pistol.set_path_slot(&"sfx_hit_2", __SFX_HIT_2)
	GsomModapi.register(wpn_pistol)
	
