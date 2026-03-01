extends Button
class_name UiMenuGameMode

@onready var __title: Label = $MarginContainer/HBoxContainer/VBoxContainer/Title
@onready var __summary: Label = $MarginContainer/HBoxContainer/VBoxContainer/Summary
@onready var __texture_rect: TextureRect = $MarginContainer/HBoxContainer/TextureRect

func set_from_content(gamemode: GsomModContent) -> void:
	tooltip_text = gamemode.get_text_slot(GsomModContent.TEXT_TOOLTIP)
	__title.text = gamemode.get_text_slot(GsomModContent.TEXT_TITLE)
	__summary.text = gamemode.get_text_slot(GsomModContent.TEXT_SUMMARY)
	var thumbnail_path: StringName = gamemode.get_path_slot(GsomModContent.PATH_THUMBNAIL)
	if thumbnail_path != &"":
		var texture: Texture2D = load(thumbnail_path)
		__texture_rect.texture = texture
		
