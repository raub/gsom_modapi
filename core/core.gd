extends GsomModCore

const __Environment: PackedScene = preload("./vfx/environment.tscn")
const __Splash: PackedScene = preload("./ui/splash/splash.tscn")
const __Menu: PackedScene = preload("./ui/menu/menu.tscn")

var __menu: UiMenu = null
var __svc_network: GsomNetworkImpl = null
var __precached: Array[Resource] = []

func _get_version() -> StringName:
	return &"0.0.1"

func _mod_init() -> void:
	var mode_dungeon: GsomModContentGamemode = GsomModContentGamemode.new()
	mode_dungeon.ui_title = "Escape"
	mode_dungeon.ui_tooltip = "Play corridor-shooter mode in research labs."
	mode_dungeon.ui_summary = "Clear rooms and corridors to escape the lab complex."
	mode_dungeon.path_thumbnail = &"res://core/content/mode_dungeon/dungeon.png"
	mode_dungeon.path_scene = &"res://core/content/mode_dungeon/mode_dungeon.tscn"
	mode_dungeon.path_replicator = &"res://core/content/mode_dungeon/replicator.gd"
	mode_dungeon.dep_queries = [
		GsomModQueryFilter.from_tags_all([&"dungeon", &"always"]),
		GsomModQueryFilter.from_tags_all([&"player", &"fps"]),
	]
	
	var room_labs: GsomModContentRoom = GsomModContentRoom.new()
	room_labs.add_tags([&"core", &"dungeon"])
	room_labs.path_scene = &"res://core/content/room_labs/room_labs.tscn"

	var char_player: GsomModContentCharacter = GsomModContentCharacter.new()
	char_player.add_tags([&"core", &"dungeon", &"character", &"always"])
	char_player.path_scene = &"res://core/content/char_player/char_player.tscn"

	var ctl_player: GsomModContentController = GsomModContentController.new()
	ctl_player.add_tags([&"core", &"player", &"fps"])
	ctl_player.path_scene = &"res://core/content/ctl_player/ctl_player.tscn"

	GsomModapi.register(mode_dungeon)
	GsomModapi.register(room_labs)
	
	GsomModapi.register(char_player)
	GsomModapi.register(ctl_player)

func _core_main() -> void:
	__svc_network = GsomNetworkImpl.new()
	__svc_network.gamemode_started.connect(__hide_menu)
	__svc_network.gamemode_ended.connect(__show_menu)
	GsomModapi.scene.add_child(__svc_network)
	
	var environment: WorldEnvironment = __Environment.instantiate()
	GsomModapi.scene.add_child(environment)
	
	var splash: Control = __Splash.instantiate()
	splash.modulate = Color(1, 1, 1, 0)
	GsomModapi.scene.add_child(splash)
	
	var tween: Tween = GsomModapi.scene.create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(splash, "modulate", Color(1, 1, 1, 1), 0.2)
	tween.tween_interval(1.0)
	tween.tween_property(splash, "modulate", Color(1, 1, 1, 0), 0.4)
	
	tween.tween_callback(func () -> void: splash.queue_free())
	tween.tween_callback(__show_menu)
	
	var query: GsomModQueryFilter = GsomModQueryFilter.new()
	query.kinds = [&"gamemode"]
	var precache_list: Array[StringName] = GsomModapi.traverse_query(query)
	for path: StringName in precache_list:
		__precache.call_deferred(path)

func __precache(path: StringName) -> void:
	var res: Resource = load(path)
	__precached.append(res)
	prints("Precached:", path, Time.get_ticks_usec())

func __show_menu() -> void:
	__menu = __Menu.instantiate()
	__menu.modulate = Color(1, 1, 1, 0)
	GsomModapi.scene.add_child(__menu)
	
	__menu.started_new_game.connect(__launch_new_game)
	
	var tween: Tween = GsomModapi.scene.create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(__menu, "modulate", Color(1, 1, 1, 1), 0.2)

func __hide_menu() -> void:
	if !__menu:
		push_warning("Menu already hidden.")
		return
	__menu.hide()
	__menu.queue_free()
	__menu = null

func __launch_new_game(content_id: StringName) -> void:
	__svc_network.gamemode_start(content_id)
