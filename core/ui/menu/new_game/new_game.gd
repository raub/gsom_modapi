extends Control
class_name UiMenuNewGame

signal selected_mode(id: StringName)
signal pressed_back()

const __GameMode: PackedScene = preload("./game_mode/game_mode.tscn")

@onready var __mode_rows: VBoxContainer = $VBoxContainer/MarginContainer/ScrollContainer/ModeRows
@onready var __back: Button = $VBoxContainer/HBoxContainer/Back

func _ready() -> void:
	__back.pressed.connect(pressed_back.emit)
	
	var game_modes: Array[GsomModContent] = GsomModapi.content_by_kind(&"gamemode")
	if game_modes.is_empty():
		return
	
	for gamemode: GsomModContent in game_modes:
		var mode_item: UiMenuGameMode = __GameMode.instantiate()
		mode_item.pressed.connect(selected_mode.emit.bind(gamemode.id))
		__mode_rows.add_child(mode_item)
		mode_item.call_deferred("set_from_content", gamemode)
	
	if __mode_rows.get_child_count():
		(__mode_rows.get_child(0) as Control).grab_focus()

func _input(event: InputEvent) -> void:
	if !(visible and event is InputEventKey):
		return
	
	var keyEvent: InputEventKey = event as InputEventKey
	if keyEvent.pressed and !keyEvent.echo and keyEvent.keycode == KEY_ESCAPE:
		hide()
