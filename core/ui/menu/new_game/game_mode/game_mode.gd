extends Button
class_name UiMenuGameMode

@onready var __title: Label = $MarginContainer/HBoxContainer/VBoxContainer/Title
@onready var __summary: Label = $MarginContainer/HBoxContainer/VBoxContainer/Summary
@onready var __texture_rect: TextureRect = $MarginContainer/HBoxContainer/TextureRect

func set_from_content(gamemode: GsomModContent) -> void:
	tooltip_text = gamemode.ui_tooltip
	__title.text = gamemode.ui_title
	__summary.text = gamemode.ui_summary
	if gamemode.path_thumbnail:
		var texture: Texture2D = load(gamemode.path_thumbnail)
		__texture_rect.texture = texture
		
