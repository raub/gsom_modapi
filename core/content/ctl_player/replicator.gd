extends IGsomPlayer

func _local_tick(_dt: float) -> Variant:
	assert(false, "Not implemented")
	return null

func _apply_actions(_actions: Variant) -> void:
	assert(false, "Not implemented")

func _sv_peer_update(_peer: IGsomPeer) -> void:
	pass

func _sv_tick(_dt: float) -> void:
	pass

func _cl_tick(_dt: float) -> void:
	pass

func _cl_ready() -> void:
	pass

func _sv_ready() -> void:
	pass

func _cl_unpack(_snapshot: Variant) -> void:
	pass

func _sv_pack(_lod: RelevancyLod) -> Variant:
	return null

func _sv_read_event(_peer: IGsomPeer, _e: Event) -> void:
	pass

func _cl_read_event(_e: Event) -> void:
	pass
