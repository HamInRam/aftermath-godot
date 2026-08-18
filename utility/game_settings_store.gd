class_name GameSettingsStore
extends Node

signal settings_changed

const SCHEMA_VERSION := 1
const DEFAULT_SAVE_PATH := "user://aftermath_settings.json"
const AUDIO_BUSES := ["Music", "SFX", "Ambience"]

var save_path := DEFAULT_SAVE_PATH
var master_volume := 0.9
var music_volume := 0.75
var sfx_volume := 0.85
var ambience_volume := 0.7
var screen_shake_strength := 1.0
var flash_intensity := 1.0
var screen_effects_enabled := true
var ambient_camera_motion_enabled := true

func _init(custom_save_path := DEFAULT_SAVE_PATH) -> void:
	save_path = custom_save_path

func _ready() -> void:
	load_settings()
	apply_all()

func get_defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"master_volume": 0.9,
		"music_volume": 0.75,
		"sfx_volume": 0.85,
		"ambience_volume": 0.7,
		"screen_shake_strength": 1.0,
		"flash_intensity": 1.0,
		"screen_effects_enabled": true,
		"ambient_camera_motion_enabled": true,
	}

func load_settings() -> bool:
	if not FileAccess.file_exists(save_path): return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null: return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("schema_version", -1)) != SCHEMA_VERSION: return false
	_apply_dictionary(parsed)
	return true

func save_settings() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(to_dictionary(), "\t"))
	file.close()
	return true

func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ambience_volume": ambience_volume,
		"screen_shake_strength": screen_shake_strength,
		"flash_intensity": flash_intensity,
		"screen_effects_enabled": screen_effects_enabled,
		"ambient_camera_motion_enabled": ambient_camera_motion_enabled,
	}

func update_values(values: Dictionary, persist := true) -> void:
	_apply_dictionary(values)
	apply_all()
	if persist: save_settings()
	settings_changed.emit()

func reset_to_defaults(persist := true) -> void:
	_apply_dictionary(get_defaults())
	apply_all()
	if persist: save_settings()
	settings_changed.emit()

func apply_all() -> void:
	_ensure_audio_buses()
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("Ambience", ambience_volume)

func _apply_dictionary(values: Dictionary) -> void:
	master_volume = clampf(float(values.get("master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(values.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(values.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	ambience_volume = clampf(float(values.get("ambience_volume", ambience_volume)), 0.0, 1.0)
	screen_shake_strength = clampf(float(values.get("screen_shake_strength", screen_shake_strength)), 0.0, 1.0)
	flash_intensity = clampf(float(values.get("flash_intensity", flash_intensity)), 0.0, 1.0)
	screen_effects_enabled = bool(values.get("screen_effects_enabled", screen_effects_enabled))
	ambient_camera_motion_enabled = bool(values.get("ambient_camera_motion_enabled", ambient_camera_motion_enabled))

func _ensure_audio_buses() -> void:
	for bus_name in AUDIO_BUSES:
		if AudioServer.get_bus_index(bus_name) >= 0: continue
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _set_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0: return
	AudioServer.set_bus_volume_db(bus_index, -80.0 if linear_value <= 0.001 else linear_to_db(linear_value))

func remove_test_save() -> void:
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func _exit_tree() -> void:
	ProceduralAudioLibrary.clear_cache()
