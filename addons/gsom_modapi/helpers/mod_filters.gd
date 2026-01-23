extends Object

static func sort_by_attr(
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

static func passes_kind(desc: GsomModContent, q: GsomModQueryFilter) -> bool:
	if q.kinds.is_empty():
		return true
	return desc.kind in q.kinds


static func passes_caps(desc: GsomModContent, q: GsomModQueryFilter) -> bool:
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


static func passes_tags(desc: GsomModContent, q: GsomModQueryFilter) -> bool:
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


static func passes_attrs(desc: GsomModContent, q: GsomModQueryFilter) -> bool:
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
