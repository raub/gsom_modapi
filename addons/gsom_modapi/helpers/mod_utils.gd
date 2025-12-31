extends Object

## Returns a new array with duplicate elements removed, preserving order.
static func array_uniq(input: Array) -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	
	for item in input:
		if not seen.has(item):
			seen[item] = true
			result.append(item)
	
	return result

## Returns a new Array[StringName] containing only unique elements, preserving order.
static func array_uniq_string_name(input: Array[StringName]) -> Array[StringName]:
	var seen: Dictionary[StringName, bool] = {}
	var result: Array[StringName] = []
	
	for s: StringName in input:
		if not seen.has(s):
			seen[s] = true
			result.append(s)
	
	return result
