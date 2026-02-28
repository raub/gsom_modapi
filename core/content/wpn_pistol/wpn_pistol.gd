extends Node3D
class_name WpnPistol

@onready var __muzzle_flash: MeshInstance3D = $MuzzleFlash

const __MUZZLE_FLASH_TIME: float = 0.045

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
