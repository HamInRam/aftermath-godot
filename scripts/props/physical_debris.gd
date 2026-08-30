class_name PhysicalDebris
extends RigidBody2D

const PIXELS := preload("res://utility/pixel_art_painter.gd")

var debris_material := "wood"
var primary := Color("8f572f")
var secondary := Color("d99a55")
var cleanup_steps := 1
var settle_time := 1.4
var launch_delay := 0.0
var pending_velocity := Vector2.ZERO
var pending_angular_velocity := 0.0
var impact_spent := false

func setup(material_name: String, profile: Dictionary, direction: Vector2, intensity: float, chunk_index: int) -> void:
	debris_material = material_name
	primary = profile.primary
	secondary = profile.secondary
	gravity_scale = 0.0
	mass = 0.22 + chunk_index * 0.08
	linear_damp = 4.2
	angular_damp = 3.8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	collision_layer = 32
	collision_mask = 7
	contact_monitor = true
	max_contacts_reported = 4
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4 + chunk_index % 2 * 2, 2 + chunk_index % 3)
	shape_node.shape = shape
	# Debris can be spawned from a body_entered callback during a chain reaction.
	# Installing a body shape while PhysicsServer2D is flushing that query is
	# illegal, so defer only the shape attachment to the next safe frame.
	call_deferred("_install_collision_shape", shape_node)
	pending_velocity = direction.normalized().rotated(randf_range(-0.55, 0.55)) * randf_range(42.0, 92.0) * intensity
	pending_angular_velocity = randf_range(-12.0, 12.0)
	launch_delay = chunk_index * 0.025
	freeze = launch_delay > 0.0
	if not freeze:
		linear_velocity = pending_velocity
		angular_velocity = pending_angular_velocity
	body_entered.connect(_on_body_entered)
	add_to_group("environment_debris")
	CleanupRegistry.register_target(self)
	z_index = 2
	queue_redraw()

func _install_collision_shape(shape_node: CollisionShape2D) -> void:
	if not is_instance_valid(shape_node) or shape_node.get_parent() != null: return
	add_child(shape_node)

func _physics_process(delta: float) -> void:
	if launch_delay > 0.0:
		launch_delay -= delta
		if launch_delay <= 0.0:
			freeze = false
			linear_velocity = pending_velocity
			angular_velocity = pending_angular_velocity
		return
	settle_time -= delta
	if settle_time <= 0.0 or (linear_velocity.length() < 4.0 and absf(angular_velocity) < 0.5):
		freeze = true
		set_physics_process(false)

func _on_body_entered(body: Node) -> void:
	if impact_spent or linear_velocity.length() < 38.0: return
	impact_spent = true
	var direction := linear_velocity.normalized()
	var energy := clampf(linear_velocity.length() / 70.0, 0.5, 1.5)
	if body.is_in_group("destructible_prop"):
		if body.has_method("receive_thrown_impact"): body.receive_thrown_impact(direction, energy)
		elif body.has_method("take_damage"): body.take_damage(1, global_position - direction)
	elif body.is_in_group("enemy") and body.has_method("take_door_hit"):
		body.take_door_hit(direction, "knockdown")
	Events.publish_combat_noise(global_position, 54.0 + energy * 22.0, "%s_debris" % debris_material)
	linear_velocity *= 0.35

func receive_projectile_glance(impact_velocity: Vector2, hit_position: Vector2, _weapon_id: String, damage: int) -> void:
	if impact_velocity.length_squared() < 0.01: return
	var direction := impact_velocity.normalized()
	var impulse_strength := clampf(impact_velocity.length() * 0.018 * maxi(1, damage), 7.0, 28.0)
	var torque := (hit_position - global_position).cross(direction) * 0.8
	if absf(torque) < 0.25: torque = -direction.x * 1.5 + direction.y * 1.5
	freeze = false
	set_physics_process(true)
	settle_time = maxf(settle_time, 0.55)
	linear_velocity = (linear_velocity + direction * impulse_strength).limit_length(115.0)
	angular_velocity = clampf(angular_velocity + torque, -14.0, 14.0)
	Events.publish_combat_noise(global_position, 26.0, "%s_debris_ping" % debris_material)

func get_cleanup_type() -> String: return "debris"
func get_cleanup_cost() -> int: return 1
func get_cleanup_progress() -> float: return 1.0 - float(cleanup_steps)

func clean_step() -> void:
	cleanup_steps = 0
	CleanupRegistry.unregister_target(self)
	queue_free()

func _draw() -> void:
	var points := [Vector2(-2,-1), Vector2(-1,-1), Vector2(0,0), Vector2(1,0), Vector2(2,1)]
	for index in points.size():
		PIXELS.pixel(self, points[index], Color("17131b") if index in [0,4] else primary)
	PIXELS.pixel(self, Vector2(-1,0), secondary)
	PIXELS.pixel(self, Vector2(1,-1), primary.lightened(0.18))
