extends Node

# Name of the core startup script (same for game and all mods)
const CORE_SCRIPT: String = "res://core/core.gd"

# Name of the core startup method (same for game and all mods)
const CORE_MAIN: String = "main"

func _ready() -> void:
	GsomModapi.launch("", CORE_SCRIPT, CORE_MAIN)
