extends Node

const MISSIONS := [
	"res://scenes/main.tscn", "res://scenes/levels/sandwich_shop.tscn", "res://scenes/levels/after_hours.tscn",
	"res://scenes/levels/harbor_exchange.tscn", "res://scenes/levels/motel_witness.tscn", "res://scenes/levels/penthouse.tscn",
	"res://scenes/levels/cold_storage.tscn", "res://scenes/levels/casino_floor.tscn", "res://scenes/levels/police_archive.tscn",
	"res://scenes/levels/slaughterhouse.tscn", "res://scenes/levels/broadcast_tower.tscn", "res://scenes/levels/last_call.tscn",
]
var failures := 0

func _ready() -> void:
	_expect(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0, "environment art must retain nearest-neighbor hard pixels")
	var screen_shader := FileAccess.get_file_as_string("res://shaders/screen_effect.gdshader")
	_expect("= 0.005" in screen_shader and "= 0.11" in screen_shader and "= 0.00025" in screen_shader, "crime-noir treatment must use subtle scanlines, controlled vignette, and near-zero color splitting")
	var ambient_signatures := {}
	for scene_path: String in MISSIONS:
		var level = (load(scene_path) as PackedScene).instantiate()
		level.record_progress = false
		add_child(level)
		await get_tree().process_frame
		var ambient := (level.get_node("CanvasModulate") as CanvasModulate).color
		var luminance := ambient.r * 0.2126 + ambient.g * 0.7152 + ambient.b * 0.0722
		_expect(luminance >= 0.78, "%s ambient exposure must keep unlit rooms readable" % scene_path)
		ambient_signatures[ambient.to_html(false)] = true
		var environment := (level.get_node("WorldEnvironment") as WorldEnvironment).environment
		_expect(environment.adjustment_contrast <= 1.15 and environment.adjustment_saturation <= 1.25, "post-processing must preserve pixel separation instead of crushing dark colors")
		_expect(level.has_node("TileMap/WallCaps") and level.get_node("TileMap/WallCaps").position.y < 0.0, "%s needs a screen-up wall cap for coherent pseudo-3D height" % scene_path)
		var visible_lights := level.get_node("Lighting").get_children().filter(func(light: Node) -> bool: return light is PointLight2D and light.visible)
		_expect(visible_lights.size() >= 4, "%s needs distributed color lighting rather than isolated visibility pools" % scene_path)
		level.queue_free()
		await get_tree().process_frame
	_expect(ambient_signatures.size() == MISSIONS.size(), "all twelve cases should expose a distinct ambient color script")
	if failures == 0: print("visual readability regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
