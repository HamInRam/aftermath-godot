extends Node2D

const DOOR_SCENE := preload("res://scenes/props/swing_door.tscn")

var failures := 0

func _ready() -> void:
	var atlas := PixelEnvironmentAtlas.create_texture()
	var atlas_image := atlas.get_image()
	_expect(atlas_image.get_width() == 256 and atlas_image.get_height() == 8, "environment tiles must be generated as a strict 32 x 8px pixel atlas")
	_expect(atlas_image.get_pixel(0, 0).a > 0.99 and atlas_image.get_pixel(24, 0).a > 0.99, "generated floor and wall pixels must be opaque")
	_expect(atlas_image.get_pixel(192, 0).a < 0.01, "overlay tiles must preserve transparent pixel cells")

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
