extends RefCounted
class_name RoomLabsGeneratorBoxes

static func add_solid_box(
	parent: Node3D,
	base_name: String,
	size: Vector3,
	pos: Vector3,
	material: Material,
	with_collision: bool = true
) -> void:
	var clamped_size: Vector3 = Vector3(
		maxf(size.x, 0.05),
		maxf(size.y, 0.05),
		maxf(size.z, 0.05)
	)

	var node: Node3D = Node3D.new()
	node.name = base_name
	node.position = pos
	parent.add_child(node)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = clamped_size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	node.add_child(mesh_instance)

	if !with_collision:
		return

	var body: StaticBody3D = StaticBody3D.new()
	node.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = clamped_size
	collision.shape = shape
	body.add_child(collision)

static func add_oriented_box(
	parent: Node3D,
	base_name: String,
	size: Vector3,
	pos: Vector3,
	box_basis: Basis,
	material: Material,
	with_collision: bool = true
) -> void:
	var clamped_size: Vector3 = Vector3(
		maxf(size.x, 0.05),
		maxf(size.y, 0.05),
		maxf(size.z, 0.05)
	)

	var node: Node3D = Node3D.new()
	node.name = base_name
	node.position = pos
	node.basis = box_basis
	parent.add_child(node)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = clamped_size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	node.add_child(mesh_instance)

	if !with_collision:
		return

	var body: StaticBody3D = StaticBody3D.new()
	node.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = clamped_size
	collision.shape = shape
	body.add_child(collision)
