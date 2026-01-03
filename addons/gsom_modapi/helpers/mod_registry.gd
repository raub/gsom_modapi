extends RefCounted

const ModLoader = preload("../helpers/mod_loader.gd")

var __by_id: Dictionary[StringName, GsomModContent] = {}
var __by_kind: Dictionary[StringName, Array] = {}
var __by_mod: Dictionary[StringName, Array] = {}
var __by_key: Dictionary[StringName, Array] = {}

func register(desc: GsomModContent) -> GsomModContent:
	# All work is done on a duplicate - input is read-only
	desc = desc.duplicate_deep()
	
	desc.id = ModLoader.gen_id()
	if !desc.id:
		return null
	
	__by_id[desc.id] = desc
	
	if !__by_kind.has(desc.kind):
		__by_kind[desc.kind] = [] as Array[GsomModContent]
	__by_kind[desc.kind].append(desc)
	
	# Ordered unique key storage
	if desc.key:
		var items: Array[GsomModContent] = [] as Array[GsomModContent]
		if __by_key.has(desc.key):
			items = __by_key[desc.key]
		var orderIndex = 0;
		for i in items.size():
			if desc.key_weight >= items[i].key_weight:
				break
		items.insert(orderIndex, desc)
		__by_key[desc.key].append(desc)
	
	var phase: StringName = ModLoader.get_phase()
	if !__by_mod.has(phase):
		__by_mod[phase] = [] as Array[GsomModContent]
	__by_mod[phase].append(desc)
	return desc

func __filter_keyed_content(list: Array[GsomModContent]) -> Array[GsomModContent]:
	if !list.size():
		return list
	var result: Array[GsomModContent] = [] as Array[GsomModContent]
	for item: GsomModContent in list:
		if !item.key:
			result.append(item)
		var keyed = get_by_key(item.key)
		if keyed == item:
			result.append(item)
	return result

func get_by_id(id: StringName) -> GsomModContent:
	var item = __by_id.get(id)
	if !item.key:
		return item
	return get_by_key(item.key)

func get_by_kind(kind: StringName) -> Array[GsomModContent]:
	return __filter_keyed_content(__by_kind.get(kind, [] as Array[GsomModContent]))

func get_by_key(key: StringName) -> GsomModContent:
	var items: Array[GsomModContent] = __by_key.get(key, [] as Array[GsomModContent])
	return items[0]

func get_by_key_all(key: StringName) -> Array[GsomModContent]:
	return __by_key.get(key, [] as Array[GsomModContent])

func get_by_mod(mod: StringName) -> Array[GsomModContent]:
	return __filter_keyed_content(__by_mod.get(mod, [] as Array[GsomModContent]))

func get_by_query(filter: GsomModQuery) -> Array[GsomModContent]:
	# Direct override
	if filter.direct_id != &"":
		var d: GsomModContent = get_by_id(filter.direct_id)
		return ([d] if d != null else []) as Array[GsomModContent]
	
	var results: Array[GsomModContent] = []

	for desc in __by_id.values():
		if not __passes_kind(desc, filter):
			continue
		if not __passes_capabilities(desc, filter):
			continue
		if not __passes_tags(desc, filter):
			continue
		if not __passes_attributes(desc, filter):
			continue
		results.append(desc)
	
	if results.size() > 1 && filter.sort_attr:
		results.sort_custom(__sort_by_attr.bind(filter.sort_attr))
	
	return __filter_keyed_content(results)

static func __sort_by_attr(attr_name: StringName, a: GsomModContent, b: GsomModContent) -> bool:
	# "a" can only win if it has the attr
	if a.attrs.has(attr_name):
		# "a" always wins when "b" has no such attr
		if !b.attrs.has(attr_name):
			return true
		return a.attrs.get(attr_name) > b.attrs.get(attr_name)
	
	return false

static func __passes_kind(desc: GsomModContent, q: GsomModQuery) -> bool:
	if q.kinds.is_empty():
		return true
	return desc.kind in q.kinds


static func __passes_capabilities(desc: GsomModContent, q: GsomModQuery) -> bool:
	for cap in q.required_capabilities:
		if cap not in desc.capabilities:
			return false
	
	for cap in q.forbidden_capabilities:
		if cap in desc.capabilities:
			return false
	
	return true


static func __passes_tags(desc: GsomModContent, q: GsomModQuery) -> bool:
	for t in q.tags_include:
		if t not in desc.tags:
			return false
	
	for t in q.tags_exclude:
		if t in desc.tags:
			return false
	
	return true


static func __passes_attributes(desc: GsomModContent, q: GsomModQuery) -> bool:
	# equals
	for k in q.attr_equals.keys():
		if desc.attributes.get(k) != q.attr_equals[k]:
			return false
	
	# min
	for k in q.attr_min.keys():
		var v = desc.attributes.get(k, null)
		if v == null or v < q.attr_min[k]:
			return false
	
	# max
	for k in q.attr_max.keys():
		var v = desc.attributes.get(k, null)
		if v == null or v > q.attr_max[k]:
			return false
	
	return true
