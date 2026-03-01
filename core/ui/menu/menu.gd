extends Control
class_name UiMenu

signal started_new_game(id: StringName)
signal requested_disconnect()

@onready var __main_menu: UiMenuMain = $MainMenu
@onready var __new_game: UiMenuNewGame = $NewGame

var __network_is_host: bool = true

func _ready() -> void:
	__main_menu.pressed.connect(__handle_main_menu)
	__new_game.pressed_back.connect(__restore_main_menu)
	__new_game.selected_mode.connect(__handle_new_game)
	__main_menu.set_network_is_host(__network_is_host)
	
	__restore_main_menu()

func set_network_is_host(is_host: bool) -> void:
	__network_is_host = is_host
	if __main_menu:
		__main_menu.set_network_is_host(is_host)

func __handle_main_menu(what: String) -> void:
	if what == "new_game":
		if !__network_is_host:
			return
		var game_modes: Array[GsomModContent] = GsomModapi.content_by_kind(&"gamemode")
		if game_modes.size() == 1:
			__handle_new_game(game_modes[0].id)
		else:
			__show_new_game()
		
	if what == "settings":
		pass
	
	if what == "disconnect":
		requested_disconnect.emit()
		return
	
	if what == "quit":
		get_tree().quit()

func __handle_new_game(id: StringName) -> void:
	__new_game.hide()
	started_new_game.emit(id)

func __show_new_game() -> void:
	__main_menu.hide()
	__new_game.show()
	__new_game.grab_focus()

func __restore_main_menu() -> void:
	__new_game.hide()
	__main_menu.show()
	__main_menu.grab_focus()
