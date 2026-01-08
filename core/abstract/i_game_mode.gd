extends IController
class_name IGameMode

## Base interface for all game-modes.

## Auxiliary menu items from this game mode.
##
## Core converts them into simple menu buttons.
## Nothing fancy here - press or not press, no extra styles or hotkeys.
class MenuItem:
	## Item identity - this is what you get back in `_execute_menu_item`
	var action: StringName = &""
	## What is displayed
	var title: String = ""
	## It is possible to provide a disabled item, hopefully with a tooltip "why"
	var disabled: bool = false
	## Explain what this item does (actual menu components will decide how to show it)
	var tooltip: String = ""

## If host can save this game mode at will.
##
## Core will ask this to determine if manual "save/load" buttons are available.
func _can_manual_save() -> bool:
	return false

## Called when Core wants a save-able data dump.
##
## Returning `null` means not available at this moment.
## E.g. you probably don't want to save during loading or a cutscene.
##
## Note: this is only part of the saved data, here you mostly decide if it is worth saving.
## All network entities will be enumerated and written automatically.
## Only store the information that is not provided by `_sv_pack(RelevancyLod.MAX)`.
## Such as, encode the game mode compatibility version to validate during load.
func _sv_pack_game() -> Variant:
	return null

## A request from Core to rewire the game to this state.
##
## Return `true` if the save data is accepted, `false` otherwise.
##
## You can encode the game mode compatibility data when saving.
## I.e. the version, to reject the incompatible save files.
func _sv_unpack_game(_save: Variant) -> bool:
	return false

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

## Onboard a new peer.
##
## Called for each peer, when they join this game mode for the first time.
## I.e. when IGameMode instance created - for all pre-existing peers.
## And later for all newcomers while the game is on.
func _sv_peer_join(_peer: IPeer) -> void:
	pass

## Handle complete peer disconnection.
##
## This is the point of no return. Peer data will be erased, can't reconnect.
func _sv_peer_drop(_peer: IPeer) -> void:
	pass

## Update peer UI and/or their player entity.
##
## This includes the field `peer.connected` - to handle temporary disconnections.
func _sv_peer_update(_peer: IPeer) -> void:
	pass
