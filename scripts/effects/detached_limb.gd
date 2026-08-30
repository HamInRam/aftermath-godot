class_name DetachedLimb
extends CharacterBody2D

const PIXEL_PAINTER := preload("res://utility/pixel_art_painter.gd")

var limb_kind := "arm"
var blood_amount := 1.0
var spin := 0.0
var trail_distance := 0.0
var previous_position := Vector2.ZERO
var settled := false

func _ready() -> void:
	z_index = 6
	CleanupRegistry.register_target(self)
	add_to_group("gore_limb")
	previous_position = global_position

func setup(kind: String, direction: Vector2, intensity: float) -> void:
	limb_kind = kind
	velocity = direction.normalized().rotated(randf_range(-0.42, 0.42)) * randf_range(48.0, 88.0) * clampf(intensity, 0.8, 2.0)
	spin = randf_range(-11.0, 11.0)
	rotation = randf_range(-PI, PI)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if settled: return
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		velocity = velocity.bounce(collision.get_normal()) * 0.22
		spin *= 0.35
		Events.publish_combat_noise(collision.get_position(), 46.0, "gore_impact")
	trail_distance += global_position.distance_to(previous_position)
	if trail_distance >= 7.0:
		var blood_system := get_tree().get_first_node_in_group("blood_system")
		if is_instance_valid(blood_system) and blood_system.has_method("spawn_micro_drop"):
			blood_system.spawn_micro_drop(global_position, 0.45, previous_position.direction_to(global_position))
		trail_distance = 0.0
	previous_position = global_position
	velocity = velocity.move_toward(Vector2.ZERO, 110.0 * delta)
	rotation = snappedf(rotation + spin * delta, PI / 4.0)
	spin = move_toward(spin, 0.0, 10.0 * delta)
	if velocity.length() < 2.0:
		settled = true
		velocity = Vector2.ZERO
		set_physics_process(false)

func clean_step() -> void:
	blood_amount -= 0.25
	if blood_amount <= 0.02:
		CleanupRegistry.unregister_target(self)
		queue_free()
	else: queue_redraw()

func get_cleanup_type() -> String: return "gore"
func get_cleanup_cost() -> int: return 4
func get_cleanup_progress() -> float: return 1.0 - blood_amount

func _draw() -> void:
	var outline := Color(0.08, 0.025, 0.04, blood_amount)
	var cloth := Color(0.31, 0.10, 0.28, blood_amount)
	var flesh := Color(0.94, 0.42, 0.44, blood_amount)
	var blood := Color(0.58, 0.005, 0.035, blood_amount)
	if limb_kind == "leg":
		PIXEL_PAINTER.material_panel(self, Rect2(-5, -2, 8, 4), outline, cloth, cloth.lightened(0.14), cloth.darkened(0.18), 3, &"fabric")
		PIXEL_PAINTER.material_rect(self, Rect2(2, -1, 3, 2), flesh, flesh.lightened(0.12), blood, 5)
	elif limb_kind == "head":
		PIXEL_PAINTER.material_circle(self, Vector2.ZERO, 3, outline, outline.lightened(0.1), outline.darkened(0.2), 7)
		PIXEL_PAINTER.material_circle(self, Vector2.ZERO, 2, flesh, flesh.lightened(0.12), blood, 11)
		PIXEL_PAINTER.pixel(self, Vector2(-1, -1), Color(0.96, 0.88, 0.76, blood_amount))
	else:
		PIXEL_PAINTER.material_panel(self, Rect2(-4, -2, 7, 4), outline, cloth, cloth.lightened(0.14), cloth.darkened(0.18), 13, &"fabric")
		PIXEL_PAINTER.material_rect(self, Rect2(2, -1, 3, 2), flesh, flesh.lightened(0.12), blood, 17)
