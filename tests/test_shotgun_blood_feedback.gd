extends Node2D

## One bounded fixture: production Main dispatch/impact handling, Bullet swept
## collision, Actor/BallisticDamageResolver, DamageContext, and BloodSystem.
## No level loading, AI, cleanup scenes, audio, input, or global hit-stop loop.
const MAIN := preload("res://scripts/main.gd")
const CORPSE := preload("res://scenes/corpse.tscn")
const WEAPON := "mossberg_590a1"
const SHOT_ID := 5901
var failures := 0

class ShotOwner:
	extends CharacterBody2D
	var gun: Gun

class FeedbackMain:
	extends "res://scripts/main.gd"
	var impacts: Array[Dictionary] = []
	var terminal_spent := 0
	var peak_mist := 0
	var native_mist := true
	var crimson_mist := true
	var visual_only_mist := true
	func _ready() -> void: set_process(false)
	func _exit_tree() -> void: pass
	func _trigger_hit_stop(_duration: float) -> void: pass
	func _on_damage_impact(context: DamageContext) -> void:
		var incoming := context.blood_budget_raw
		super._on_damage_impact(context)
		# In a live level this is invoked by _on_enemy_died after actor damage.
		# Keep production impact-to-death budget ownership; omit unrelated loot/UI.
		var terminal := 0
		if context.lethal:
			terminal = blood_system.spawn_death_burst_budgeted(context.hit_position,
				pending_death_blood_power, Vector2.ZERO, context.direction,
				context.weapon_id, pending_death_blood_budget_raw, pending_death_stain_radius)
		terminal_spent += terminal
		impacts.append({"stage": context.target.get_meta("stage"), "lane": context.target.get_meta("lane"),
			"incoming": incoming, "remaining": context.blood_budget_raw,
			"impact": context.blood_budget_spent_raw, "terminal": terminal,
			"damage": context.damage, "lethal": context.lethal, "radius": context.blood_stain_radius,
			"terminal_radius": pending_death_stain_radius,
			"source_radius": context.weapon_source.blood_stain_radius if context.weapon_source != null else -1.0})
		var mist: BloodMistBatch = blood_system.mist_batch
		peak_mist = maxi(peak_mist, mist.particles.size())
		var mesh: MultiMesh = mist.particle_batch.multimesh
		native_mist = native_mist and (mesh.mesh as QuadMesh).size == Vector2.ONE
		# The dummy headless rendering server does not retain instance transforms.
		# Quad dimensions/palette/ledger run in CI; execute this same fixture with
		# the real renderer as well to inspect every submitted pixel transform.
		if DisplayServer.get_name() != "headless":
			for index in mesh.visible_instance_count:
				var transform := mesh.get_instance_transform_2d(index)
				var corner := transform.origin - Vector2(0.5,0.5)
				native_mist = native_mist and transform.x == Vector2.RIGHT and transform.y == Vector2.DOWN and corner == corner.round()
		for particle: Dictionary in mist.particles:
			crimson_mist = crimson_mist and particle.color == NeonPalette.BLOOD_CRIMSON
		for count: int in mist.emission_remaining.values():
			visual_only_mist = visual_only_mist and count == 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var saved_settings := {"gore_enabled": Settings.gore_enabled, "ragdoll_enabled": Settings.ragdoll_enabled, "blood_density": Settings.blood_density}
	Settings.update_values({"gore_enabled": true, "ragdoll_enabled": true, "blood_density": 1.0}, false)
	RuntimeBudget.override_limits_for_test({"gore": 0})
	seed(5901)
	var data := AttackCatalog.get_gun_data(WEAPON).duplicate() as GunData
	data.blood_stain_radius = 13.0
	_expect(data.pellet_count == 9 and data.damage == 30, "arcade Mossberg must emit nine 30-damage pellets")
	_test_resolver_shape(data)
	var harness := FeedbackMain.new()
	var blood := BloodSystem.new()
	blood.name = "BloodSystem"
	harness.add_child(blood)
	var targets := Node2D.new()
	targets.name = "Enemies"
	harness.add_child(targets)
	var camera := Node2D.new()
	camera.name = "TraumaCamera"
	harness.add_child(camera)
	add_child(harness)
	var reserve := BloodResourceController.new()
	harness.add_child(reserve)
	reserve.reserve = 50.0
	reserve.set_stance_active(true)
	harness.blood_resource = reserve
	# Only the shot identity and gun data are supplied by this host. Dispatch and
	# every resulting projectile are production code, including budget division.
	var shooter := ShotOwner.new()
	shooter.gun = Gun.new()
	shooter.gun.gun_data = data
	shooter.gun.weapon_id = WEAPON
	shooter.gun.current_shot_id = SHOT_ID
	harness.player = shooter
	harness.hud = HudController.new()
	harness.combat_feedback = CombatFeedback.new()
	for lane in data.pellet_count:
		for stage in 2:
			var target := Actor.new()
			target.max_hp = 10
			target.collision_layer = 2
			target.collision_mask = 0
			target.position = Vector2(22.0 + stage*30.0, lane*40.0)
			target.set_meta("lane",lane)
			target.set_meta("stage",stage)
			target.add_to_group("enemy")
			var shape_node := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(4,12)
			shape_node.shape = shape
			target.add_child(shape_node)
			targets.add_child(target)
	await get_tree().physics_frame
	var initial_reserve := reserve.reserve
	for lane in data.pellet_count:
		harness._on_projectile_requested(Vector2(0,lane*40),Vector2.RIGHT,false,data.damage,WEAPON,shooter)
	data.blood_stain_radius = 88.0 # In-flight rounds must retain the original 13.
	var paid := initial_reserve - reserve.reserve
	var shot_budget := int(reserve.enhanced_shot_cache.raw_blood_budget)
	var per_pellet := floori(float(shot_budget)/data.pellet_count)
	var bullets := harness.get_children().filter(func(node: Node) -> bool: return node.get_script() == preload("res://scripts/bullet.gd"))
	_expect(bullets.size() == 9, "production Main must dispatch all nine pellets")
	_expect(is_equal_approx(paid,3.5), "all nine dispatch calls sharing a shot ID must charge exactly 3.5 blood")
	for bullet in bullets:
		_expect(bullet.blood_enhanced and bullet.blood_budget_raw == per_pellet, "Main must divide the paid raw ledger by nine")
		_expect(bullet.damage == roundi(float(data.damage)*reserve.enhanced_damage_multiplier), "blood enhancement must apply once per pellet")
		_expect(is_equal_approx(bullet.penetration_power,data.penetration_power+reserve.enhanced_penetration_bonus), "penetration bonus must apply once per pellet")
	for frame in 18: await get_tree().physics_frame
	_expect(harness.impacts.size() == 18, "nine real pellets must each traverse both low-health targets")
	var first_hits := 0
	var followup_hits := 0
	var declared_spent := 0
	for impact: Dictionary in harness.impacts:
		declared_spent += int(impact.impact) + int(impact.terminal)
		_expect(impact.lethal, "penetration fixture must exercise the lethal budget transfer")
		_expect(float(impact.radius) == 13.0 and float(impact.terminal_radius) == 13.0, "runtime radius snapshot reaches every impact and terminal burst")
		_expect(float(impact.source_radius) == 13.0, "detached GunData survives live weapon mutation and penetration")
		_expect(int(impact.remaining) == 0, "production Main must transfer lethal remainder away from the continuing projectile")
		if int(impact.stage) == 0:
			first_hits += 1
			_expect(int(impact.incoming) == per_pellet, "first target owns only its pellet's share")
		else:
			followup_hits += 1
			_expect(int(impact.incoming) == 0 and int(impact.impact) == 0 and int(impact.terminal) == 0, "penetration must not reset a spent ledger on a second body")
	_expect(first_hits == 9 and followup_hits == 9, "all nine penetration chains must be observed")
	_expect(harness.terminal_spent > 0, "the regression must actually exercise budgeted death bursts")
	_expect(harness.peak_mist >= 9*18 and harness.native_mist, "shotgun mist must use visible unit-sized quads on integer pixel cells")
	_expect(harness.crimson_mist and harness.visual_only_mist, "enhanced mist must be crimson with zero unbudgeted ground deposits")
	var raw_before_settle := _raw_mass(blood)
	(blood.mist_batch as BloodMistBatch)._process(1.0)
	_expect((blood.mist_batch as BloodMistBatch).particles.is_empty(), "all remaining mist must be expired before recovery is measured")
	_expect(_raw_mass(blood) == raw_before_settle, "landing enhanced mist may not mint extra recoverable blood")
	var recovered_raw := _drain_all(blood)
	_expect(recovered_raw > 0 and recovered_raw == raw_before_settle, "real siphoning must recover exactly the deposited raw mass")
	_expect(recovered_raw <= declared_spent and declared_spent <= per_pellet*9, "impact plus terminal deposits must fit inside the nine allocated shares")
	_expect(float(recovered_raw)*reserve.RAW_TO_RESOURCE <= paid*0.72+0.000001, "perfect recovery must return at most 72 percent of the paid shot")
	_expect(_raw_mass(blood) == 0 and _drain_all(blood) == 0, "drained blood must not be collectable a second time")
	print("SHOTGUN_BLOOD_LEDGER ", JSON.stringify({"pellets":bullets.size(),"cost":paid,"shot_raw_budget":shot_budget,"raw_per_pellet":per_pellet,"recovered_raw":recovered_raw,"recovered_resource":recovered_raw*reserve.RAW_TO_RESOURCE,"penetration_hits":followup_hits,"mist_peak":harness.peak_mist}))
	await _test_corpse(data)
	harness.hud.free()
	harness.combat_feedback.free()
	shooter.gun.free()
	shooter.free()
	harness.queue_free()
	await get_tree().process_frame
	Settings.update_values(saved_settings,false)
	RuntimeBudget.restore_default_limits()
	AttackCatalog.GUNS.clear()
	ProceduralAudioLibrary.clear_cache()
	if failures == 0: print("SHOTGUN_BLOOD_FEEDBACK_REGRESSION_OK")
	get_tree().quit(0 if failures == 0 else 1)

func _test_resolver_shape(data: GunData) -> void:
	var buckshot := BallisticDamageResolver.resolve(18.0,data.penetration_power,"torso",20.0,data.damage_falloff_start,data.damage_falloff_end,data.minimum_damage_ratio,100,100,0.0,0.0,0.0,false,false,"shotgun")
	var same_calibre := BallisticDamageResolver.resolve(18.0,data.penetration_power,"torso",20.0,data.damage_falloff_start,data.damage_falloff_end,data.minimum_damage_ratio,100,100,0.0,0.0,0.0,false,false,"handgun")
	var context := DamageContext.create(Vector2.ZERO,Vector2.RIGHT,int(buckshot.health_damage),WEAPON,20.0,false,"torso")
	context.apply_ballistic_result(buckshot)
	_expect(context.damage == 18 and int(same_calibre.health_damage) == 18, "spray presentation changes must not change eighteen-point health damage")
	_expect(is_equal_approx(context.entry_wound_scale,float(same_calibre.entry_wound_scale)) and is_equal_approx(context.exit_wound_scale,float(same_calibre.exit_wound_scale)), "pellet density must not shrink entry/exit wound geometry a second time")
	_expect(context.external_blood_scale < float(same_calibre.external_blood_scale), "pellet crowding must still reduce density once")
	_expect(context.projectile_exited and context.exit_wound_scale > 0.5 and context.mist_scale > 0.35, "close buckshot needs a readable resolved exit spray")

func _test_corpse(data: GunData) -> void:
	var arena := Node2D.new()
	arena.position = Vector2(500,500)
	add_child(arena)
	var corpse = CORPSE.instantiate()
	arena.add_child(corpse)
	corpse.setup(0.0,Vector2.RIGHT,999.0,data.blood_power,"firearm_gib","limb",WEAPON,20.0)
	_expect(corpse.missing_modules.has("arm_front") and corpse.missing_modules.has("leg_back"), "shotgun limb wound must remove the authored modules")
	_expect(is_instance_valid(corpse.ragdoll) and corpse.ragdoll.wound_state == corpse.dismemberment_state, "shotgun corpse must retain its live wound-aware ragdoll")
	_expect(corpse.velocity.length() <= 52.001 and float(corpse.ragdoll_impact_profile.linear_force) <= 96.0 and float(corpse.ragdoll_impact_profile.limb_force) <= 170.0, "extreme input knockback must remain inside body and joint limits")
	var detached := arena.get_children().filter(func(node: Node) -> bool: return node is DetachedLimb)
	_expect(detached.size() == corpse.missing_modules.size(), "only missing anatomy may become detached pieces")
	for limb: DetachedLimb in detached: _expect(not limb.allow_blood_trail, "shotgun anatomy cannot create renewable blood trails")
	# Production enemy rigs deliberately include a 0.85s articulation bonus:
	# 2.15 + force/145*0.65 + 0.85 is about 3.43s for this blast. A hard-coded
	# 200-frame (~3.33s) observation ended before the authored deadline.
	_expect(corpse.ragdoll.active_time > 0.0 and corpse.ragdoll.active_time <= 4.0, "enemy shotgun articulation deadline must be finite and at most four seconds")
	for frame in ceili(4.1 * Engine.physics_ticks_per_second): await get_tree().physics_frame
	_expect(corpse.ragdoll.frozen, "ragdoll simulation must settle in bounded time")
	_expect(corpse.position.length() < 80.0, "shotgun body cannot cross a room after its bounded impulse")
	var cells: Dictionary = corpse.ragdoll.get_art_pixels()
	var cut_count := 0
	for point: Vector2 in cells:
		var cell: Dictionary = cells[point]
		var color: Color = cell.color
		_expect(point == point.round(), "corpse artwork must retain native integer pixels")
		_expect(is_equal_approx(color.r,color.g) and is_equal_approx(color.g,color.b), "shotgun corpse anatomy and clothing must remain grayscale")
		_expect(not corpse.missing_modules.has(str(cell.part)), "a removed body module may not be repainted")
		if str(cell.part) == "cut": cut_count += 1
	_expect(cut_count > 0, "missing modules must leave visible attached cut edges")
	arena.queue_free()
	await get_tree().process_frame

func _raw_mass(system: BloodSystem) -> int:
	var total := 0
	for canvas in [system.ground_canvas,system.wall_canvas]:
		for chunk in canvas.chunks.values():
			if is_instance_valid(chunk): total += int(chunk.blood_load)
	return total

func _drain_all(system: BloodSystem) -> int:
	var total := 0
	for iteration in 4:
		var result := system.absorb_pixel_blood(Vector2(30,160),512.0,255,100000,1000000)
		total += int(result.amount)
		if int(result.amount) == 0: break
	return total

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
