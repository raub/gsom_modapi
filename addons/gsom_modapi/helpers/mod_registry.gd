extends RefCounted

const ModLoader = preload("../helpers/mod_loader.gd")

var __by_id: Dictionary[StringName, GsomModContent] = {}
var __by_kind: Dictionary[StringName, Array] = {}
var __by_mod: Dictionary[StringName, Array] = {}

func register(desc: GsomModContent) -> void:
	desc.id = ModLoader.gen_id()
	if !desc.id:
		return
	
	__by_id[desc.id] = desc
	
	if !__by_kind.has(desc.kind):
		__by_kind[desc.kind] = [] as Array[GsomModContent]
	__by_kind[desc.kind].append(desc)
	
	var phase: StringName = ModLoader.get_phase()
	if !__by_mod.has(phase):
		__by_mod[phase] = [] as Array[GsomModContent]
	__by_mod[phase].append(desc)

func get_by_id(id: StringName) -> GsomModContent:
	return __by_id.get(id)

func get_by_kind(kind: StringName) -> Array[GsomModContent]:
	return __by_kind.get(kind, [] as Array[GsomModContent])

func get_by_mod(mod: StringName) -> Array[GsomModContent]:
	return __by_mod.get(mod, [] as Array[GsomModContent])

func get_by_query(filter: GsomModQuery) -> Array[GsomModContent]:
	# direct override
	if filter.direct_id != &"":
		var d := get_by_id(filter.direct_id)
		return [d] if d != null else []
	
	var results: Array[GsomModContent] = []

	for desc in __by_id.values():         # master list of GsomModContent
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
	
	return results

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
