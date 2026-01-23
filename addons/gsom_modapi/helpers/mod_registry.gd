extends RefCounted

const ModLoader = preload("../helpers/mod_loader.gd")
const ModFilters = preload("../helpers/mod_filters.gd")

static var __by_id: Dictionary[StringName, GsomModContent] = {}
static var __by_kind: Dictionary[StringName, Array] = {}
static var __by_mod: Dictionary[StringName, Array] = {}
static var __by_key: Dictionary[StringName, Array] = {}

# Empty content list - generate typed empty array
static func __emcolist() -> Array[GsomModContent]: return [] as Array[GsomModContent]

static func register(desc: GsomModContent) -> GsomModContent:
	# All work is done on a duplicate - input is read-only
	desc = desc.duplicate_deep()
	
	desc.id = ModLoader.gen_id()
	if !desc.id:
		return null
	
	desc.mod = ModLoader.get_phase()
	
	__by_id[desc.id] = desc
	
	if !__by_kind.has(desc.kind):
		__by_kind[desc.kind] = __emcolist()
	__by_kind[desc.kind].append(desc)
	
	# Ordered unique key storage
	if desc.key:
		var items: Array[GsomModContent] = __emcolist()
		if __by_key.has(desc.key):
			items = __by_key[desc.key]
		var orderIndex: int = 0;
		for i: int in items.size():
			if desc.key_weight >= items[i].key_weight:
				break
		items.insert(orderIndex, desc)
		__by_key[desc.key].append(desc)
	
	var phase: StringName = ModLoader.get_phase()
	if !__by_mod.has(phase):
		__by_mod[phase] = __emcolist()
	__by_mod[phase].append(desc)
	return desc

static func __filter_keyed_content(list: Array[GsomModContent]) -> Array[GsomModContent]:
	if !list.size():
		return list
	var result: Array[GsomModContent] = __emcolist()
	for item: GsomModContent in list:
		if !item.key:
			result.append(item)
			continue
		var keyed: GsomModContent = get_by_key(item.key)
		if keyed == item:
			result.append(item)
	return result

static func get_by_id(id: StringName) -> GsomModContent:
	var item: GsomModContent = __by_id.get(id)
	if !item.key:
		return item
	return get_by_key(item.key)

static func get_by_kind(kind: StringName) -> Array[GsomModContent]:
	var raw: Array[GsomModContent] = __by_kind.get(kind, __emcolist())
	return __filter_keyed_content(raw)

static func get_by_key(key: StringName) -> GsomModContent:
	var items: Array[GsomModContent] = __by_key.get(key, __emcolist())
	return items[0] if items.size() else null

static func get_by_key_all(key: StringName) -> Array[GsomModContent]:
	return __by_key.get(key, __emcolist())

static func get_by_mod(mod: StringName) -> Array[GsomModContent]:
	var raw: Array[GsomModContent] = __by_mod.get(mod, __emcolist())
	return __filter_keyed_content(raw)

static func get_by_query(query: GsomModQueryBase) -> Array[GsomModContent]:
	if query is GsomModQueryFilter:
		return __filter_by_query(query as GsomModQueryFilter)
	
	if query is GsomModQueryPick:
		return __pick_by_query(query as GsomModQueryPick)
	
	push_warning("Unsupported query type.")
	return []

static func __filter_by_query(filter: GsomModQueryFilter) -> Array[GsomModContent]:
	var results: Array[GsomModContent] = []

	for desc: GsomModContent in __by_id.values():
		if not ModFilters.passes_kind(desc, filter):
			continue
		if not ModFilters.passes_caps(desc, filter):
			continue
		if not ModFilters.passes_tags(desc, filter):
			continue
		if not ModFilters.passes_attrs(desc, filter):
			continue
		results.append(desc)
	
	if results.size() > 1 && filter.sort_attr:
		results.sort_custom(ModFilters.sort_by_attr.bind(filter.sort_attr))
	
	return __filter_keyed_content(results)

static func __pick_by_query(query: GsomModQueryPick) -> Array[GsomModContent]:
	var results: Array[GsomModContent] = []
	
	for id: StringName in query.pick_ids:
		var content: GsomModContent = get_by_id(id)
		if content:
			results.append(content)
	
	for key: StringName in query.pick_keys:
		var content: GsomModContent = get_by_key(key)
		if content and !results.has(content):
			results.append(content)
	
	if results.size() > 1 && query.sort_attr:
		results.sort_custom(ModFilters.sort_by_attr.bind(query.sort_attr))
	
	return results
