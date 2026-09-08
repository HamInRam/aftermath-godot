extends Node2D

const PROFILE := preload("res://utility/weapon_presentation_profile.gd")
const ART := preload("res://utility/weapon_pixel_art.gd")
const GUN := preload("res://scenes/gun.tscn")
const PLAYER := preload("res://scenes/player.tscn")
const CAMERA := preload("res://scripts/camera/trauma_camera.gd")
const FEEDBACK := preload("res://scripts/controllers/combat_feedback.gd")
const CASING := preload("res://scenes/effects/shell_casing.tscn")
const FLASH := preload("res://scenes/effects/muzzle_flash.tscn")
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_save := Progression.save_path
	Progression.save_path = "/tmp/aftermath_weapon_presentation_%d.json" % OS.get_process_id()
	var silhouettes: Dictionary = {}
	for weapon_class in WeaponPlatformCatalog.CLASS_ORDER:
		var first_id := WeaponPlatformCatalog.get_class_weapon_ids(weapon_class)[0]
		var first_shape := ART.get_shape(AttackCatalog.get_gun_data(first_id))
		var signature := ""
		for cell in first_shape: signature += str(cell.position)
		_expect(not silhouettes.has(signature), "each class must have its own silhouette: " + weapon_class)
		silhouettes[signature] = true
		for weapon_id in WeaponPlatformCatalog.get_class_weapon_ids(weapon_class):
			var data := AttackCatalog.get_gun_data(weapon_id)
			var cells := ART.get_shape(data)
			_expect(cells.size() >= 24, "all platform IDs must keep a readable pixel silhouette: " + weapon_id)
			for cell in cells:
				var point: Vector2 = cell.position
				var color: Color = cell.color
				_expect(point == point.round(), "weapon cells must remain native integer pixels")
				_expect(is_equal_approx(color.r, color.g) and is_equal_approx(color.g, color.b), "ordinary weapons must contain no cyan/gold/red pixels")
		var profile := PROFILE.for_class(weapon_class)
		var kick := PROFILE.recoil_pose(profile, 0.0)
		var seated := PROFILE.recoil_pose(profile, 1.0)
		_expect(kick.offset.x < -1.0 and absf(float(kick.angle)) > 0.02, "class recoil needs visible immediate kick")
		_expect((seated.offset as Vector2).length() < 0.001 and is_zero_approx(float(seated.angle)), "recoil must seat exactly at zero")
	_write_contact_sheet()
	var gun := GUN.instantiate() as Gun
	add_child(gun)
	gun.set_process(false)
	for player_audio in [gun.shot_audio, gun.mechanical_audio, gun.punch_audio, gun.reload_audio]: player_audio.stream = null
	gun.set_gun_data(AttackCatalog.get_gun_data("hk_mp5a5"), true)
	gun.fire_interval_variance = 0.0
	gun.set_weapon_ammo(gun.weapon_id, gun.max_ammo)
	var shots := 0
	var old_muzzle := gun.muzzle.global_position
	for frame in range(60):
		if gun.try_fire(Vector2.RIGHT): shots += 1
		gun._process(1.0 / 60.0)
	_expect(shots >= 13 and shots <= 14, "750 RPM must not quantize down to 600 RPM at 60Hz")
	_expect(gun.muzzle.global_position == old_muzzle and is_zero_approx(gun.weapon_pivot.rotation), "visual recoil may not rotate or translate the ballistic muzzle")
	gun.cancel_reload(false)
	gun.set_weapon_ammo(gun.weapon_id, 2)
	gun.set_reserve_ammo(gun.weapon_id, 10)
	gun.reload()
	var phases: Array[String] = []
	for progress in [0.08, 0.40, 0.78, 0.95]:
		gun.reload_timer.start(gun.active_reload_duration * (1.0 - progress))
		gun._update_weapon_presentation(0.0)
		phases.append(gun.reload_phase)
		_expect(gun.ammo == 2 and gun.reserve_ammo == 10, "reload graphics cannot credit ammunition before completion")
	_expect(phases == ["lower", "exchange", "chamber", "ready"], "magazine reload must expose four ordered visual phases")
	gun.cancel_reload()
	_expect(gun.visual_offset == Vector2.ZERO and is_zero_approx(gun.visual_angle) and gun.magazine_offset == Vector2.ZERO, "cancelling reload must fully reset visual parts")
	gun._on_reload_timer_timeout()
	_expect(gun.ammo == 2 and gun.reserve_ammo == 10, "cancelled reload must not duplicate ammunition")
	gun.reload()
	gun._on_reload_timer_timeout()
	_expect(gun.ammo == 12 and gun.reserve_ammo == 0, "reload completion still transfers exact finite reserve")
	var cached_cell_count := ART.get_shape(gun.gun_data).size()
	var previous_data: GunData = gun.gun_data
	gun.clear_equipped_weapon()
	_expect(ART.get_shape(previous_data).size() == cached_cell_count, "throw/clear must not erase the shared weapon-art cache")
	gun.set_gun_data(AttackCatalog.get_gun_data("mossberg_590a1"), true)
	gun.set_weapon_ammo(gun.weapon_id, 0)
	gun.set_reserve_ammo(gun.weapon_id, 7)
	gun.reload()
	gun.reload_timer.start(gun.active_reload_duration * 0.55)
	gun._update_weapon_presentation(0.0)
	_expect(gun.reload_phase == "feed" and gun.magazine_offset.y > 1.0, "tube shotgun must show shell feeding instead of box-magazine swap")
	gun.cancel_reload()
	var player = PLAYER.instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(100, 100)
	player.actual_aim_angle = 0.0
	player.using_controller_aim = false
	var expected_angle: float = player.global_position.angle_to_point(player.get_global_mouse_position())
	player._update_aim_solution(0.00001)
	_expect(absf(angle_difference(player.actual_aim_angle, expected_angle)) < 0.001, "mouse aim must resolve instantly even with tiny slowed delta")
	player.gun.rotation = 0.42
	player._update_procedural_motion(0.001)
	_expect(is_zero_approx(player.gun.rotation), "locomotion/reload body animation cannot rotate the ballistic carrier")
	player.actual_aim_angle = 0.0
	var pickup := Node2D.new()
	pickup.add_to_group("weapon_pickup")
	add_child(pickup)
	pickup.global_position = Vector2(124, 100)
	await get_tree().physics_frame
	_expect(player.get_nearby_weapon_pickup() == pickup, "manual pickup should reach a nearby 24px weapon")
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(3, 24)
	shape.shape = rectangle
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = Vector2(112, 100)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(player.get_nearby_weapon_pickup() == null, "larger pickup radius must not collect a gun through a wall")
	var casing = CASING.instantiate()
	add_child(casing)
	casing.position = Vector2(210, 190)
	casing.setup(Vector2.RIGHT, false)
	casing._process(1.0 / 60.0)
	_expect(casing.position.distance_to(Vector2(210, 190)) < 2.0 and casing.rotation == 0.0, "casing must eject from its assigned position using unrotated 1px cells")
	var flash = FLASH.instantiate()
	flash.setup(Vector2.RIGHT, 30.0, 0.05, true)
	add_child(flash)
	_expect(flash.blood_enhanced and flash.light.color.r > flash.light.color.g, "enhanced flash must remain crimson after ready")
	var camera := CAMERA.new() as TraumaCamera
	add_child(camera)
	camera.set_physics_process(false)
	for index in range(20): camera.add_directional_impulse(Vector2.LEFT, 2.0)
	_expect(camera.directional_offset.x < 0 and absf(camera.directional_offset.y) < 0.001 and camera.directional_offset.length() <= 2.601, "repeated shot kicks must stay directional and bounded")
	var feedback := FEEDBACK.new() as CombatFeedback
	add_child(feedback)
	feedback.trigger_hit_stop(0.20)
	var deadline := feedback.hit_stop_deadline_msec
	for index in range(9): feedback.trigger_hit_stop(0.20)
	_expect(feedback.hit_stop_deadline_msec == deadline and deadline - Time.get_ticks_msec() <= 28, "pellets may not prolong a hit-stop beyond 28ms")
	# Match the feedback's monotonic clock. Fast headless SceneTree timers can
	# advance simulated delta ahead of wall time during this synthetic burst.
	var recovery_deadline := Time.get_ticks_msec() + 100
	while Time.get_ticks_msec() < recovery_deadline: await get_tree().process_frame
	_expect(not feedback.hit_stop_active and is_equal_approx(Engine.time_scale, 1.0), "bounded hit-stop must restore the game clock")
	feedback.reset()
	Progression.save_path = original_save
	for actor in [player, gun]:
		for audio_node in actor.find_children("*", "AudioStreamPlayer", true, false):
			(audio_node as AudioStreamPlayer).stop()
			(audio_node as AudioStreamPlayer).stream = null
	await get_tree().create_timer(0.12).timeout
	if failures == 0: print("weapon presentation regression: PASS")
	get_tree().quit(failures)

func _write_contact_sheet() -> void:
	var image := Image.create(320, 288, false, Image.FORMAT_RGBA8)
	image.fill(Color("363636"))
	for row in range(8):
		var data := AttackCatalog.get_gun_data(WeaponPlatformCatalog.STARTER_WEAPONS[row])
		for column in range(8):
			var forward := Vector2.RIGHT.rotated(float(column) * PI / 4.0)
			var center := Vector2(column * 40 + 17, row * 36 + 16)
			var origin := center - forward * (float(data.visual_length_pixels) - 3.0) * 0.5
			for cell in ART.get_shape(data):
				var point: Vector2 = cell.position
				var target := (origin + forward * point.x + forward.orthogonal() * point.y).round()
				if target.x >= 0 and target.x < image.get_width() and target.y >= 0 and target.y < image.get_height(): image.set_pixelv(target, cell.color)
	image.resize(960, 864, Image.INTERPOLATE_NEAREST)
	image.save_png("/tmp/aftermath_weapon_contactsheet.png")

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
