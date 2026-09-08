extends Node2D

## Uses production Player/Gun, production Bullet swept collision, and production
## Enemy/Actor health and armour. No direct take_damage or theoretical hit sums.
const PLAYER := preload("res://scenes/player.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")
const BULLET := preload("res://scenes/bullet.tscn")
const DISTANCES := [20.0, 45.0, 70.0, 110.0]
const FACINGS := {"front": PI, "back": 0.0, "side": PI * 0.5}
var failures := 0
var reports: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var old_save := Progression.save_path
	Progression.save_path = "/tmp/aftermath_shotgun_combat_%d.json" % OS.get_process_id()
	for weapon_id in ["mossberg_590a1", "shotgun"]:
		var data := AttackCatalog.get_gun_data(weapon_id)
		_expect(data.weapon_id == "mossberg_590a1", "legacy shotgun alias must resolve to first Mossberg platform")
		_expect(data.pellet_count == 9, "Mossberg must emit nine physical pellets per shell")
		for distance in DISTANCES:
			for facing in FACINGS:
				# A high-HP instance measures every pellet. A normal instance checks
				# actual kill behavior; dying intentionally removes its collider.
				var full := await _fire_at_enemy(weapon_id, distance, facing, true)
				var combat := await _fire_at_enemy(weapon_id, distance, facing, false)
				var row := {"weapon": weapon_id, "distance": distance, "facing": facing,
					"pellets": full.emitted, "hits": full.hits, "damage": full.damage,
					"zones": full.zones, "travel": full.travel, "muzzle": full.muzzle,
					"normal_hp": combat.initial_hp, "remaining_hp": combat.hp,
					"kill": combat.dead, "hits_to_kill": combat.hits}
				reports.append(row)
				print("SHOTGUN_REAL_SHOT ", JSON.stringify(row))
				_expect(full.emitted == data.pellet_count and combat.emitted == data.pellet_count, "one shell must create all physical pellets")
				_expect(full.shells_spent == 1 and combat.shells_spent == 1, "one trigger pull must spend exactly one shell")
				_expect(full.hits > 0 and full.hits <= full.emitted, "center-aimed shotgun must hit without duplicate damage per pellet")
				_expect(full.damage == full.initial_hp - full.hp, "real pellet health events must match real enemy health loss")
				_expect(not full.stealth and not combat.stealth, "combat fixture must exclude unaware instant-kill bonus")
				if distance <= 45.0:
					_expect(full.zones == {"torso": 9}, "a centred close blast must hit torso, not turn into all-head/all-limb based on facing")
				if distance <= 70.0:
					_expect(combat.dead, "Mossberg centred blast must defeat a normal aware enemy through its close-combat range")
				else:
					_expect(full.hits < full.emitted and combat.dead, "arcade Mossberg must retain dispersion but defeat a centred normal enemy at room range")
	var variant_size := DISTANCES.size() * FACINGS.size()
	for index in variant_size:
		var canonical: Dictionary = reports[index]
		var alias: Dictionary = reports[index + variant_size]
		_expect(canonical.damage == alias.damage and canonical.hits == alias.hits and canonical.kill == alias.kill,
			"legacy shotgun and named Mossberg must have identical actual bullet/health behavior")
	# Additional near-contact geometry and armour samples supplement the required
	# four-distance matrix without substituting resolver-only calculations.
	var far := await _fire_at_enemy("mossberg_590a1", 220.0, "front", true)
	_expect(far.hits < 5 and far.damage < 75, "far range must still reward a rifle rather than shotgun sniping")
	for distance in [11.0, 14.0, 17.0]:
		for facing in FACINGS:
			var close := await _fire_at_enemy("mossberg_590a1", distance, facing, true)
			print("SHOTGUN_CONTACT ", JSON.stringify(close))
			_expect(close.hits == 9, "barrel touching/inside/beyond enemy must not lose any pellets: %spx %s" % [distance, facing])
			_expect(close.hp < close.initial_hp, "touching shotgun must deal real damage")
			_expect(close.muzzle == 19.0, "close-hit correction must not shift visible muzzle art")
	for sector in range(8):
		var aimed := await _fire_at_enemy("mossberg_590a1", 11.0, "back", true, "gunner", false, float(sector) * PI / 4.0)
		_expect(aimed.hits == 9, "near-contact clearance must work at every world-space shooting angle")
	var blocked := await _fire_at_enemy("mossberg_590a1", 45.0, "front", true, "gunner", true)
	_expect(blocked.emitted == 0 and blocked.shells_spent == 0 and blocked.hits == 0,
		"existing wall-in-barrel guard must reject firing without ammo loss or hitting through wall")
	for facing in FACINGS:
		var heavy := await _fire_at_enemy("mossberg_590a1", 45.0, facing, false, "heavy")
		print("SHOTGUN_HEAVY ", JSON.stringify(heavy))
		_expect(heavy.dead and heavy.absorbed > 0.0, "close shotgun must defeat heavy while genuinely applying its torso armour")
	# Let optional death-particle lifetime callbacks dispose their temporary
	# effects; outstanding timers otherwise produce misleading teardown leaks.
	await get_tree().create_timer(1.0).timeout
	Progression.save_path = old_save
	if failures == 0: print("SHOTGUN_COMBAT_REGRESSION_OK")
	get_tree().quit(failures)

func _fire_at_enemy(weapon_id: String, distance: float, facing: String, measure_all: bool, archetype := "gunner", wall_in_barrel := false, aim_angle := 0.0) -> Dictionary:
	var arena := Node2D.new()
	add_child(arena)
	var player = PLAYER.instantiate()
	player.position = Vector2(128.0, 128.0)
	arena.add_child(player)
	# Freeze controller/visual updates, not PhysicsServer collision geometry.
	# This isolates impact damage from AI movement and later wound attrition.
	_stop_updates(player)
	player.rotation = aim_angle
	var aim_direction := Vector2.RIGHT.rotated(aim_angle)
	player.upper_body.position = Vector2.ZERO
	player.upper_body.rotation = 0.0
	player.gun.position = Vector2.ZERO
	player.gun.rotation = 0.0
	var data := AttackCatalog.get_gun_data(weapon_id)
	player.gun.set_gun_data(data, true)
	player.gun.set_weapon_ammo(data.weapon_id, data.ammo_capacity)
	player.gun.fire_interval_variance = 0.0
	var enemy = ENEMY.instantiate()
	enemy.position = player.position + aim_direction * distance
	arena.add_child(enemy)
	enemy.configure_combat(archetype)
	_stop_updates(enemy)
	enemy.rotation = float(FACINGS[facing]) + aim_angle
	enemy.alert_level = enemy.AlertLevel.ALERT
	enemy.state = enemy.State.CHASE
	if measure_all: enemy.set_max_health(1000, true)
	if wall_in_barrel:
		var wall := StaticBody2D.new()
		wall.collision_layer = 4
		wall.collision_mask = 0
		wall.position = player.position + Vector2(11.0, 0.0)
		var collision := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(2.0, 40.0)
		collision.shape = rectangle
		wall.add_child(collision)
		arena.add_child(wall)
	var result := {"weapon": weapon_id, "distance": distance, "facing": facing,
		"archetype": archetype, "emitted": 0, "hits": 0, "damage": 0,
		"initial_hp": enemy.hp, "hp": enemy.hp, "dead": false, "stealth": false,
		"zones": {}, "travel": [], "absorbed": 0.0, "shells_spent": 0,
		"muzzle": snappedf((player.gun.muzzle.global_position - player.global_position).dot(aim_direction), 0.001)}
	enemy.health_changed.connect(func(current_hp: int, _max_hp: int) -> void: result.hp = current_hp)
	enemy.actor_died.connect(func(_source: Vector2) -> void: result.dead = true)
	player.projectile_requested.connect(func(origin: Vector2, direction: Vector2, enemy_owned: bool, amount: int, attack_id: String, shooter: CollisionObject2D) -> void:
		result.emitted += 1
		var bullet := BULLET.instantiate()
		bullet.global_position = origin
		bullet.shot_id = player.gun.current_shot_id
		bullet.setup(direction, enemy_owned, amount, attack_id, origin, data.bullet_speed, shooter,
			data.penetration_power, data.property_damage, data.damage_falloff_start,
			data.damage_falloff_end, data.minimum_damage_ratio)
		bullet.damage_impact.connect(func(context: DamageContext) -> void:
			result.hits += 1
			result.damage += context.damage
			result.zones[context.hit_zone] = int(result.zones.get(context.hit_zone, 0)) + 1
			result.travel.append(snappedf(context.travel_distance, 0.01))
			result.absorbed += context.armor_absorbed
			result.stealth = result.stealth or context.stealth_critical)
		arena.add_child(bullet))
	for frame in range(2): await get_tree().physics_frame
	# Seeding immediately before the real trigger makes alias/orientation trials
	# share identical pellet strata despite random AI/sprite setup in _ready.
	seed(5901)
	var before: int = player.gun.ammo
	var fired: bool = player.gun.try_fire(aim_direction)
	_expect(fired != wall_in_barrel, "production trigger must fire in open space and retain wall-in-barrel guard")
	result.shells_spent = before - player.gun.ammo
	for frame in range(18): await get_tree().physics_frame
	arena.queue_free()
	await get_tree().process_frame
	return result

func _stop_updates(node: Node) -> void:
	# PROCESS_MODE_DISABLED would remove CollisionObject2D bodies from the
	# physics space (default disable_mode REMOVE), invalidating a real hit test.
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): _stop_updates(child)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
