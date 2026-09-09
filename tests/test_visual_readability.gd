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
	_expect(str(ProjectSettings.get_setting("autoload/NoirPresenter", "")).ends_with("utility/noir_presenter.gd"), "every scene needs the global noir palette gate")
	var screen_shader := FileAccess.get_file_as_string("res://shaders/screen_effect.gdshader")
	_expect("= 0.002" in screen_shader and "= 0.10" in screen_shader and "noir_contrast" in screen_shader, "noir treatment needs near-invisible scanlines, a restrained vignette and readable high-contrast grayscale")
	_expect("crimson_signal" in screen_shader and "Registration echo is luminance-only" in screen_shader, "post-processing must reserve crimson semantically and never create RGB fringe colours")
	_expect("azure_signal" not in screen_shader and "violet_signal" not in screen_shader and "amber_signal" not in screen_shader, "the active roguelike presentation must remove legacy blue, violet and gold exceptions")
	_expect("fine_detail_protection" in screen_shader and "Value-assisted luminance" in screen_shader, "bright pixel fonts and icons must remain crisp above world-space CRT treatment")
	_expect("native_pixel_protection" in screen_shader and "grayscale_steps : hint_range(16.0, 255.0) = 255.0" in screen_shader, "native edges stay sharp without 32-level lighting contours")
	var light_image := PixelLightTextureFactory.create_texture().get_image()
	var previous := 1.0
	for x in range(64, 128):
		var alpha := light_image.get_pixel(x, 64).a
		_expect(alpha <= previous and previous - alpha < 0.03, "light falloff is monotonic without hard ring boundaries")
		previous = alpha
	_expect("SCREEN_PIXEL_SIZE" in screen_shader and "vec2(320.0, 180.0)" not in screen_shader, "post-processing must sample the active render target instead of downsampling enlarged UI through a fixed grid")
	var ambient_signatures := {}
	for scene_path: String in MISSIONS:
		var level = (load(scene_path) as PackedScene).instantiate()
		level.record_progress = false
		add_child(level)
		await get_tree().process_frame
		var ambient := (level.get_node("CanvasModulate") as CanvasModulate).color
		var luminance := ambient.r * 0.2126 + ambient.g * 0.7152 + ambient.b * 0.0722
		_expect(luminance >= 0.90, "%s ambient exposure must preserve large readable light fields beneath the noir grade" % scene_path)
		_expect(absf(ambient.r - ambient.g) < 0.002 and absf(ambient.g - ambient.b) < 0.002, "%s ambient light must be strict grayscale" % scene_path)
		ambient_signatures[ambient.to_html(false)] = true
		var environment := (level.get_node("WorldEnvironment") as WorldEnvironment).environment
		_expect(not environment.glow_enabled and environment.adjustment_contrast <= 1.15 and environment.adjustment_saturation <= 1.25, "post-processing must preserve pixel separation without soft glow or crushed dark colors")
		_expect(level.has_node("TileMap/WallCaps") and level.get_node("TileMap/WallCaps").position.y < 0.0, "%s needs a screen-up wall cap for coherent pseudo-3D height" % scene_path)
		var visible_lights := level.get_node("Lighting").get_children().filter(func(light: Node) -> bool: return light is PointLight2D and light.visible)
		_expect(visible_lights.size() >= 4, "%s needs distributed practical lighting rather than isolated visibility pools" % scene_path)
		for light: PointLight2D in visible_lights:
			_expect(light.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and light.shadow_enabled, "%s lights need hard pixel masks and occlusion" % scene_path)
			_expect(light.has_node("PixelEmitter"), "%s lights need a visible native-pixel practical source" % scene_path)
			_expect(absf(light.color.r - light.color.g) < 0.002 and absf(light.color.g - light.color.b) < 0.002, "%s practical lights must not leak colour outside the noir palette" % scene_path)
		if scene_path == "res://scenes/main.tscn":
			_expect(level.has_node("TileMap/LightOccluders") and level.get_node("TileMap/LightOccluders").get_child_count() > 0, "nightclub walls need merged hard-edge light occluders")
			_expect(level.has_node("PixelVolumeLighting") and level.get_node("PixelVolumeLighting").get_child_count() == 3, "nightclub needs three restrained pixel-volume practical beams")
		level.queue_free()
		await get_tree().process_frame
	_expect(ambient_signatures.size() == MISSIONS.size(), "all twelve cases should expose a distinct ambient color script")
	if failures == 0: print("visual readability regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
