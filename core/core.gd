extends GsomModCore

const __Environment: PackedScene = preload("./vfx/environment.tscn")
const __Splash: PackedScene = preload("./ui/splash/splash.tscn")
const __Menu: PackedScene = preload("./ui/menu/menu.tscn")
const __SvcNetwork := preload("./services/network.gd")

var __menu: UiMenu = null
var __svc_network: SvcNetwork = null

func _get_version() -> StringName:
	return &"0.0.1"

func _mod_init() -> void:
	GsomModapi.register(preload("./content/mode_dungeon/desc.tres"))
	GsomModapi.register(preload("./content/char_player/desc.tres"))
	GsomModapi.register(preload("./content/ctl_player/desc.tres"))

func _core_main() -> void:
	__svc_network = __SvcNetwork.new()
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
	__svc_network._spawn(content_id, &"controller")
