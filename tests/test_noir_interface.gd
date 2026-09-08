extends Node

const HUD := preload("res://scripts/ui/hud_controller.gd")
const TITLE := preload("res://scenes/ui/title_menu.tscn")
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var hud := HUD.new()
	add_child(hud)
	hud.set_roguelike_mode(true)
	hud.set_combat_counts(20, 0, 0)
	hud.ammo_label.text = "100/100  +200"
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(hud.ammo_label.text == "100 +200", "HUD must show reserve ammo without cutting off its number")
	_expect(hud.ammo_label.get_minimum_size().x <= hud.ammo_label.size.x, "largest normal magazine string must fit")
	var permanent := [hud.resource_backplate, hud.tactical_backplate, hud.vitality_backplate, hud.focus_backplate, hud.blood_backplate]
	var safe := Rect2(0, 0, 320, 180)
	for index in permanent.size():
		var rectangle: Rect2 = permanent[index].get_rect()
		_expect(safe.encloses(rectangle), "every corner instrument must fit the native viewport")
		for other in range(index + 1, permanent.size()):
			_expect(not rectangle.intersects(permanent[other].get_rect()), "HUD instruments may not overlap")
	_expect(hud.focus_backplate.position.x < 80 and hud.blood_backplate.position.x > 240, "Focus charges and blood reserve must occupy separate corners")
	_expect(not hud.camera_count_icon.visible and not hud.alarm_count_icon.visible, "absent tactical systems must not consume attention")
	_expect(not hud.blood_skill_label.visible, "skill cheat sheet must not stay over combat while blood stance is inactive")
	hud.reticle.set_aim_feedback({"spread_pixels": 1.05}, true)
	hud.reticle.set_aim_feedback({"spread_pixels": 1.2}, true)
	_expect(is_equal_approx(float(hud.reticle.aim_state.spread_pixels), 1.2), "reticle redraw cache must use the same quantization as its painted gap")
	hud.set_interaction("[ E ] PICK UP WALTHER_PDP_COMPACT")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(hud.context_backplate.get_rect().encloses(hud.interaction_label.get_rect()), "long platform names must elide inside the interaction card")
	hud.set_interaction("[ SPACE ] EXECUTE")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not hud.keycap_label.get_rect().intersects(hud.interaction_icon.get_rect()), "execution keycap must not overlap its action icon")
	hud.detail_label.text = "GLOCK_17_GEN5_MOS PRECISION x3 // EMPTY MAG RELOAD BOOST"
	hud.set_blood_resource(24, 100, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(hud.status_backplate.get_rect().encloses(hud.detail_label.get_rect()), "precision messages must stay inside their transient card")
	_expect(safe.encloses(hud.blood_skill_label.get_rect()), "active blood-skill hints must stay on screen")
	hud.queue_free()
	await get_tree().process_frame
	var title := TITLE.instantiate()
	add_child(title)
	await get_tree().create_timer(0.35).timeout
	var plate: Image = title.get_node("InkPlate").texture.get_image()
	_expect(plate.get_size() == Vector2i(320, 180), "menu artwork must be native 1x1 pixels")
	for y in plate.get_height():
		for x in plate.get_width():
			var color := plate.get_pixel(x, y)
			var gray := is_equal_approx(color.r, color.g) and is_equal_approx(color.g, color.b)
			var blood := color.r > 0.6 and color.g < 0.1 and color.b < 0.15
			_expect(gray or blood, "menu artwork may only contain grayscale and blood crimson")
	for child in title.get_node("Panel/VBox").get_children():
		if child is Control and child.visible:
			_expect(safe.encloses(child.get_global_rect()), "title action must remain on screen: " + child.name)
	_expect(title.get_node("Panel/VBox/NightclubButton").has_focus(), "new run must receive initial keyboard focus")
	title.queue_free()
	await get_tree().process_frame
	if failures == 0: print("noir interface regression: PASS // native artwork, readable ammo, separate resource corners, safe menu bounds")
	get_tree().quit(0 if failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
