extends MarginContainer
class_name UiMenuMain

signal pressed(what: String)

@onready var __continue: Button = $MenuContainer/MenuRows/Continue
@onready var __new_game: Button = $MenuContainer/MenuRows/NewGame
@onready var __settings: Button = $MenuContainer/MenuRows/Settings
@onready var __quit: Button = $MenuContainer/MenuRows/Quit

func _ready() -> void:
	__continue.pressed.connect(pressed.emit.bind("continue"))
	__new_game.pressed.connect(pressed.emit.bind("new_game"))
	__settings.pressed.connect(pressed.emit.bind("settings"))
	__quit.pressed.connect(pressed.emit.bind("quit"))
	
	var game_modes: Array[GsomModContent] = GsomModapi.content_by_kind(&"gamemode")
	__new_game.disabled = game_modes.is_empty()

func _input(event: InputEvent) -> void:
	if !(visible and event is InputEventKey):
		return
	
	var keyEvent: InputEventKey = event as InputEventKey
	if keyEvent.pressed and !keyEvent.echo and keyEvent.keycode == KEY_ESCAPE:
		pressed.emit("quit")
