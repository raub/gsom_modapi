extends RefCounted

const ModRegistry = preload("./mod_registry.gd")

static func traverse_selector(
	selector: GsomModSelector,
	visited: Dictionary[StringName, bool] = {},
) -> Array[StringName]:
	var result: Array[StringName] = []
	for query: GsomModQueryBase in selector.table.keys():
		result.append_array(traverse_query(query, visited))
	return result

static func traverse_query(
	query: GsomModQueryBase,
	visited: Dictionary[StringName, bool] = {},
) -> Array[StringName]:
	var result: Array[StringName] = []
	for content: GsomModContent in ModRegistry.get_by_query(query):
		if visited.has(content.id):
			continue
		visited[content.id] = true
		result.append_array(traverse_content(content, visited))
	return result

static func traverse_content(
	content: GsomModContent,
	visited: Dictionary[StringName, bool] = {},
) -> Array[StringName]:
	var result: Array[StringName] = []
	
	if content.path_icon:
		result.append(content.path_icon)

	if content.path_thumbnail:
		result.append(content.path_thumbnail)

	if content.path_preview:
		result.append(content.path_preview)

	if content.path_scene:
		result.append(content.path_scene)

	if content.path_replicator:
		result.append(content.path_replicator)

	if content.dep_query:
		result.append_array(traverse_query(content.dep_query, visited))

	if content.dep_queries:
		for query: GsomModQueryBase in content.dep_queries:
			result.append_array(traverse_query(query, visited))

	if content.dep_selector:
		result.append_array(traverse_selector(content.dep_selector, visited))
	
	return result
