extends RefCounted
## Save/load system — persists world tiles and inventory to a JSON file.
##
## KEY GODOT CONCEPTS:
## - FileAccess: Godot's file I/O class. open() returns a FileAccess instance
##   or null if the file can't be opened. Always check for null.
## - "user://": A special path that points to the user's app data directory.
##   On Windows: %APPDATA%/Godot/app_userdata/ProjectName/
##   On Linux: ~/.local/share/godot/app_userdata/ProjectName/
##   This is the standard place to store save files.
## - JSON.stringify / JSON.parse_string: Built-in JSON serialization.
##   We convert world_data (2D array of ints) and inventory (Dictionary)
##   to a JSON string for human-readable save files.

const SAVE_PATH := "user://save.json"


static func save_game(world_data: Array, inventory: Dictionary) -> bool:
	## Save current world state and inventory to disk.
	var data := {
		"world": world_data,
		"inventory": inventory,
	}
	var json_string := JSON.stringify(data)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: Could not open file for writing: %s" % SAVE_PATH)
		return false
	file.store_string(json_string)
	file.close()
	return true


static func load_game() -> Dictionary:
	## Load saved state from disk. Returns empty Dictionary if no save exists.
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json_string := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_string)
	if parsed is Dictionary:
		return parsed
	return {}


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
