extends Node
class_name SvcAudio

static func play(path: StringName) -> void:
	var sfx: AudioStreamPlayer = AudioStreamPlayer.new()
	var stream: Resource = load(path)
	if stream is AudioStream:
		sfx.stream = stream
		sfx.connect("finished", sfx.queue_free)
		GsomModapi.scene.add_child(sfx)
		sfx.play()

static func play3d(path: StringName, at: Vector3) -> void:
	var sfx: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	var stream: Resource = load(path)
	if stream is AudioStream:
		sfx.stream = stream
		sfx.connect("finished", sfx.queue_free)
		GsomModapi.scene.add_child(sfx)
		sfx.global_position = at
		sfx.play()
