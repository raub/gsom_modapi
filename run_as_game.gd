extends Node

# Name of the core startup script (same for game and all mods)
const CORE_SCRIPT: String = "res://core/core.gd"

func _ready() -> void:
	GsomModapi.launch("", CORE_SCRIPT)
