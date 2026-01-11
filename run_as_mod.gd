extends Node

# This is your game core - that is also built with addons/gsom_modapi
# And whatever other addons and game init logic
const CORE_PCK: String = "res://gdignore/core.pck"

# Name of the core startup script (same for game and all mods)
const CORE_SCRIPT: String = "res://core/core.gd"

func _ready() -> void:
	GsomModapi.launch(CORE_PCK, CORE_SCRIPT)
