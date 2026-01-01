extends GsomModMeta

func _get_version() -> StringName:
	return &"0.0.1"

func _mod_init() -> void:
	GsomModapi.register(preload("./content/mode_openworld/desc.tres"))
	GsomModapi.register(preload("./content/room_caverns/desc.tres"))
	GsomModapi.register(preload("./content/room_island/desc.tres"))
