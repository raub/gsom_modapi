extends Resource
class_name GsomModSelector

@export var table: Dictionary[GsomModQueryBase, float] = {}

## Reference other selectors
##
## This is mostly a convenience to combine existing lists of queries.
## Such as for loading all the related stuff that you are going to use later.
##
## These will be traversed and all tables will merge.
@export var selectors: Array[GsomModSelector] = []

var __raw_cache: Dictionary[GsomModQueryBase, float] = {}
var __norm_cache: Dictionary[GsomModQueryBase, float] = {}

## Combines `table` and all nested `selectors`. Returns a normalized Query table.
##
## Normalized: the sum of all weights becomes `1.0`, preserving the ratio.
## E.g. [0.5, 20, 100] becomes [0.004, 0.166, 0.83].
## 
func get_normalized() -> Dictionary[GsomModQueryBase, float]:
	if __norm_cache.size():
		return __norm_cache.duplicate()
	
	var result: Dictionary[GsomModQueryBase, float] = get_raw()
	if !result.size():
		return {}
	
	var weight_sum: float = 0.0
	
	for weight: float in result.values():
		if weight > 0.0:
			weight_sum += weight

	if weight_sum > 0.0:
		for query: GsomModQueryBase in result:
			var weight: float = result[query]
			result[query] = weight / weight_sum
	else:
		var step: float = 1.0 / result.size()
		for query: GsomModQueryBase in result:
			result[query] = step
	
	__norm_cache = result
	return __norm_cache.duplicate()

## Combines `table` and all nested `selectors`. Returns a single Query table.
##
## * Cyclic reference is ok - won't follow.
## * Duplicate queries are returned as one (sum of weights).
func get_raw() -> Dictionary[GsomModQueryBase, float]:
	if __raw_cache.size():
		return __raw_cache.duplicate()
	
	var result: Dictionary[GsomModQueryBase, float] = {}
	__get_raw_impl(result, {})
	
	__raw_cache = result
	return __raw_cache.duplicate()

func __store_query_additive(
	inout_result: Dictionary[GsomModQueryBase, float],
	query: GsomModQueryBase,
	weight: float,
) -> void:
	if inout_result.has(query):
		inout_result[query] += max(0.0, weight)
	else:
		inout_result[query] = max(0.0, weight)

func __get_raw_impl(
	inout_result: Dictionary[GsomModQueryBase, float],
	inout_visited: Dictionary[GsomModSelector, bool],
) -> void:
	if inout_visited[self]:
		return
	
	inout_visited[self] = true
	
	for query: GsomModQueryBase in table:
		__store_query_additive(inout_result, query, table[query])
	
	for selector: GsomModSelector in selectors:
		selector.__get_raw_impl(inout_result, inout_visited)
