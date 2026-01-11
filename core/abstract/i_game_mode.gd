extends IGsomController
class_name IGsomGameMode

## Base interface for all game-modes.
##
## This is what **mods should implement** to ship new game-modes.
## I.e. opposed to IGsomNetwork and IGsomPeer implementations, shipped by the Core.
##
## Note, guideline keywords:
## - [server] - this will not be called on clients.
## - [optional] - it's ok to omit implementation.

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

## [server optional] If host can save this game mode at will.
##
## Core will ask this to determine if manual "save/load" buttons are available.
func _sv_can_manual_save() -> bool:
	return false

## [server optional] Called when Core wants a save-able data dump.
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

## [server optional] A request from Core to rewire the game to this state.
##
## Return `true` if the save data is accepted, `false` otherwise.
##
## You can encode the game mode compatibility data when saving.
## I.e. the version, to reject the incompatible save files.
func _sv_unpack_game(_save: Variant) -> bool:
	return false

## [optional] When ESC menu shown by Core, game mode can add stuff
##
## Core decides how and how many of them will be placed (i.e. a maximum of 2).
## You can only ever receive back `action` in `_execute_menu_item`.
## The rest is to be implemented inside the Game Mode.
func _generate_menu_items() -> Array[MenuItem]:
	return []

## [optional] Receive the name of the pressed (custom) ESC menu item
func _execute_menu_item(_action: StringName) -> void:
	pass

## [server optional] Onboard a new peer.
##
## Called for each peer, when they join this game mode for the first time.
## I.e. when IGsomGameMode instance created - for all pre-existing peers.
## And later for all newcomers while the game is on.
func _sv_peer_join(_peer: IGsomPeer) -> void:
	pass

## [server optional] Handle complete peer disconnection.
##
## This is the point of no return. Peer data will be erased, can't reconnect.
func _sv_peer_drop(_peer: IGsomPeer) -> void:
	pass

## [server optional] Update peer UI and/or their player entity.
##
## This is called when peer fields are modified in any peer.
## When a peer disconnects/reconnects, it counts as an "update" too.
func _sv_peer_update(_peer: IGsomPeer) -> void:
	pass
