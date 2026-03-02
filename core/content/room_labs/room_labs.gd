extends Node3D
class_name RoomLabs

func _ready() -> void:
	pass

static func register() -> void:
	var room_labs: GsomModContentRoom = GsomModContentRoom.new()
	room_labs.add_tags([&"core", &"dungeon"])
	room_labs.set_path_slot(GsomModContent.PATH_SCENE, &"res://core/content/room_labs/room_labs.tscn")
	room_labs.set_path_slot("mat_floor", &"res://core/content/room_labs/vfx/floor.material")
	room_labs.set_path_slot("mat_wall", &"res://core/content/room_labs/vfx/wall.material")

	GsomModapi.register(room_labs)
	
