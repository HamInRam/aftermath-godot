extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
var failures := 0
var contacts: Array[DamageContext] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.position = Vector2(120, 90)
	enemy.set_physics_process(false)
	enemy.state = enemy.State.CHASE
	_validate_hit_zones(enemy)
	await _validate_projectile_contact(enemy)
	await _validate_stagger_impulse(enemy)
	enemy.queue_free()
	await get_tree().process_frame
	if failures == 0: print("ballistic contact regression: PASS // eight-way tissue classification, preserved entry contacts and weapon impulses")
	get_tree().quit(failures)

func _validate_hit_zones(enemy: Node2D) -> void:
	for sector in 8:
		enemy.rotation = float(sector) * PI / 4.0
		# Actor rotation and incoming direction are independent. Every centred
		# trajectory must traverse torso, including rear and side entry contacts.
		for approach in 8:
			var local_direction := Vector2.RIGHT.rotated(float(approach) * PI / 4.0)
			var entry := enemy.to_global(-local_direction * 6.0)
			var direction := local_direction.rotated(enemy.global_rotation)
			_expect(enemy.classify_ballistic_hit(entry, direction) == "torso", "centre-mass shot must hit torso for actor %d / approach %d" % [sector, approach])
		_expect(enemy.classify_ballistic_hit(enemy.to_global(Vector2(3.7, -6)), Vector2.DOWN.rotated(enemy.global_rotation)) == "head", "aiming through the forward crown must retain the head weak point in sector %d" % sector)
		_expect(enemy.classify_ballistic_hit(enemy.to_global(Vector2(-6, 4.2)), Vector2.RIGHT.rotated(enemy.global_rotation)) == "limb", "a shoulder-edge graze must remain a limb hit in sector %d" % sector)
		_expect(enemy.classify_ballistic_hit(enemy.to_global(Vector2(-4.4, -6)), Vector2.DOWN.rotated(enemy.global_rotation)) == "limb", "a rear-edge graze must remain a limb hit in sector %d" % sector)
		_expect(enemy.classify_ballistic_hit(enemy.to_global(Vector2(-6, 0)), Vector2.LEFT.rotated(enemy.global_rotation)) == "limb", "classification must not sample tissue behind an outgoing ray")
		_expect(enemy.classify_hit_zone(enemy.to_global(Vector2(4, 0))) == "head", "legacy single-point head classification must remain compatible")
		_expect(enemy.classify_hit_zone(enemy.to_global(Vector2.ZERO)) == "torso", "legacy single-point torso classification must remain compatible")
		_expect(enemy.classify_hit_zone(enemy.to_global(Vector2(-5, 0))) == "limb", "legacy single-point rear classification must remain compatible")
		_expect(enemy.classify_ballistic_hit(enemy.to_global(Vector2(4, 0)), Vector2.ZERO) == "head", "zero-direction callers must fall back to point classification")

func _validate_projectile_contact(enemy: Node2D) -> void:
	var data := AttackCatalog.get_gun_data("mossberg_590a1")
	for sector in 8:
		enemy.rotation = float(sector) * PI / 4.0
		enemy.heal_full()
		enemy.state = enemy.State.CHASE
		contacts.clear()
		var bullet = BULLET_SCENE.instantiate()
		var origin := enemy.to_global(Vector2(-16, 0))
		var direction := Vector2.RIGHT.rotated(enemy.global_rotation)
		bullet.position = origin
		bullet.setup(direction, false, data.damage, data.weapon_id, origin, data.bullet_speed, null, data.penetration_power, data.property_damage, data.damage_falloff_start, data.damage_falloff_end, data.minimum_damage_ratio)
		bullet.damage_impact.connect(func(context: DamageContext) -> void: contacts.append(context))
		add_child(bullet)
		bullet.set_physics_process(false)
		for frame in 2: await get_tree().physics_frame
		bullet._physics_process(0.04)
		_expect(contacts.size() == 1, "real projectile must resolve one contact in sector %d" % sector)
		if not contacts.is_empty():
			var context := contacts[0]
			_expect(context.hit_zone == "torso", "Bullet must use the trajectory classifier rather than the rear entry edge")
			_expect(context.hit_position.is_equal_approx(bullet.global_position), "blood context must retain the actual world-space projectile contact")
			_expect(context.hit_position.distance_to(enemy.global_position) >= 4.9, "blood must stay at the body entry instead of moving to its interior tissue sample")
			_expect(context.source_position.is_equal_approx(origin) and context.direction.is_equal_approx(direction), "contact classification may not alter projectile origin or direction")
			_expect(enemy.hp == enemy.max_hp - data.damage, "a close centre-mass pellet must apply full torso damage")
		if is_instance_valid(bullet): bullet.queue_free()
		await get_tree().process_frame

func _validate_stagger_impulse(enemy: Node2D) -> void:
	enemy.rotation = 0.0
	enemy.heal_full()
	enemy.state = enemy.State.CHASE
	enemy.lifecycle_rig.force_active()
	enemy.apply_lifecycle_impact(Vector2.RIGHT, 34.0, "torso")
	var before := {}
	for joint in enemy.lifecycle_rig.points:
		before[joint] = enemy.lifecycle_rig.points[joint].previous
	enemy.apply_ballistic_hit({"health_damage": 18, "lethal": false, "hit_zone": "torso"}, enemy.global_position - Vector2(20, 0))
	for joint in before:
		_expect((enemy.lifecycle_rig.points[joint].previous as Vector2).is_equal_approx(before[joint]), "AI stagger must preserve the same-frame weapon impulse for " + str(joint))
	_expect(enemy.state == enemy.State.STAGGERED and is_equal_approx(enemy.stagger_time, 0.09), "ballistic hits must still enter their normal AI stagger")
	_expect(enemy.velocity.is_equal_approx(Vector2(62, 0)), "ballistic stagger must retain its authored root velocity")
	await get_tree().physics_frame
	enemy.lifecycle_rig.force_active()
	var chest_before: Vector2 = enemy.lifecycle_rig.points.chest.previous
	enemy.apply_stagger(Vector2.DOWN, 0.24)
	_expect(not (enemy.lifecycle_rig.points.chest.previous as Vector2).is_equal_approx(chest_before), "ordinary stagger in a later frame must still displace the rig")
	_expect(enemy.lifecycle_rig.mode == enemy.lifecycle_rig.Mode.HIT_REACT, "ordinary stagger must retain its hit reaction mode")
	_expect(enemy.velocity.is_equal_approx(Vector2(0, 62)) and is_equal_approx(enemy.stagger_time, 0.24), "ordinary stagger must retain its root speed and duration")

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
