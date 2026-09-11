class_name AtomicJsonStore
extends RefCounted
## A completed save replaces the primary atomically; the last valid primary is
## copied to a separately staged backup before replacement. Never delete the
## primary to make a failed rename succeed.

static func read_dictionary(path: String, versions: Array) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		var value := _read_valid(candidate, versions)
		if not value.is_empty(): return value
	return {}

static func _read_valid(path: String, versions: Array) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK: return {}
	var value: Variant = parser.data
	if not value is Dictionary: return {}
	var version: Variant = value.get("schema_version")
	if not (version is int or version is float) or not is_finite(float(version)) or float(version) != floorf(float(version)) or int(version) not in versions: return {}
	return value

static func write_dictionary(path: String, value: Dictionary, versions: Array) -> bool:
	path = ProjectSettings.globalize_path(path)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or _read_valid(temporary, versions).is_empty():
		DirAccess.remove_absolute(temporary)
		return false
	# Do not overwrite a recoverable backup with a truncated/incompatible primary.
	if not _read_valid(path, versions).is_empty():
		var backup_temporary := path + ".bak.tmp"
		if DirAccess.copy_absolute(path, backup_temporary) != OK:
			DirAccess.remove_absolute(temporary)
			return false
		if DirAccess.rename_absolute(backup_temporary, path + ".bak") != OK:
			DirAccess.remove_absolute(backup_temporary)
			DirAccess.remove_absolute(temporary)
			return false
	if DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	return true

static func remove_files(path: String) -> void:
	path = ProjectSettings.globalize_path(path)
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
