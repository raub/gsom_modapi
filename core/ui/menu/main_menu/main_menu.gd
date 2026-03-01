extends MarginContainer
class_name UiMenuMain

signal pressed(what: String)

@onready var __continue: Button = $MenuContainer/MenuRows/Continue
@onready var __new_game: Button = $MenuContainer/MenuRows/NewGame
@onready var __settings: Button = $MenuContainer/MenuRows/Settings
@onready var __quit: Button = $MenuContainer/MenuRows/Quit

var __network_is_host: bool = true
var __quit_action: String = "quit"

func _ready() -> void:
	__continue.pressed.connect(pressed.emit.bind("continue"))
	__new_game.pressed.connect(pressed.emit.bind("new_game"))
	__settings.pressed.connect(pressed.emit.bind("settings"))
	__quit.pressed.connect(__emit_quit_action)
	
	var game_modes: Array[GsomModContent] = GsomModapi.content_by_kind(&"gamemode")
	__new_game.disabled = game_modes.is_empty()
	__apply_network_role()

func set_network_is_host(is_host: bool) -> void:
	__network_is_host = is_host
	__apply_network_role()

func _input(event: InputEvent) -> void:
	if !(visible and event is InputEventKey):
		return
	
	var keyEvent: InputEventKey = event as InputEventKey
	if keyEvent.pressed and !keyEvent.echo and keyEvent.keycode == KEY_ESCAPE:
		__emit_quit_action()

func __emit_quit_action() -> void:
	pressed.emit(__quit_action)

func __apply_network_role() -> void:
	if !is_inside_tree():
		return
	__new_game.visible = __network_is_host
	if __network_is_host:
		__quit.text = "Quit"
		__quit_action = "quit"
	else:
		__quit.text = "Disconnect"
		__quit_action = "disconnect"
