extends RefCounted

class ModSettings:
	var disabled_mods: Array[StringName] = []

static var __mod_settings: ModSettings = null
static var __phase: StringName = &""
static var __id: int = 0

static var loaded_mods: Dictionary[StringName, GsomModMeta] = {}

static func load_mods() -> void:
	__read_settings()
	
	var user_mod_names: PackedStringArray = __fetch_user_mod_names()
	var builtin_mod_names: PackedStringArray = __fetch_builtin_mod_names()
	
	var loaded_mod_names: PackedStringArray = []
	for name: String in user_mod_names:
		if __mod_settings.disabled_mods.has(name):
			continue
		if ProjectSettings.load_resource_pack("user://mods/%s.pck", false):
			loaded_mod_names.append(name)
	
	for name: String in builtin_mod_names:
		if !loaded_mod_names.has(name):
			loaded_mod_names.append(name)
	
	for name: String in loaded_mod_names:
		var script: GDScript = load("res://mods/%s/mod.gd" % name)
		var inst: Object = script.new()
		if !(inst is GsomModMeta):
			push_error("The mod script should extend 'GsomModMeta'.")
			continue
		loaded_mods[name] = inst as GsomModMeta
	
	for name: StringName in loaded_mods:
		start_phase(name)
		loaded_mods[name]._mod_init()
		end_phase()

# Reads "user://mods/*" for external mods.
# @returns An array of directory names found under "mods".
static func __fetch_user_mod_names() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var base: String = "user://mods"

	if not DirAccess.dir_exists_absolute(base):
		return result

	var dir: DirAccess = DirAccess.open(base)
	if dir == null:
		return result

	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break

		# Skip files and special entries
		if name == "." or name == "..":
			continue
		if dir.current_is_dir():
			result.append(name)

	dir.list_dir_end()
	return result


# Reads "res://mods/*" for builtin mods.
# @returns An array of directory names found under "mods".
static func __fetch_builtin_mod_names() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var base: String = "res://mods"

	# res:// may not contain a mods folder
	if not DirAccess.dir_exists_absolute(base):
		return result

	var dir: DirAccess = DirAccess.open(base)
	if dir == null:
		return result

	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break

		# Skip files and special entries
		if name == "." or name == "..":
			continue
		if dir.current_is_dir():
			result.append(name)

	dir.list_dir_end()
	return result

# Reads "user://mod_settings.json" if it exists
#
# Only the fields present in `__mod_settings_default` are taken.
# Only if they match the data type - array to array, object to object, number to number, etc.
#
# The missing fields are taken from `__mod_settings_default` as is.
static func __read_settings() -> void:
	__mod_settings = ModSettings.new()

# Writes "user://mod_settings.json"
# The `__mod_settings` var contents is dumped into the file
static func __write_settings() -> void:
	pass

# Per-mod loading phase
static func start_phase(name: StringName) -> void:
	__phase = name
	__id = 0

# Create a pre-mod ID
static func gen_id() -> StringName:
	if !__phase:
		push_error("Can't generate ID outside init phases.")
		return &""
	__id += 1
	return &"%s:%s" % [__phase, __id]

# Finish the load phase
static func end_phase() -> void:
	__phase = &""
	__id = 0

# Mod name currently being loaded
static func get_phase() -> StringName:
	return __phase
