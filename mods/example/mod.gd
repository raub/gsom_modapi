extends GsomModMeta

func _get_version() -> StringName:
	return &"0.0.1"

func _mod_init() -> void:
	var mode_openworld: GsomModContentGamemode = GsomModContentGamemode.new()
	mode_openworld.ui_title = "Extraction"
	mode_openworld.ui_tooltip = "Play extraction mode in an open-world setting."
	mode_openworld.ui_summary = "Survive and reach the extraction point."
	mode_openworld.path_thumbnail = &"res://mods/example/content/mode_openworld/openworld.png"
	mode_openworld.path_scene = &"res://mods/example/content/mode_openworld/mode_openworld.tscn"
	mode_openworld.path_replicator = &"res://mods/example/content/mode_openworld/replicator.gd"
	
	var room_caverns: GsomModContentRoom = GsomModContentRoom.new()
	room_caverns.ui_title = "Caverns"
	room_caverns.ui_tooltip = "A vast network of underground tunnels."
	room_caverns.ui_summary = "A vast network of underground tunnels."
	room_caverns.path_thumbnail = &"res://mods/example/content/mode_openworld/openworld.png"
	room_caverns.path_scene = &"res://mods/example/content/room_caverns/room_caverns.tscn"

	var room_island: GsomModContentRoom = GsomModContentRoom.new()
	room_island.ui_title = "Island"
	room_island.ui_tooltip = "A floating island in the middle of nowhere."
	room_island.ui_summary = "A floating island in the middle of nowhere."
	room_island.path_thumbnail = &"res://mods/example/content/mode_openworld/openworld.png"
	room_island.path_scene = &"res://mods/example/content/room_island/room_island.tscn"

	GsomModapi.register(mode_openworld)
	GsomModapi.register(room_caverns)
	GsomModapi.register(room_island)
