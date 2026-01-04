extends IController
class_name IGameMode

## Base interface for all game-modes.

enum SaveMode {
	## Saving a game is not supported
	NONE,
	## Checkpoint-based saving
	CHECK,
	## Save at any moment
	QUICK,
}

## Auxiliary menu items from this game mode.
##
## Core converts them into simple menu buttons.
## Nothing fancy here - press or not press, no extra styles or hotkeys.
class MenuItem:
	var action: StringName = ""
	var title: String = ""
	var disabled: bool = false
	var tooltip: String = ""

## How does this game-mode work with saves
var save_mode: SaveMode = SaveMode.NONE

## Called when Core wants a save-able data dump
func _save_game() -> Variant:
	return null # null means can't be saved

## A request from Core to rewire the game to this state
func _load_game(_save: Variant) -> void:
	pass

## When ESC menu shown by Core, game mode can add stuff
##
## Core decides how and how many of them will be placed (i.e. a maximum of 2).
## You can only ever receive back `action` in `_execute_menu_item`.
## The rest is to be implemented inside the Game Mode.
func _generate_menu_items() -> Array[MenuItem]:
	return []

## Receive the name of the pressed (custom) ESC menu item
func _execute_menu_item(_action: StringName) -> void:
	pass
