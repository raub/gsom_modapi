extends RefCounted

const ModLoader = preload("../helpers/mod_loader.gd")

var __by_id: Dictionary[StringName, GsomModContent] = {}
var __by_kind: Dictionary[StringName, Array] = {}
var __by_mod: Dictionary[StringName, Array] = {}
var __by_key: Dictionary[StringName, Array] = {}

# Empty content list - generate typed empty array
func __emcolist() -> Array[GsomModContent]: return [] as Array[GsomModContent]

func register(desc: GsomModContent) -> GsomModContent:
	# All work is done on a duplicate - input is read-only
	desc = desc.duplicate_deep()
	
	desc.id = ModLoader.gen_id()
	if !desc.id:
		return null
	
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

func __filter_keyed_content(list: Array[GsomModContent]) -> Array[GsomModContent]:
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

func get_by_id(id: StringName) -> GsomModContent:
	var item: GsomModContent = __by_id.get(id)
	if !item.key:
		return item
	return get_by_key(item.key)

func get_by_kind(kind: StringName) -> Array[GsomModContent]:
	var raw: Array[GsomModContent] = __by_kind.get(kind, __emcolist())
	return __filter_keyed_content(raw)

func get_by_key(key: StringName) -> GsomModContent:
	var items: Array[GsomModContent] = __by_key.get(key, __emcolist())
	return items[0] if items.size() else null

func get_by_key_all(key: StringName) -> Array[GsomModContent]:
	return __by_key.get(key, __emcolist())

func get_by_mod(mod: StringName) -> Array[GsomModContent]:
	var raw: Array[GsomModContent] = __by_mod.get(mod, __emcolist())
	return __filter_keyed_content(raw)

func get_by_query(query: GsomModQueryBase) -> Array[GsomModContent]:
	if query is GsomModQueryFilter:
		return __filter_by_query(query as GsomModQueryFilter)
	
	if query is GsomModQueryPick:
		return __pick_by_query(query as GsomModQueryPick)
	
	return []

func __filter_by_query(filter: GsomModQueryFilter) -> Array[GsomModContent]:
	var results: Array[GsomModContent] = []

	for desc: GsomModContent in __by_id.values():
		if not __passes_kind(desc, filter):
			continue
		if not __passes_caps(desc, filter):
			continue
		if not __passes_tags(desc, filter):
			continue
		if not __passes_attrs(desc, filter):
			continue
		results.append(desc)
	
	if results.size() > 1 && filter.sort_attr:
		results.sort_custom(__sort_by_attr.bind(filter.sort_attr))
	
	return __filter_keyed_content(results)

func __pick_by_query(query: GsomModQueryPick) -> Array[GsomModContent]:
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
		results.sort_custom(__sort_by_attr.bind(query.sort_attr))
	
	return results

static func __sort_by_attr(
	attr_name: StringName,
	a: GsomModContent,
	b: GsomModContent,
) -> bool:
	# "a" can only win if it has the attr
	if a.attrs.has(attr_name):
		# "a" always wins when "b" has no such attr
		if !b.attrs.has(attr_name):
			return true
		return a.attrs.get(attr_name) > b.attrs.get(attr_name)
	
	return false

static func __passes_kind(desc: GsomModContent, q: GsomModQueryFilter) -> bool:
	if q.kinds.is_empty():
		return true
	return desc.kind in q.kinds


static func __passes_caps(desc: GsomModContent, q: GsomModQueryFilter) -> bool:
	for cap: StringName in q.caps_all:
		if cap not in desc.caps:
			return false
	
	for cap: StringName in q.caps_exclude:
		if cap in desc.caps:
			return false
	
	var has_any: bool = true
	for t: StringName in q.caps_any:
		if t in desc.caps:
			has_any = true
			break
	
	return has_any


static func __passes_tags(desc: GsomModContent, q: GsomModQueryFilter) -> bool:
	for t: StringName in q.tags_all:
		if t not in desc.tags:
			return false
	
	for t: StringName in q.tags_exclude:
		if t in desc.tags:
			return false
	
	var has_any: bool = true
	for t: StringName in q.tags_any:
		if t in desc.tags:
			has_any = true
			break
	
	return has_any


static func __passes_attrs(desc: GsomModContent, q: GsomModQueryFilter) -> bool:
	# equals
	for k: StringName in q.attr_equals.keys():
		if desc.attrs.get(k) != q.attr_equals[k]:
			return false
	
	# min
	for k: StringName in q.attr_min.keys():
		var v: Variant = desc.attrs.get(k, null)
		if v == null or v < q.attr_min[k]:
			return false
	
	# max
	for k: StringName in q.attr_max.keys():
		var v: Variant = desc.attrs.get(k, null)
		if v == null or v > q.attr_max[k]:
			return false
	
	return true
