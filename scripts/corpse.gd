extends CharacterBody2D

static var weapon_pose_cursors: Dictionary = {}
const PIXEL_RAGDOLL := preload("res://scripts/effects/pixel_ragdoll_2d.gd")
const RAGDOLL_IMPACT := preload("res://scripts/combat/ragdoll_impact_resolver.gd")
const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")
const DETACHED_LIMB := preload("res://scripts/effects/detached_limb.gd")

var spin := 0.0
var simulated_rotation := 0.0
var wound_variant := 0
var wound_severity := 1.0
var death_style := "firearm"
var wound_offset := Vector2.ZERO
var clothing_absorption := 0.0 # Legacy renderer input; active renderer ignores it.
var attack_id := "pistol"
var attack_family := "pistol"
var wound_kind := "puncture"
var missing_modules: PackedStringArray = []
var dismemberment_state := "intact"
var corpse_pose_variant := 0
var death_twitch := 0.0
var ragdoll: PixelRagdoll2D
var overkill_window := 1.2
var overkill_hits := 0
var travel_distance := 0.0
var rig_kind := "human"
var victim_role := "enemy"
var ragdoll_impact_profile: Dictionary = {}
var root_speed_limit := 30.0

func _ready() -> void:
	queue_redraw()

func setup(facing: float, impact_direction := Vector2.ZERO, knockback := 0.0, blood_power := 1.0, style := "firearm", hit_zone := "torso", new_attack_id := "pistol", new_travel_distance := 0.0, new_rig_kind := "human", new_victim_role := "enemy", initial_pose := {}) -> void:
	rotation = snappedf(facing if initial_pose is Dictionary and not initial_pose.is_empty() else facing + randf_range(-0.35, 0.35), PI / 8.0)
	simulated_rotation = rotation
	wound_variant = randi_range(0, 2)
	wound_severity = clampf(blood_power, 0.7, 1.8)
	death_style = style
	attack_id = new_attack_id
	attack_family = _resolve_attack_family(attack_id)
	travel_distance = maxf(0.0, new_travel_distance)
	rig_kind = "hound" if new_rig_kind in ["hound", "dog"] else "human"
	victim_role = new_victim_role
	# All blood is resolved in the impact frame. Corpses are visual/AI state only
	# and never become passive emitters or cleanup objectives.
	# Legacy/non-projectile kill paths may only provide the authored death style.
	# Recover a high-energy firearm identity instead of silently drawing a pistol corpse.
	if attack_id == "pistol" and death_style == "firearm_gib":
		attack_id = "shotgun" if blood_power >= 2.0 else "lmg"
	elif attack_id == "pistol" and death_style == "firearm_torn" and blood_power < 0.95:
		attack_id = "smg"
	attack_family = _resolve_attack_family(attack_id)
	# Cycle instead of pure random selection so four consecutive kills with the
	# same weapon always demonstrate four different corpse silhouettes.
	var next_pose := (int(weapon_pose_cursors.get(attack_id, -1)) + 1) % 4
	weapon_pose_cursors[attack_id] = next_pose
	corpse_pose_variant = next_pose
	var violence := AttackCatalog.get_violence_profile(attack_id)
	wound_kind = str(violence.get("wound", "puncture"))
	_configure_dismemberment(hit_zone, clampi(int(violence.get("limbs", 0)), 0, 3))
	ragdoll_impact_profile = RAGDOLL_IMPACT.resolve(attack_id, travel_distance, hit_zone, rig_kind)
	# Enemy deaths happen while play continues, unlike the player's game-over beat.
	# Give them a longer, clearer articulation window so the shared ragdoll is
	# actually readable amid camera movement, blood, and ongoing combat.
	if victim_role == "enemy":
		ragdoll_impact_profile["presentation_scale"] = 1.55
		ragdoll_impact_profile["settle_bonus"] = 0.85
	# Root travel and internal articulation are deliberately separate. Limbs can
	# snap visibly while the body mass stays inside the encounter room.
	var authored_root_scale := 0.65
	var minimum_root_speed := 12.0
	root_speed_limit = 28.0
	match attack_family:
		"pistol": authored_root_scale = 0.82; minimum_root_speed = 18.0; root_speed_limit = 30.0
		"smg": authored_root_scale = 0.68; minimum_root_speed = 16.0; root_speed_limit = 28.0
		"lmg": authored_root_scale = 0.76; minimum_root_speed = 22.0; root_speed_limit = 42.0
		"shotgun": authored_root_scale = 0.62; minimum_root_speed = 26.0; root_speed_limit = 52.0
		"bat": authored_root_scale = 0.78; minimum_root_speed = 18.0; root_speed_limit = 38.0
		"execution": authored_root_scale = 0.60; minimum_root_speed = 10.0; root_speed_limit = 24.0
		"execution_knife": authored_root_scale = 0.45; minimum_root_speed = 8.0; root_speed_limit = 18.0
		"execution_bat": authored_root_scale = 0.72; minimum_root_speed = 16.0; root_speed_limit = 34.0
		"door": authored_root_scale = 0.75; minimum_root_speed = 18.0; root_speed_limit = 36.0
		"fist": authored_root_scale = 0.55; minimum_root_speed = 8.0; root_speed_limit = 16.0
		"knife": authored_root_scale = 0.42; minimum_root_speed = 6.0; root_speed_limit = 14.0
		"hound_bite": authored_root_scale = 0.58; minimum_root_speed = 10.0; root_speed_limit = 20.0
	var resolved_linear := clampf(maxf(knockback * 0.38, float(ragdoll_impact_profile.linear_force) * authored_root_scale), minimum_root_speed, root_speed_limit)
	velocity = impact_direction.normalized() * resolved_linear
	spin = randf_range(-1.4, 1.4) * float(ragdoll_impact_profile.spin_force) * clampf(resolved_linear / 28.0, 0.45, 1.3)
	if Settings.ragdoll_enabled:
		ragdoll = PIXEL_RAGDOLL.new() as PixelRagdoll2D
		add_child(ragdoll)
		ragdoll.wound_state = dismemberment_state
		ragdoll.wound_variant = wound_variant
		if victim_role == "player":
			ragdoll.cloth_color = Color("d8d8d8")
			ragdoll.accent_color = Color("777777")
		ragdoll.setup(impact_direction, float(ragdoll_impact_profile.limb_force), missing_modules, corpse_pose_variant, rig_kind, ragdoll_impact_profile, initial_pose)
	_spawn_detached_anatomy(impact_direction)
	death_twitch = 0.16
	wound_offset = Vector2(4, 0) if hit_zone == "head" else (Vector2(-2, 3) if hit_zone == "limb" else Vector2.ZERO)
	queue_redraw()

func _spawn_detached_anatomy(impact_direction: Vector2) -> void:
	if not Settings.gore_enabled or missing_modules.is_empty() or not is_inside_tree(): return
	var parent := get_parent() as Node2D
	# Some tests host corpses directly under a Node. Node2D is not required for
	# gameplay ownership, only for converting a transformed room's local space.
	var effect_parent := get_parent()
	if not is_instance_valid(effect_parent): return
	var limb_power := clampf(float(ragdoll_impact_profile.get("limb_force", 30.0)) / 72.0, 0.65, 1.55)
	for module in missing_modules:
		var kind := "head" if module == "head" else ("leg" if module.begins_with("leg") else "arm")
		var local_point := Vector2(5, 0) if kind == "head" else (Vector2(-5, 3) if kind == "leg" else Vector2(1, -3 if module == "arm_front" else 3))
		var spawn_position := to_global(local_point)
		var query := PhysicsRayQueryParameters2D.create(global_position, spawn_position, 4)
		var blocked := get_world_2d().direct_space_state.intersect_ray(query)
		if not blocked.is_empty(): spawn_position = blocked.position + blocked.normal * 2.5
		var limb := DETACHED_LIMB.new() as CharacterBody2D
		limb.position = parent.to_local(spawn_position) if is_instance_valid(parent) else spawn_position
		# Severed parts are anatomy, not renewable blood emitters. Every crimson
		# pixel still comes from the wound event's finite mass ledger.
		limb.setup(kind, impact_direction, limb_power, false)
		limb.visual_role = ragdoll.visual_role if is_instance_valid(ragdoll) else ("player" if victim_role == "player" else "gunner")
		RuntimeBudget.add_persistent("anatomy", limb, effect_parent)

func _configure_dismemberment(hit_zone: String, limb_count: int) -> void:
	missing_modules.clear()
	dismemberment_state = "intact"
	if not Settings.gore_enabled: return
	match attack_family:
		"pistol":
			if hit_zone == "head": dismemberment_state = "head_puncture"
			elif hit_zone == "limb": dismemberment_state = "limb_puncture"
			else: dismemberment_state = "shoulder_puncture" if wound_variant == 2 else "torso_puncture"
		"smg":
			dismemberment_state = "cluster_head" if hit_zone == "head" else ("side_torn" if wound_variant == 2 else ("cluster_low" if wound_variant == 1 else "cluster_torso"))
			if hit_zone == "head" and wound_variant == 2: missing_modules.append("head")
		"lmg":
			if hit_zone == "head":
				dismemberment_state = "head_destroyed"
				missing_modules.append("head")
			elif hit_zone == "limb":
				dismemberment_state = "limb_severed"
				missing_modules.append("arm_front" if wound_variant != 1 else "leg_back")
			else:
				dismemberment_state = "torso_split" if wound_variant == 2 else "torso_torn"
				missing_modules.append("arm_front")
		"shotgun":
			if hit_zone == "head":
				dismemberment_state = "head_destroyed"
				missing_modules.append("head")
			elif hit_zone == "limb":
				dismemberment_state = "multi_limb"
				missing_modules.append("arm_front")
				missing_modules.append("leg_back")
			elif wound_variant == 0:
				dismemberment_state = "upper_destroyed"
				missing_modules.append("head")
				missing_modules.append("arm_front")
			elif wound_variant == 1:
				dismemberment_state = "bisected"
				missing_modules.append("leg_back")
			else:
				dismemberment_state = "torso_cavity"
				missing_modules.append("arm_back")
		_:
			var requested := limb_count
			if requested > 0: missing_modules.append("arm_front")
			if requested > 1: missing_modules.append("leg_back")
			if requested > 2: missing_modules.append("arm_back")
	# Preserve violence-profile support for future weapons without making light
	# firearms randomly erase more anatomy than their authored state permits.
	if attack_family not in ["pistol", "smg", "lmg", "shotgun"]:
		return

func _resolve_attack_family(source_id: String) -> String:
	if source_id in ["pistol", "smg", "lmg", "shotgun"]: return source_id
	if not WeaponPlatformCatalog.has_weapon(source_id): return source_id
	var weapon_class := str(WeaponPlatformCatalog.get_platform(source_id).get("class", "handgun"))
	if weapon_class == "handgun": return "pistol"
	if weapon_class in ["pdw", "smg"]: return "smg"
	if weapon_class == "shotgun": return "shotgun"
	return "lmg"

func _physics_process(delta: float) -> void:
	if overkill_window > 0.0:
		overkill_window = maxf(0.0, overkill_window - delta)
		if overkill_window <= 0.0: collision_layer = 0
	if death_twitch > 0.0:
		death_twitch -= delta
		simulated_rotation += sin(death_twitch * 90.0) * 0.012
		rotation = snappedf(simulated_rotation, PI / 8.0)
		queue_redraw()
	if velocity.length_squared() < 0.1:
		velocity = Vector2.ZERO
		# The same process owns the overkill/collision timeout. Sleeping the root
		# immediately used to leave a stationary corpse on its combat collision
		# layer forever and kept its overkill window permanently open.
		if overkill_window <= 0.0 and death_twitch <= 0.0:
			set_physics_process(false)
		return
	velocity = velocity.limit_length(root_speed_limit)
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		var impact_velocity := velocity
		var collider := collision.get_collider()
		if collider is Node and collider.is_in_group("destructible_prop"):
			if collider.has_method("receive_corpse_impact"):
				collider.receive_corpse_impact(impact_velocity.normalized(), clampf(impact_velocity.length() / 55.0, 0.5, 1.8))
			elif collider.has_method("take_damage") and impact_velocity.length() >= 55.0:
				collider.take_damage(1, global_position - impact_velocity.normalized())
		if impact_velocity.length() >= 38.0:
			Events.publish_combat_noise(collision.get_position(), clampf(impact_velocity.length() * 1.2, 48.0, 110.0), "corpse_impact")
		# A corpse should thud and settle at a wall, not retain enough tangential
		# energy to squeeze around thin corners or disabled door leaves.
		velocity = velocity.slide(collision.get_normal()).limit_length(18.0) * 0.12
		spin *= 0.22
	velocity = velocity.move_toward(Vector2.ZERO, 130.0 * delta)
	# Accumulate continuous angular momentum separately from the authored visual
	# frames. Quantizing `rotation + spin * delta` directly discarded virtually
	# every pistol/SMG impulse before it could cross a 22.5-degree frame.
	simulated_rotation += spin * delta
	rotation = snappedf(simulated_rotation, PI / 8.0)
	spin = move_toward(spin, 0.0, 7.0 * delta)

func can_receive_overkill() -> bool:
	return overkill_window > 0.0 and overkill_hits < 1

func receive_projectile_overkill(direction: Vector2, hit_position: Vector2, weapon_id: String, impact_speed: float) -> bool:
	if not can_receive_overkill(): return false
	overkill_hits += 1
	wound_severity = minf(2.2, wound_severity + 0.16)
	var followup := RAGDOLL_IMPACT.resolve(weapon_id, travel_distance, "torso", rig_kind)
	if is_instance_valid(ragdoll):
		ragdoll.apply_impact(direction, float(followup.limb_force) * 0.46, to_local(hit_position))
	velocity = (velocity + direction.normalized() * float(followup.linear_force) * 0.16).limit_length(root_speed_limit)
	spin += randf_range(-0.9, 0.9) * float(followup.spin_force)
	queue_redraw()
	return true

func _draw_compact_pixel_corpse() -> void:
	# Original prototype language: a tiny readable body assembled from a handful
	# of hard-edged blocks. Damage changes missing blocks, not overall canvas size.
	var ink := Color("17141b")
	var cloth := Color("d8e2df")
	var cloth_shadow := Color("666666")
	var skin := NeonPalette.SKIN
	var wound_gray := Color("4b4b4b")
	var tissue := NeonPalette.TISSUE
	var pose_y := int([-1, -2, 1, 2][corpse_pose_variant])
	var paint := func(area: Rect2, color: Color, seed: int, pattern: StringName = &"fabric") -> void:
		PIXEL_PAINTER.material_rect(self, area, color, color.lightened(0.13), color.darkened(0.18), seed, pattern)
	# Legs remain separate pixels so the silhouette reads as a fallen person.
	if not missing_modules.has("leg_back"):
		paint.call(Rect2(-8, pose_y - 3, 5, 2), ink, 3, &"fabric")
	paint.call(Rect2(-8, pose_y + 2, 5, 2), ink, 5, &"fabric")
	# Compact torso, capped at nine pixels instead of the later 32–48 px art.
	if dismemberment_state in ["bisected", "torso_split"]:
		paint.call(Rect2(-3, pose_y - 3, 3, 6), cloth, 7)
		paint.call(Rect2(2, pose_y - 3, 3, 6), cloth, 11)
		paint.call(Rect2(0, pose_y - 2, 2, 4), tissue, 13, &"grain")
	elif dismemberment_state in ["upper_destroyed", "torso_torn", "torso_cavity", "side_torn"]:
		paint.call(Rect2(-3, pose_y - 3, 5, 6), cloth_shadow, 17)
		paint.call(Rect2(2, pose_y - 2, 3, 4), wound_gray, 19, &"grain")
		paint.call(Rect2(2, pose_y - 1, 2, 2), tissue, 23, &"grain")
	else:
		paint.call(Rect2(-3, pose_y - 3, 8, 6), ink, 29, &"grain")
		paint.call(Rect2(-2, pose_y - 2, 6, 4), cloth, 31)
		paint.call(Rect2(-1, pose_y - 1, 4, 2), cloth_shadow, 37)
	if not missing_modules.has("arm_front"):
		paint.call(Rect2(-1, pose_y - 5, 6, 2), ink, 41, &"fabric")
	if not missing_modules.has("arm_back"):
		paint.call(Rect2(-1, pose_y + 3, 6, 2), ink, 43, &"fabric")
	if not missing_modules.has("head"):
		paint.call(Rect2(5, pose_y - 2, 4, 4), ink, 47, &"grain")
		paint.call(Rect2(6, pose_y - 1, 2, 2), skin, 53, &"grain")
	else:
		paint.call(Rect2(5, pose_y - 2, 3, 4), wound_gray, 59, &"grain")
		paint.call(Rect2(6, pose_y - 1, 1, 2), tissue, 61, &"grain")
		# Detached head remains beside the body instead of disappearing into blood.
		paint.call(Rect2(11, pose_y - 6, 4, 4), ink, 67, &"grain")
		paint.call(Rect2(12, pose_y - 5, 2, 2), skin, 71, &"grain")
		paint.call(Rect2(11, pose_y - 4, 2, 2), wound_gray, 73, &"grain")
	if missing_modules.has("arm_front"):
		paint.call(Rect2(1, pose_y - 10, 7, 2), ink, 79)
		paint.call(Rect2(6, pose_y - 10, 2, 2), tissue, 83, &"grain")
	if missing_modules.has("arm_back"):
		paint.call(Rect2(0, pose_y + 8, 7, 2), ink, 89)
		paint.call(Rect2(5, pose_y + 8, 2, 2), tissue, 97, &"grain")
	if missing_modules.has("leg_back"):
		paint.call(Rect2(-12, pose_y + 7, 8, 3), ink, 101)
		paint.call(Rect2(-5, pose_y + 7, 2, 3), tissue, 103, &"grain")
	# One small wound mark keeps firearm identity without burying the silhouette.
	if dismemberment_state != "intact":
		PIXEL_PAINTER.material_circle(self, (wound_offset * 0.45).round(), 1, wound_gray, wound_gray.lightened(0.16), wound_gray.darkened(0.24), 107)

func _draw_body_bag() -> void:
	# A compact human-scale 26x9 px zippered bag. Every visible mark is a native one-pixel
	# cell: the tapered ends prevent the former storage-box silhouette, while the
	# zipper, compression straps and handles explain the object at a glance.
	var ink := Color("0e1115")
	var fabric := Color("242b31")
	var highlight := Color("3b4650")
	var shadow := Color("171c21")
	# Main textile mass plus tapered head/foot sections.
	PIXEL_PAINTER.material_rect(self, Rect2(-11, -3, 22, 7), fabric, highlight, shadow, 109, &"fabric")
	PIXEL_PAINTER.material_rect(self, Rect2(-12, -2, 24, 5), fabric, highlight, shadow, 113, &"fabric")
	PIXEL_PAINTER.line(self, Vector2(-10, -4), Vector2(10, -4), ink)
	PIXEL_PAINTER.line(self, Vector2(-10, 4), Vector2(10, 4), ink)
	PIXEL_PAINTER.line(self, Vector2(-12, -3), Vector2(-11, -3), ink)
	PIXEL_PAINTER.line(self, Vector2(11, -3), Vector2(12, -3), ink)
	PIXEL_PAINTER.line(self, Vector2(-12, 3), Vector2(-11, 3), ink)
	PIXEL_PAINTER.line(self, Vector2(11, 3), Vector2(12, 3), ink)
	PIXEL_PAINTER.line(self, Vector2(-12, -2), Vector2(-12, 2), ink)
	PIXEL_PAINTER.line(self, Vector2(12, -2), Vector2(12, 2), ink)
	PIXEL_PAINTER.pixel(self, Vector2(-13, 0), ink)
	PIXEL_PAINTER.pixel(self, Vector2(13, 0), ink)
	# Long central zipper with a bright pull tab toward the head end.
	PIXEL_PAINTER.line(self, Vector2(-9, 0), Vector2(9, 0), Color("71808c"))
	for x in range(-8, 10, 3): PIXEL_PAINTER.pixel(self, Vector2(x, 0), Color("a5b1b9"))
	PIXEL_PAINTER.line(self, Vector2(9, -1), Vector2(10, -1), Color("d8e2df"))
	# Two darker compression straps wrap across the body mass.
	for strap_x in [-4, 4]:
		PIXEL_PAINTER.line(self, Vector2(strap_x, -3), Vector2(strap_x, 3), Color("11161a"))
		PIXEL_PAINTER.pixel(self, Vector2(strap_x + 1, 2), Color("75838b"))
	# Four flat carrying handles sit outside the textile edge.
	for handle_x in [-7, 5]:
		PIXEL_PAINTER.line(self, Vector2(handle_x, -5), Vector2(handle_x + 2, -5), Color("171c21"))
		PIXEL_PAINTER.line(self, Vector2(handle_x, 5), Vector2(handle_x + 2, 5), Color("171c21"))
	# Small evidence tag; rectangular and tied to the zipper rather than a large dot.
	PIXEL_PAINTER.material_rect(self, Rect2(7, 1, 3, 2), Color("d8d0c5"), Color("fff8e8"), Color("968f89"), 127, &"grain")

func _draw() -> void:
	# Corpse art shares the living actor's compact 16–20 px body core while
	# retaining a 32 px effect canvas for limbs, wounds and bagging UI.
	# The previous 0.45 scale reduced severed edges to sub-pixel noise. This is
	# still compact beside a living actor but leaves 2–4 physical pixels for each
	# missing module, cavity, and detached piece at the final viewport scale.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_instance_valid(ragdoll): return
	_draw_compact_pixel_corpse()
	return
	# Authored corpse sprites now carry the human silhouette and major trauma.
	# Runtime drawing is restricted to changing blood saturation and packaging UI.
	if has_node("BodySprite"):
		var authored_blood := Color(0.62, 0.0, 0.08, 0.78)
		var authored_radius := lerpf(1.0, 4.5, clothing_absorption) * wound_severity
		draw_circle(wound_offset, authored_radius, authored_blood)
		if dismemberment_state in ["head_puncture", "torso_puncture", "shoulder_puncture", "limb_puncture", "cluster_torso", "cluster_low"]:
			draw_circle(wound_offset, 1.6 + wound_variant * 0.5, NeonPalette.BLOOD_DARK)
		return
	# Four universal fall poses are layered under every weapon-specific wound.
	# This keeps repeated kills with the same gun from producing cloned bodies.
	var leg_back_pos := [Vector2(-13, -6), Vector2(-9, -12), Vector2(-18, -9), Vector2(-17, -2)][corpse_pose_variant] as Vector2
	var leg_front_pos := [Vector2(-13, 2), Vector2(-14, -7), Vector2(-18, 6), Vector2(-9, 9)][corpse_pose_variant] as Vector2
	var arm_front_pos := [Vector2(-4, -8), Vector2(1, -13), Vector2(-3, -14), Vector2(-9, -12)][corpse_pose_variant] as Vector2
	var arm_back_pos := [Vector2(-4, 5), Vector2(-8, -12), Vector2(-3, 11), Vector2(2, 8)][corpse_pose_variant] as Vector2
	var head_pos := [Vector2(10, 0), Vector2(6, -8), Vector2(10, 0), Vector2(6, 7)][corpse_pose_variant] as Vector2
	# Weapon-specific anatomy: low-calibre shots preserve the silhouette, while
	# LMG and shotgun deaths visibly remove or split the body mass that produced
	# the matching gore burst.
	if dismemberment_state == "bisected":
		draw_rect(Rect2(-10, -5, 7, 10), NeonPalette.INK)
		draw_rect(Rect2(0, -5, 8, 10), NeonPalette.INK)
		draw_rect(Rect2(-3, -4, 4, 8), NeonPalette.BLOOD_DARK)
		draw_rect(Rect2(-2, -2, 3, 4), NeonPalette.TISSUE)
	elif dismemberment_state == "upper_destroyed":
		draw_rect(Rect2(-10, -5, 9, 10), NeonPalette.INK)
		draw_rect(Rect2(-8, -4, 7, 8), Color("84275c"))
		draw_polygon(PackedVector2Array([Vector2(-1, -5), Vector2(8, -3), Vector2(5, 5), Vector2(-1, 4)]), PackedColorArray([NeonPalette.BLOOD_DARK]))
		draw_circle(Vector2(3, 0), 3.0, NeonPalette.TISSUE)
	elif dismemberment_state in ["torso_torn", "torso_split", "torso_cavity", "side_torn"]:
		draw_rect(Rect2(-9, -5, 17, 10), NeonPalette.INK)
		draw_rect(Rect2(-7, -4, 7, 8), Color("84275c"))
		draw_polygon(PackedVector2Array([Vector2(0, -4), Vector2(8, -2), Vector2(5, 4), Vector2(0, 3)]), PackedColorArray([NeonPalette.BLOOD_DARK]))
		draw_rect(Rect2(0, -2, 5, 4), NeonPalette.TISSUE)
	elif corpse_pose_variant == 1:
		# Curled side fall: bent diagonal torso and head tucked toward both arms.
		draw_polygon(PackedVector2Array([Vector2(-9, -4), Vector2(0, -7), Vector2(7, -3), Vector2(4, 5), Vector2(-6, 4)]), PackedColorArray([NeonPalette.INK]))
		draw_polygon(PackedVector2Array([Vector2(-7, -3), Vector2(0, -5), Vector2(5, -2), Vector2(3, 3), Vector2(-5, 3)]), PackedColorArray([Color("84275c")]))
	elif corpse_pose_variant == 3:
		# Twisted fall: the chest and pelvis visibly disagree on orientation.
		draw_polygon(PackedVector2Array([Vector2(-10, -5), Vector2(1, -6), Vector2(8, 1), Vector2(4, 6), Vector2(-7, 4)]), PackedColorArray([NeonPalette.INK]))
		draw_polygon(PackedVector2Array([Vector2(-7, -3), Vector2(0, -4), Vector2(6, 1), Vector2(3, 4), Vector2(-6, 3)]), PackedColorArray([Color("84275c")]))
	else:
		draw_rect(Rect2(-9, -5, 17, 10), NeonPalette.INK)
		draw_rect(Rect2(-7, -4, 14, 8), Color("84275c"))
		draw_rect(Rect2(-5, -3, 8, 2), Color("c33b79"))
	if not missing_modules.has("head"):
		draw_circle(head_pos, 4.0, NeonPalette.INK)
		draw_rect(Rect2(head_pos + Vector2(-2, -3), Vector2(4, 6)), NeonPalette.SKIN)
	if not missing_modules.has("leg_back"): draw_rect(Rect2(leg_back_pos, Vector2(6, 4)), NeonPalette.INK)
	draw_rect(Rect2(leg_front_pos, Vector2(6, 4)), NeonPalette.INK)
	if not missing_modules.has("arm_front"):
		draw_rect(Rect2(arm_front_pos, Vector2(11, 3)), NeonPalette.INK)
		draw_rect(Rect2(arm_front_pos + Vector2(2, 1), Vector2(8, 1)), Color("b43b72"))
	if not missing_modules.has("arm_back"):
		draw_rect(Rect2(arm_back_pos, Vector2(11, 3)), NeonPalette.INK)
		draw_rect(Rect2(arm_back_pos + Vector2(2, 1), Vector2(8, 1)), Color("b43b72"))
	var blood := NeonPalette.BLOOD_DARK
	var tissue := NeonPalette.TISSUE
	var wound_rim := Color("ff5577")
	var cavity := Color("26030d")
	var absorbed_color := Color(0.46, 0.01, 0.08, 0.72)
	var absorbed_radius := lerpf(1.0, 7.0, clothing_absorption) * wound_severity
	draw_circle(wound_offset, absorbed_radius, absorbed_color)
	if missing_modules.has("head"):
		draw_rect(Rect2(head_pos + Vector2(-3, -4), Vector2(7, 8)), blood)
		draw_rect(Rect2(head_pos + Vector2(-1, -2), Vector2(3, 4)), tissue)
	if missing_modules.has("arm_front"): draw_circle(Vector2(5, -6), 2.2, tissue)
	if missing_modules.has("arm_back"): draw_circle(Vector2(5, 6), 2.2, tissue)
	if missing_modules.has("leg_back"): draw_circle(Vector2(-9, -4), 2.3, tissue)
	# Readability pass: persistent blood remains below the corpse, while bright
	# one-pixel wound rims and dark cavities preserve the anatomy at a glance.
	if dismemberment_state == "bisected":
		draw_line(Vector2(-3, -4), Vector2(-3, 4), cavity, 3.0)
		draw_line(Vector2(-2, -4), Vector2(-2, 4), wound_rim, 1.2)
		draw_line(Vector2(0, -4), Vector2(0, 4), wound_rim, 1.2)
		draw_rect(Rect2(-2, -1, 3, 2), NeonPalette.BONE)
	elif dismemberment_state == "upper_destroyed":
		draw_line(Vector2(-1, -4), Vector2(-1, 4), wound_rim, 1.5)
		draw_circle(Vector2(3, 0), 2.0, cavity)
		draw_rect(Rect2(1, -1, 4, 2), tissue)
	elif dismemberment_state in ["torso_torn", "torso_split", "torso_cavity", "side_torn"]:
		draw_arc(Vector2(3, 0), 4.0, -PI * 0.5, PI * 0.5, 7, wound_rim, 1.4)
		draw_circle(Vector2(3, 0), 2.2, cavity)
		draw_rect(Rect2(2, -1, 3, 2), tissue)
		if dismemberment_state == "torso_split": draw_line(Vector2(-3, -4), Vector2(4, 4), wound_rim, 1.5)
	elif dismemberment_state == "shoulder_puncture":
		draw_circle(Vector2(3, -3), 2.0, blood)
		draw_rect(Rect2(3, -4, 2, 2), tissue)
	elif dismemberment_state == "limb_puncture":
		draw_circle(arm_front_pos + Vector2(5, 1), 1.8, blood)
	elif dismemberment_state == "cluster_low":
		draw_circle(Vector2(-4, 2), 2.2, blood)
		draw_circle(Vector2(-1, 3), 1.5, wound_rim)
	if dismemberment_state == "multi_limb":
		# Two clearly detached modules with a floor gap between each piece and torso.
		draw_rect(Rect2(13, -12, 9, 5), NeonPalette.INK)
		draw_rect(Rect2(14, -11, 7, 3), Color("6f2354"))
		draw_circle(Vector2(14, -9.5), 1.8, tissue)
		draw_rect(Rect2(-22, -12, 10, 5), NeonPalette.INK)
		draw_rect(Rect2(-21, -11, 8, 3), Color("6f2354"))
		draw_circle(Vector2(-13, -9.5), 1.8, tissue)
	elif dismemberment_state == "limb_severed":
		draw_rect(Rect2(14, -11, 10, 5), NeonPalette.INK)
		draw_rect(Rect2(15, -10, 8, 3), Color("6f2354"))
		draw_circle(Vector2(15, -8.5), 1.8, tissue)
	elif dismemberment_state == "head_destroyed":
		draw_circle(Vector2(12, 0), 6.2, cavity)
		draw_circle(Vector2(12, 0), 5.5, blood)
		draw_arc(Vector2(10, 0), 4.2, -PI * 0.5, PI * 0.5, 8, wound_rim, 1.4)
		draw_rect(Rect2(9, -3, 4, 2), tissue)
		draw_rect(Rect2(13, 1, 3, 2), NeonPalette.BONE)
		# Separate skull/tissue fragments make the missing head readable even over a pool.
		draw_rect(Rect2(19, -6, 4, 3), NeonPalette.INK)
		draw_rect(Rect2(20, -5, 2, 2), NeonPalette.BONE)
		draw_circle(Vector2(19, 5), 2.0, tissue)
	if death_style == "slash":
		draw_line(Vector2(-7, -5), Vector2(8, 5), NeonPalette.BLOOD_FRESH, 3.0)
		draw_line(Vector2(-5, -5), Vector2(9, 4), tissue, 1.0)
	elif death_style == "blunt":
		draw_circle(Vector2(10, 0), 5.0, blood)
		draw_rect(Rect2(7, -3, 4, 3), tissue)
		draw_rect(Rect2(11, 1, 3, 2), NeonPalette.BONE)
	elif death_style == "firearm_torn":
		draw_rect(Rect2(-3, -5, 9, 10), blood)
		draw_rect(Rect2(-1, -3, 4, 4), tissue)
		draw_rect(Rect2(4, 1, 3, 2), NeonPalette.BONE)
	elif death_style == "firearm_gib":
		draw_rect(Rect2(-8, -5, 10, 10), blood)
		draw_rect(Rect2(1, -3, 5, 4), tissue)
		draw_rect(Rect2(5, 2, 4, 2), NeonPalette.BONE)
		draw_line(Vector2(-10, 6), Vector2(6, -6), blood, 3.0)
	elif death_style == "execution_blade":
		draw_line(Vector2(-9, -6), Vector2(10, 6), NeonPalette.MAGENTA, 4.0)
		draw_circle(Vector2(10, 0), 4.0, blood)
	elif death_style in ["execution", "execution_blunt"]:
		draw_circle(Vector2(10, 0), 6.0, blood)
		draw_rect(Rect2(6, -4, 6, 4), tissue)
		draw_rect(Rect2(5, 1, 3, 1), Color("f8d8cf"))
		draw_rect(Rect2(-1, -1, 3, 2), blood)
	elif wound_variant == 0:
		draw_circle(Vector2(0, 0), 1.4 * wound_severity, blood)
		draw_rect(Rect2(-1, -1, 3, 1), tissue)
	elif wound_variant == 1:
		draw_circle(Vector2(4, 0), 2.0, blood)
		draw_rect(Rect2(4, -1, 2, 1), tissue)
	else:
		draw_rect(Rect2(-3, -2, 2 + wound_severity, 4), blood)
		draw_rect(Rect2(-2, 0, 3, 1), tissue)
