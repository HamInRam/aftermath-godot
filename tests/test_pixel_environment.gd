extends Node2D

const DOOR_SCENE := preload("res://scenes/props/swing_door.tscn")
const PIXEL_MATERIAL_CANVAS := preload("res://utility/pixel_material_canvas.gd")

var failures := 0

func _ready() -> void:
	var atlas := PixelEnvironmentAtlas.create_texture()
	var atlas_image := atlas.get_image()
	_expect(atlas_image.get_width() == PixelEnvironmentAtlas.TILE_SIZE * PixelEnvironmentAtlas.TILE_COUNT and atlas_image.get_height() == PixelEnvironmentAtlas.TILE_SIZE, "environment tiles must preserve the strict 8x8 native pixel grid")
	_expect(atlas_image.get_pixel(0, 0).a > 0.99 and atlas_image.get_pixel(24, 0).a > 0.99, "generated floor and wall pixels must be opaque")
	_expect(atlas_image.get_pixel(192, 0).a < 0.01, "overlay tiles must preserve transparent pixel cells")
	for tile_index in range(32, PixelEnvironmentAtlas.TILE_COUNT):
		var colors := {}
		for y in PixelEnvironmentAtlas.TILE_SIZE:
			for x in PixelEnvironmentAtlas.TILE_SIZE:
				var sample := atlas_image.get_pixel(tile_index * PixelEnvironmentAtlas.TILE_SIZE + x, y)
				if sample.a > 0.99: colors[sample.to_html(false)] = true
		_expect(colors.size() >= 4, "new architectural materials must use at least four opaque pixel colors per tile")

	var micro_materials := {Vector2i(0,0): 0, Vector2i(1,0): 1, Vector2i(0,1): 32, Vector2i(1,1): 37}
	var material_texture: ImageTexture = PIXEL_MATERIAL_CANVAS.create_texture(Vector2i(2,2), Vector2i(8,8), micro_materials, 71)
	var material_image := material_texture.get_image()
	_expect(material_image.get_size() == Vector2i(16,16), "world material canvas must retain one texel per world pixel")
	var concrete_colors := {}
	for y in 8:
		for x in 8: concrete_colors[material_image.get_pixel(x,y).to_html(false)] = true
	_expect(concrete_colors.size() >= 2 and concrete_colors.size() <= 5, "continuous material fields need a dominant ground tone plus restrained structural variation")
	_expect(material_image.get_pixel(7,2) != material_image.get_pixel(15,2), "adjacent material cells must retain distinct authored identities")
	var nightclub_materials := {Vector2i(0,0): 9, Vector2i(1,0): 12, Vector2i(0,1): 34, Vector2i(1,1): 37}
	var nightclub_image := PIXEL_MATERIAL_CANVAS.create_texture(Vector2i(2,2), Vector2i(8,8), nightclub_materials, 91, "nightclub").get_image()
	var nightclub_colors := {}
	var uniform_blocks := 0
	for y in nightclub_image.get_height():
		for x in nightclub_image.get_width():
			var sample := nightclub_image.get_pixel(x,y)
			nightclub_colors[sample.to_html(false)] = true
			_expect(absf(sample.r - sample.g) < 0.002 and absf(sample.g - sample.b) < 0.002, "environment source materials should already be neutral before post-processing")
	for y in range(nightclub_image.get_height() - 1):
		for x in range(nightclub_image.get_width() - 1):
			var sample := nightclub_image.get_pixel(x,y)
			if sample == nightclub_image.get_pixel(x+1,y) and sample == nightclub_image.get_pixel(x,y+1) and sample == nightclub_image.get_pixel(x+1,y+1): uniform_blocks += 1
	_expect(nightclub_colors.size() >= 6 and nightclub_colors.size() <= 20, "nightclub surfaces should remain distinct without becoming a noisy rainbow of near-duplicate values")
	_expect(uniform_blocks > 0, "nightclub surfaces need quiet multi-pixel fields so actors, bullets and blood remain readable")

	var light_texture := PixelLightTextureFactory.create_texture()
	var light_image := light_texture.get_image()
	_expect(light_image.get_width() == 128 and light_image.get_height() == 128, "environment light masks must preserve one texel per world pixel at their full footprint")
	var alpha_values := {}
	for y in light_image.get_height():
		for x in light_image.get_width(): alpha_values[snappedf(light_image.get_pixel(x, y).a, 0.01)] = true
	_expect(alpha_values.size() <= 6, "pixel lighting must use discrete alpha bands rather than a smooth gradient")

	var door := DOOR_SCENE.instantiate()
	add_child(door)
	_expect(not door.get_node("Frame/TopFrame").visible and not door.get_node("Door/Panel").visible, "legacy vector door art must remain disabled")
	_expect(door.get_node("Frame").get_script() != null, "door frame must use the generated pixel renderer")
	_expect((door.get_node("Door/PanelCollision").shape as RectangleShape2D).size == Vector2(4, 24), "doors should use a full three-tile human-scale leaf")

	var prop := DestructibleProp.new()
	add_child(prop)
	prop.setup("sink", Color("65d8d2"))
	_expect(prop.material_profile.hazard == "water", "pixel props must retain their systemic destruction material and liquid consequence")
	prop.receive_projectile_impact_context(Vector2.RIGHT * 650.0, prop.global_position, "shotgun", 2)
	await get_tree().process_frame
	_expect(prop.state == DestructibleProp.PropState.DESTROYED, "pixel migration must preserve destructible state transitions")

	if failures == 0: print("pixel environment regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
