extends IReplicated
class_name IGameMode

## This is the base interface that all game-modes will implement.
##
## This class is opensourced for modders to share common ground in codebase.
##
## Core will always call these intended methods in specified way:
## 1. set scenes - these are the scenes to work on, i.e. layers.
## 2. set lobby - these are the players in the lobby.
## 3. [_show_setup_screen] - optionally called if this is "new game".
## 3.1. emit setup_completed - the Core will grab a new save state to hydrate the game.
## 4. _check_save_mode - how does this game-mode work with saves.
## 5. [_generate_save_state] - called when Core wants a save-able data dump.
## 6. _accept_save_state - a request to rewire the game to this state.
## 6.1. emit load_completed - finished loading, can play.
## 7. _generate_menu_items - when ESC menu shown, game mode can add stuff.
## 7.1. _execute_menu_item - receive the name of pressed menu item.
## 8. _sv_tick - authority: increment the game-mode simulation.
## 8.1. emit game_completed - the game has ended in one way or another.
## 8.2. _cl_tick - client-side: run local player and apply events from server.
## 9. _show_final_screen - display the game results before leaving.
## 9.1. emit final_closed - we can discard the game-mode and return to main menu.

signal load_completed()
signal final_closed()

enum SaveMode {
	NONE,
	CHECK,
	QUICK,
}

enum State {
	NONE, # no-op
	SETUP, # the setup screen is being displayed
	LOAD, # the level is loading
	PLAY, # the game is running
	PAUSE, # the game is running
	END, # the results screen is shown
}

var __state: State = State.NONE

class Save:
	var data: Variant = null
	var name: String = ""

class MenuItem:
	var action: StringName = ""
	var title: String = ""

class Payload:
	var state: State = State.NONE

func _assign_data(_data: Variant) -> void:
	pass

func _assign_payload(_payload: Variant) -> void:
	pass

func _create_payload() -> Variant:
	return null

func _show_setup_screen() -> void:
	_change_state.call_deferred(State.LOAD)

func _show_load_screen() -> void:
	_change_state.call_deferred(State.PLAY)

func _check_save_mode() -> SaveMode:
	return SaveMode.NONE

func _generate_save_state() -> Save:
	return null # null means can't be saved

func _accept_game_state(_save: Save) -> void:
	load_completed.emit()

func _generate_menu_items() -> Array[MenuItem]:
	return []

func _execute_menu_item(_action: StringName) -> void:
	pass

func _change_state(new_state: State) -> void:
	prints("_change_state: %s to %s" % [__state, new_state])
	if (
		__state == new_state
		or __state == State.END
		or __state == State.NONE and new_state != State.SETUP
		or __state == State.SETUP and new_state != State.LOAD
		or __state == State.LOAD and new_state != State.PLAY
		or __state == State.PLAY and ![State.LOAD, State.PAUSE, State.END].has(new_state)
		or __state == State.PAUSE and ![State.LOAD, State.PLAY, State.END].has(new_state)
	):
		push_warning("State transition failed: %s to %s" % [__state, new_state])
		return
	
	is_dirty = true
	__state = new_state
	
	if new_state == State.SETUP:
		_show_setup_screen()
	if new_state == State.LOAD:
		_show_load_screen()
	if new_state == State.END:
		_show_final_screen()


## The default implementation simply ends the game in 5 seconds
var __dont_use_ticks: float = 0
func _sv_tick(dt: float) -> void:
	if __state == State.NONE:
		_change_state(State.SETUP)
	
	if __state == State.PLAY:
		__dont_use_ticks += dt
		if __dont_use_ticks > 5:
			_change_state(State.END)

func _cl_tick(_dt: float) -> void:
	pass

func _show_final_screen() -> void:
	final_closed.emit()
