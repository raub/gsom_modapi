extends RefCounted
class_name RoomLabsGeneratorRooms

class RoomEdge:
	var a: Vector2i = Vector2i.ZERO
	var b: Vector2i = Vector2i.ZERO

class RoomData:
	var coord: Vector2i = Vector2i.ZERO
	var center: Vector3 = Vector3.ZERO
	var width: float = 0.0
	var depth: float = 0.0
	var height: float = 0.0
	var combat: bool = false
