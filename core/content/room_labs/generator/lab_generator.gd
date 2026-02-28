@tool
extends Node3D
class_name RoomLabsGenerator

@export_tool_button("Generate") var generate_action: Callable = generate

@export var room_seed: int = 1337
@export var randomize_seed_on_ready: bool = false
@export_range(8, 64, 1) var room_count: int = 22
@export_range(2, 12, 1) var grid_radius: int = 5
@export_range(22.0, 40.0, 0.5) var grid_step: float = 30.0

@export_range(12.0, 22.0, 0.5) var room_width_min: float = 13.0
@export_range(12.0, 24.0, 0.5) var room_width_max: float = 18.0
@export_range(10.0, 22.0, 0.5) var room_depth_min: float = 12.0
@export_range(10.0, 24.0, 0.5) var room_depth_max: float = 18.0
@export_range(18.0, 34.0, 0.5) var combat_width_min: float = 20.0
@export_range(18.0, 36.0, 0.5) var combat_width_max: float = 28.0
@export_range(18.0, 34.0, 0.5) var combat_depth_min: float = 20.0
@export_range(18.0, 36.0, 0.5) var combat_depth_max: float = 28.0
@export_range(0.1, 0.8, 0.05) var combat_room_ratio: float = 0.35

@export_range(4.0, 8.0, 0.25) var room_height: float = 5.2
@export_range(0.0, 12.0, 0.25) var room_height_variation: float = 10.0
@export_range(0.0, 8.0, 0.1) var adjacent_room_height_min_delta: float = 1.4
@export_range(0.0, 12.0, 0.25) var room_floor_variation: float = 3.0
@export_range(0.0, 8.0, 0.1) var adjacent_room_floor_min_delta: float = 1.2
@export_range(4.0, 12.0, 0.25) var corridor_width: float = 6.0
@export_range(0.0, 6.0, 0.25) var corridor_target_length: float = 2.0
@export_range(0.0, 2.0, 0.05) var room_cell_margin: float = 0.5
@export_range(2.2, 4.5, 0.1) var doorway_height: float = 3.2
@export_range(0.2, 1.0, 0.05) var wall_thickness: float = 0.5
@export_range(0.2, 1.2, 0.05) var floor_thickness: float = 0.45
@export_range(0.5, 2.0, 0.1) var door_floor_snap_threshold: float = 1.0
@export_range(1.0, 4.0, 0.1) var door_split_min_delta: float = 2.0
@export_range(1.5, 5.0, 0.1) var door_bridge_min_height: float = 3.0
@export_range(0.05, 0.95, 0.05) var elevated_door_chance: float = 0.65

const GENERATED_ROOT_NAME: StringName = &"GeneratedLabs"
const GENERATED_ROOT_PATH: NodePath = ^"GeneratedLabs"
const RoomEdge = RoomLabsGeneratorRooms.RoomEdge
const RoomData = RoomLabsGeneratorRooms.RoomData

var __rng: RandomNumberGenerator = RandomNumberGenerator.new()
var __rooms_by_key: Dictionary[String, RoomData] = {}
var __neighbors_by_key: Dictionary[String, Array] = {}
var __edges: Array[RoomEdge] = []
var __door_bottom_by_side: Dictionary[String, float] = {}

func _ready() -> void:
	if randomize_seed_on_ready:
		room_seed = randi()
	generate()

func generate() -> void:
	__clear_previous_generation()
	__rng.seed = room_seed
	__rooms_by_key.clear()
	__neighbors_by_key.clear()
	__edges.clear()
	__door_bottom_by_side.clear()
	RoomLabsGeneratorMaterials.prepare()
	var layout_graph: RoomLabsGeneratorGraph.LayoutGraph = RoomLabsGeneratorGraph.build_layout_graph(
		__rng,
		room_count,
		grid_radius,
		grid_step,
		combat_room_ratio,
		room_width_min,
		room_width_max,
		room_depth_min,
		room_depth_max,
		combat_width_min,
		combat_width_max,
		combat_depth_min,
		combat_depth_max,
		corridor_width,
		room_height,
		room_height_variation,
		adjacent_room_height_min_delta,
		room_floor_variation,
		adjacent_room_floor_min_delta,
		doorway_height,
		door_floor_snap_threshold,
		corridor_target_length,
		room_cell_margin
	)
	__rooms_by_key = layout_graph.rooms_by_key
	__neighbors_by_key = layout_graph.neighbors_by_key
	__edges = layout_graph.edges
	__door_bottom_by_side = RoomLabsGeneratorDoors.plan_door_openings(
		__rooms_by_key,
		__neighbors_by_key,
		__rng,
		doorway_height,
		door_floor_snap_threshold,
		door_split_min_delta,
		elevated_door_chance
	)
	__spawn_generated_geometry()
	print(
		"[RoomLabs] Generated labs room_seed=%d rooms=%d edges=%d"
		% [room_seed, __rooms_by_key.size(), __edges.size()]
	)

func __clear_previous_generation() -> void:
	var generated: Node = get_node_or_null(GENERATED_ROOT_PATH)
	if generated:
		generated.free()

func __spawn_generated_geometry() -> void:
	var root: Node3D = Node3D.new()
	root.name = GENERATED_ROOT_NAME
	add_child(root)

	var geom_root: Node3D = Node3D.new()
	geom_root.name = &"Geometry"
	root.add_child(geom_root)

	var light_root: Node3D = Node3D.new()
	light_root.name = &"Lights"
	root.add_child(light_root)

	var door_bottom_for_side: Callable = (
		func(coord: Vector2i, dir: Vector2i, room_height_local: float) -> float:
			return RoomLabsGeneratorDoors.door_bottom_for_side(
				coord,
				dir,
				room_height_local,
				__door_bottom_by_side,
				doorway_height,
				door_floor_snap_threshold
			)
	)

	var room_keys: Array = __rooms_by_key.keys()
	for room_key: String in room_keys:
		var room: RoomData = __rooms_by_key[room_key]
		var has_neighbors: bool = __neighbors_by_key.has(room_key)
		RoomLabsGeneratorRooms.build_room(
			geom_root,
			light_root,
			room,
			__neighbors_by_key[room_key] if has_neighbors else [],
			__rng,
			corridor_width,
			doorway_height,
			wall_thickness,
			floor_thickness,
			room_height,
			door_floor_snap_threshold,
			door_bridge_min_height,
			door_bottom_for_side
		)

	for edge: RoomEdge in __edges:
		RoomLabsGeneratorCorridor.build_corridor(
			geom_root,
			__rooms_by_key,
			__neighbors_by_key,
			edge.a,
			edge.b,
			corridor_width,
			wall_thickness,
			floor_thickness,
			room_height,
			door_bottom_for_side
		)

	RoomLabsGeneratorLighting.add_base_environment_lighting(root, light_root)
