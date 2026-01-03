extends Node3D

## This node captures player controls and applies the actions.
## In terms of Position - it follows the currently controlled pawn.
## For Rotation, this node only uses YAW, and Head - only PITCH.

@onready var __body: Node3D = $Body
@onready var __head: Node3D = $Body/Head

func _ready() -> void:
	pass

func _local_tick(_delta: float) -> void:
	pass

func _sv_tick(_delta: float) -> void:
	pass

func _cl_tick(_delta: float) -> void:
	pass
