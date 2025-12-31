extends IGameMode

func _assign_data(_data: Variant) -> void:
	pass

func _assign_payload(_payload: Variant) -> void:
	pass

func _create_payload() -> Variant:
	return null

func _show_setup_screen() -> void:
	_change_state.call_deferred(State.LOAD)

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

## The default implementation simply ends the game in 5 seconds
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
