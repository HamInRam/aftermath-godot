extends Node

var failures := 0

func _ready() -> void:
	_expect(ProjectSettings.get_setting("application/config/name") == "AFTERMATH", "release build should use the final product name")
	_expect(ProjectSettings.get_setting("application/config/version") == "1.2.6", "project version should match the release branch")
	_expect(FileAccess.file_exists("res://assets/branding/aftermath_icon.svg"), "release icon should be present")
	_expect(FileAccess.file_exists("res://assets/fonts/Silkscreen-Regular.ttf") and FileAccess.file_exists("res://assets/fonts/OFL-Silkscreen.txt"), "bundled UI font and its complete OFL license should ship")
	_expect(FileAccess.file_exists("res://LICENSE.md") and FileAccess.file_exists("res://THIRD_PARTY_NOTICES.md") and FileAccess.file_exists("res://GODOT_LICENSE.txt"), "project, third-party and engine license notices should ship")
	_expect("Silkscreen" in FileAccess.get_file_as_string("res://THIRD_PARTY_NOTICES.md"), "third-party notice should identify the bundled pixel font")
	_expect(FileAccess.file_exists("res://RELEASE_CHECKLIST.md") and FileAccess.file_exists("res://export_presets.cfg"), "release checklist and export presets should be versioned")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_expect("name=\"Windows Desktop\"" in presets and "name=\"Linux\"" in presets, "Windows and Linux release presets should both exist")
	_expect("application/product_version=\"1.2.6.0\"" in presets and "include_filter=\"*.md,*.txt\"" in presets, "exports should carry the current version and include distributable license documents")
	for profile in MissionCatalog.get_all_missions():
		_expect(not profile.scene_path.is_empty() and ResourceLoader.exists(profile.scene_path), "every catalog mission should reference an exportable scene")
	if failures == 0: print("release metadata regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
