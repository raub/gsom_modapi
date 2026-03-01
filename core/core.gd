extends GsomModCore

const __Environment: PackedScene = preload("./vfx/environment.tscn")
const __Splash: PackedScene = preload("./ui/splash/splash.tscn")
const __PathMenu: StringName = &"res://core/ui/menu/menu.tscn"
const __ActionMoveLeft: StringName = &"move_left"
const __ActionMoveRight: StringName = &"move_right"
const __ActionMoveForward: StringName = &"move_forward"
const __ActionMoveBackward: StringName = &"move_backward"
const __ActionJump: StringName = &"move_jump"
const __ActionToggleMouse: StringName = &"move_toggle_mouse"
const __ActionShootPrimary: StringName = &"shoot_primary"
const __ActionShootSecondary: StringName = &"shoot_secondary"
const __ActionReload: StringName = &"weapon_reload"

var __menu: UiMenu = null
var __svc_network: GsomNetworkImpl = null
var __menu_load_resources: Array[StringName] = []

func _get_version() -> StringName:
	return &"0.0.1"

func _mod_init() -> void:
	var mode_dungeon: GsomModContentGamemode = GsomModContentGamemode.new()
	mode_dungeon.ui_title = "Escape"
	mode_dungeon.ui_tooltip = "Play corridor-shooter mode in research labs."
	mode_dungeon.ui_summary = "Clear rooms and corridors to escape the lab complex."
	mode_dungeon.set_path_slot(GsomModContent.PATH_THUMBNAIL, &"res://core/content/mode_dungeon/dungeon.png")
	mode_dungeon.set_path_slot(GsomModContent.PATH_SCENE, &"res://core/content/mode_dungeon/mode_dungeon.tscn")
	mode_dungeon.set_path_slot(GsomModContent.PATH_REPLICATOR, &"res://core/content/mode_dungeon/replicator.gd")
	mode_dungeon.dep_queries = [
		GsomModQueryFilter.from_tags_all([&"dungeon", &"always"]),
		GsomModQueryFilter.from_tags_all([&"player", &"fps"]),
	]
	
	var room_labs: GsomModContentRoom = GsomModContentRoom.new()
	room_labs.add_tags([&"core", &"dungeon"])
	room_labs.set_path_slot(GsomModContent.PATH_SCENE, &"res://core/content/room_labs/room_labs.tscn")

	var char_player: GsomModContentCharacter = GsomModContentCharacter.new()
	char_player.add_tags([&"core", &"dungeon", &"character", &"always"])
	char_player.set_path_slot(GsomModContent.PATH_SCENE, &"res://core/content/char_player/char_player.tscn")
	char_player.set_path_slot(GsomModContent.PATH_REPLICATOR, &"res://core/content/char_player/replicator.gd")

	var ctl_player: GsomModContentController = GsomModContentController.new()
	ctl_player.add_tags([&"core", &"player", &"fps"])
	ctl_player.set_path_slot(GsomModContent.PATH_SCENE, &"res://core/content/ctl_player/ctl_player.tscn")
	ctl_player.set_path_slot(GsomModContent.PATH_REPLICATOR, &"res://core/content/ctl_player/replicator.gd")

	var wpn_pistol: GsomModContentWeapon = GsomModContentWeapon.new()
	wpn_pistol.add_tags([&"core", &"weapon", &"pistol"])
	wpn_pistol.set_path_slot(GsomModContent.PATH_SCENE, &"res://core/content/wpn_pistol/wpn_pistol.tscn")
	wpn_pistol.set_path_slot(GsomModContent.PATH_REPLICATOR, &"res://core/content/wpn_pistol/replicator.gd")
	wpn_pistol.set_path_slot(&"crosshair", &"res://core/content/wpn_pistol/crosshair.tscn")

	GsomModapi.register(mode_dungeon)
	GsomModapi.register(room_labs)

	GsomModapi.register(char_player)
	GsomModapi.register(ctl_player)
	GsomModapi.register(wpn_pistol)

func _core_main() -> void:
	__ensure_runtime_input_actions()

	__svc_network = GsomNetworkImpl.new()
	__svc_network.gamemode_started.connect(__hide_menu)
	__svc_network.gamemode_ended.connect(__load_and_show_menu)
	GsomModapi.scene.add_child(__svc_network)

	__menu_load_resources = __build_menu_load_resources()
	__svc_network._sv_load_start("menu", __menu_load_resources)
	
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
	tween.tween_callback(func () -> void:
		__show_menu_on_load_epoch(__svc_network.local_peer._get_load_epoch())
	)

func __build_menu_load_resources() -> Array[StringName]:
	var query: GsomModQueryFilter = GsomModQueryFilter.new()
	query.kinds = [&"gamemode"]
	var resources: Array[StringName] = GsomModapi.traverse_query(query)
	if !resources.has(__PathMenu):
		resources.append(__PathMenu)
	return resources

func __load_and_show_menu() -> void:
	__svc_network._sv_load_start("menu", __menu_load_resources)
	__show_menu_on_load_epoch(__svc_network.local_peer._get_load_epoch())

func __show_menu_on_load_epoch(epoch_id: int) -> void:
	var local_peer: GsomPeerImpl = __svc_network.local_peer
	if local_peer._get_load_epoch() != epoch_id or local_peer._get_load_progress() < 1.0:
		__show_menu_on_load_epoch.call_deferred(epoch_id)
		return
	__show_menu()

func __show_menu() -> void:
	var menu_scene: PackedScene = load(__PathMenu) as PackedScene
	if !menu_scene:
		push_error("Failed to load menu scene '%s'." % __PathMenu)
		return
	__menu = menu_scene.instantiate()
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

func __ensure_runtime_input_actions() -> void:
	__ensure_input_action_keys(__ActionMoveLeft, [KEY_A, KEY_LEFT])
	__ensure_input_action_keys(__ActionMoveRight, [KEY_D, KEY_RIGHT])
	__ensure_input_action_keys(__ActionMoveForward, [KEY_W, KEY_UP])
	__ensure_input_action_keys(__ActionMoveBackward, [KEY_S, KEY_DOWN])
	__ensure_input_action_keys(__ActionJump, [KEY_SPACE])
	__ensure_input_action_keys(__ActionToggleMouse, [KEY_ESCAPE])
	__ensure_input_action_keys(__ActionReload, [KEY_R])
	__ensure_input_action_mouse_button(__ActionShootPrimary, MOUSE_BUTTON_LEFT)
	__ensure_input_action_mouse_button(__ActionShootSecondary, MOUSE_BUTTON_RIGHT)

func __ensure_input_action_keys(action: StringName, keys: Array[Key]) -> void:
	if !InputMap.has_action(action):
		InputMap.add_action(action)
	var existing_events: Array[InputEvent] = InputMap.action_get_events(action)
	if !existing_events.is_empty():
		return
	for keycode: Key in keys:
		var key_event: InputEventKey = InputEventKey.new()
		key_event.physical_keycode = keycode
		InputMap.action_add_event(action, key_event)

func __ensure_input_action_mouse_button(action: StringName, button: MouseButton) -> void:
	if !InputMap.has_action(action):
		InputMap.add_action(action)
	var existing_events: Array[InputEvent] = InputMap.action_get_events(action)
	if !existing_events.is_empty():
		return
	var button_event: InputEventMouseButton = InputEventMouseButton.new()
	button_event.button_index = button
	InputMap.action_add_event(action, button_event)
