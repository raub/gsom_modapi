extends IGsomGameMode

# This example implementation simply ends the game in 5 seconds
var __ticks: float = 0

# Don't tick after game ends
var __sv_play: bool = true

func _sv_tick(dt: float) -> void:
	if !__sv_play:
		return
	__ticks += dt
	if __ticks > 5:
		__sv_play = false
		net._sv_despawn(net_id) # self-destruct
