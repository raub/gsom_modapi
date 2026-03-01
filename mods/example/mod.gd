extends GsomModMeta

func _get_version() -> StringName:
	return &"0.0.1"

func _mod_init() -> void:
	var mode_openworld: GsomModContentGamemode = GsomModContentGamemode.new()
	mode_openworld.set_text_slot(GsomModContent.TEXT_TITLE, "Extraction")
	mode_openworld.set_text_slot(GsomModContent.TEXT_TOOLTIP, "Play extraction mode in an open-world setting.")
	mode_openworld.set_text_slot(GsomModContent.TEXT_SUMMARY, "Survive and reach the extraction point.")
	mode_openworld.set_path_slot(
		GsomModContent.PATH_THUMBNAIL,
		&"res://mods/example/content/mode_openworld/openworld.png",
	)
	mode_openworld.set_path_slot(
		GsomModContent.PATH_SCENE,
		&"res://mods/example/content/mode_openworld/mode_openworld.tscn",
	)
	mode_openworld.set_path_slot(
		GsomModContent.PATH_REPLICATOR,
		&"res://mods/example/content/mode_openworld/replicator.gd",
	)
	
	var room_caverns: GsomModContentRoom = GsomModContentRoom.new()
	room_caverns.set_text_slot(GsomModContent.TEXT_TITLE, "Caverns")
	room_caverns.set_text_slot(GsomModContent.TEXT_TOOLTIP, "A vast network of underground tunnels.")
	room_caverns.set_text_slot(GsomModContent.TEXT_SUMMARY, "A vast network of underground tunnels.")
	room_caverns.set_path_slot(
		GsomModContent.PATH_THUMBNAIL,
		&"res://mods/example/content/mode_openworld/openworld.png",
	)
	room_caverns.set_path_slot(
		GsomModContent.PATH_SCENE,
		&"res://mods/example/content/room_caverns/room_caverns.tscn",
	)

	var room_island: GsomModContentRoom = GsomModContentRoom.new()
	room_island.set_text_slot(GsomModContent.TEXT_TITLE, "Island")
	room_island.set_text_slot(GsomModContent.TEXT_TOOLTIP, "A floating island in the middle of nowhere.")
	room_island.set_text_slot(GsomModContent.TEXT_SUMMARY, "A floating island in the middle of nowhere.")
	room_island.set_path_slot(
		GsomModContent.PATH_THUMBNAIL,
		&"res://mods/example/content/mode_openworld/openworld.png",
	)
	room_island.set_path_slot(
		GsomModContent.PATH_SCENE,
		&"res://mods/example/content/room_island/room_island.tscn",
	)

	GsomModapi.register(mode_openworld)
	GsomModapi.register(room_caverns)
	GsomModapi.register(room_island)
