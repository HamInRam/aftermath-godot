extends Node

const RIG := preload("res://scripts/visuals/lifecycle_physics_rig_2d.gd")
const RAGDOLL := preload("res://scripts/effects/pixel_ragdoll_2d.gd")
const ART := preload("res://utility/pixel_actor_art.gd")
const TEXTURES := preload("res://utility/pixel_actor_texture_factory.gd")
const OUTPUT := "/tmp/aftermath_noir_actor_art.png"
const ROLES := ["player", "gunner", "melee", "assault", "heavy", "hound"]
var failures := 0
var corpse_sheet: Image

func _ready() -> void:
	var sheet := Image.create(256, 240, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("111111"))
	corpse_sheet = Image.create(200, 240, false, Image.FORMAT_RGBA8)
	corpse_sheet.fill(Color("777777"))
	for row in ROLES.size():
		var role: String = ROLES[row]
		var rig := RIG.new()
		add_child(rig)
		rig.configure("hound" if role == "hound" else ("player" if role == "player" else "enemy"), Color.RED, Color.CYAN, role)
		var joint_count := rig.points.size()
		var constraints := rig.constraints.duplicate(true)
		for direction in 8:
			rig.rotation = float(direction) * PI / 4.0
			rig.update_lifecycle(0.0, Vector2.ZERO, 100.0)
			var pixels := rig.get_live_art_pixels()
			_assert_native_pixels(pixels, "%s/%d" % [role, direction])
			var head_count := _part_count(pixels, "head")
			_expect(head_count >= 12 and head_count <= 30, "%s/%d must retain a compact crown" % [role, direction])
			if role != "hound":
				_expect(_part_count(pixels, "hand_a") >= 2 and _part_count(pixels, "hand_b") >= 2, "%s/%d must show both articulated palms" % [role, direction])
				_expect(_part_count(pixels, "torso") > head_count, "%s/%d shoulders must outweigh the small crown" % [role, direction])
			_expect(not rig.should_draw_legs(), "idle actor must occlude its feet")
			var image := ART.to_image(pixels, 32)
			sheet.blend_rect(image, Rect2i(0, 0, 32, 32), Vector2i(direction * 32, row * 40))
			# Pale floor strip verifies the same outer ink contour on light rooms.
			for y in range(row * 40 + 32, row * 40 + 40):
				for x in range(direction * 32, direction * 32 + 32): sheet.set_pixel(x, y, Color("bbbbbb"))
		_expect(rig.points.size() == joint_count and rig.constraints == constraints, "pixel authoring must never modify the physics skeleton")
		rig.rotation = 0.0
		rig.force_active()
		var preview := TEXTURES.get_frame(role).get_image()
		var live := ART.to_image(rig.get_live_art_pixels())
		_expect(preview.get_data() == live.get_data(), "%s preview must contain the actual live artwork" % role)
		_validate_corpse(rig, role)
		rig.queue_free()
	_validate_continuous_aim()
	_validate_weapon_poses()
	sheet.resize(1024, 960, Image.INTERPOLATE_NEAREST)
	_expect(sheet.save_png(OUTPUT) == OK, "native actor contact sheet must save")
	corpse_sheet.resize(800, 960, Image.INTERPOLATE_NEAREST)
	_expect(corpse_sheet.save_png("/tmp/aftermath_noir_corpse_art.png") == OK, "corpse anatomy contact sheet must save")
	if failures == 0: print("noir actor art regression: PASS // 48 live silhouettes, 30 missing-module cases // " + OUTPUT)
	else: push_error("noir actor art regression: %d failure(s)" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _validate_corpse(rig: Node2D, role: String) -> void:
	for missing in ["", "head", "arm_front", "arm_back", "leg_back"]:
		var corpse := RAGDOLL.new()
		add_child(corpse)
		var modules := PackedStringArray() if missing.is_empty() else PackedStringArray([missing])
		corpse.setup(Vector2.RIGHT, 12.0, modules, 0, "hound" if role == "hound" else "human", {}, rig.get_pose_snapshot())
		for frame in 35: corpse._physics_process(1.0 / 60.0)
		corpse.freeze_pose()
		_expect(corpse.visual_role == role, "%s corpse must inherit the living role" % role)
		_expect(corpse.cloth_color == ART.palette(role).c, "%s corpse must retain its living cloth value" % role)
		var cells := corpse.get_art_pixels()
		_assert_native_pixels(cells, role + " corpse")
		if not missing.is_empty():
			_expect(_part_count(cells, missing) == 0, "%s missing %s may not paint a replacement limb" % [role, missing])
			_expect(_part_count(cells, "cut") > 0, "removed module must leave a connected cut edge")
		else: _expect(_part_count(cells, "head") > 0, "intact corpse must retain the crown")
		var image := ART.to_image(cells, 40)
		corpse_sheet.blend_rect(image, Rect2i(0, 0, 40, 40), Vector2i(["", "head", "arm_front", "arm_back", "leg_back"].find(missing) * 40, ROLES.find(role) * 40))
		corpse.queue_free()

func _validate_continuous_aim() -> void:
	var rig := RIG.new()
	add_child(rig)
	var snapshots := []
	for degrees in [0.0, 10.0, 20.0]:
		rig.rotation = deg_to_rad(degrees)
		rig.update_lifecycle(0.0, Vector2.ZERO, 100.0)
		_expect(rig.facing_direction.is_equal_approx(Vector2.RIGHT.rotated(rig.rotation)), "visual aim must follow the continuous angle")
		_expect(rig.get_facing_sector() == 0, "sector hysteresis remains independent of continuous artwork")
		snapshots.append(ART.to_image(rig.get_live_art_pixels(), 32).get_data())
	_expect(snapshots[0] != snapshots[1] and snapshots[1] != snapshots[2], "continuous aim must update silhouette inside the same sector")
	rig.queue_free()

func _validate_weapon_poses() -> void:
	var rig := RIG.new()
	add_child(rig)
	rig.configure("player", Color.WHITE, Color.WHITE, "player")
	var sheet := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("777777"))
	var snapshots := []
	for row in 4:
		rig.set_weapon_stance(["handgun", "carbine", "shotgun", "melee"][row])
		for direction in 8:
			rig.rotation = direction * PI / 4.0
			rig.update_lifecycle(0.0, Vector2.ZERO, 100.0)
			var cells := rig.get_live_art_pixels()
			_assert_native_pixels(cells, "weapon grip")
			for at: Vector2 in cells:
				_expect(absf(at.x) < 16 and absf(at.y) < 16, "grips may not clip the authoring canvas")
			sheet.blend_rect(ART.to_image(cells), Rect2i(0, 0, 32, 32), Vector2i(direction * 32, row * 32))
			if direction == 0: snapshots.append(ART.to_image(cells).get_data())
	_expect(snapshots[0] != snapshots[1] and snapshots[1] != snapshots[2], "handgun, rifle and shotgun must have different support grips")
	rig.set_weapon_stance("carbine")
	rig.rotation = 0.0
	rig.update_lifecycle(0.0, Vector2.ZERO, 100.0, Vector2.ZERO, 0.0, "reload", 0.5)
	_expect(ART.to_image(rig.get_live_art_pixels()).get_data() != snapshots[1], "reload must visibly release the support hand")
	rig.update_lifecycle(0.0, Vector2.ZERO, 100.0, Vector2.ZERO, 0.0, "reload", 1.0)
	_expect(ART.to_image(rig.get_live_art_pixels()).get_data() == snapshots[1], "finished reload must return exactly to grip")
	sheet.resize(1024, 512, Image.INTERPOLATE_NEAREST)
	sheet.save_png("/tmp/aftermath_weapon_grips.png")
	rig.queue_free()

func _assert_native_pixels(cells: Dictionary, label: String) -> void:
	for at: Vector2 in cells:
		var color: Color = cells[at].color
		_expect(at == at.round(), label + " must use one native integer cell")
		_expect(is_equal_approx(color.r, color.g) and is_equal_approx(color.g, color.b), label + " must use neutral anatomy and clothing")

func _part_count(cells: Dictionary, part: String) -> int:
	var count := 0
	for cell: Dictionary in cells.values():
		if cell.part == part: count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
