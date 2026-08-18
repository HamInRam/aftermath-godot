class_name SecurityCamera
extends StaticBody2D

signal alarm_triggered(camera: SecurityCamera, player_position: Vector2)
signal disabled(camera: SecurityCamera)

@export var detection_range := 105.0
@export_range(20.0, 160.0) var vision_fov_degrees := 62.0
@export var detection_time := 0.35
@export var scan_arc_degrees := 82.0
@export var scan_speed := 1.25
@export var interaction_range := 20.0
@export var alert_radius := 360.0

var is_offline := false
var detection_progress := 0.0
var alarm_latched := false
var hidden_time := 0.0
var base_rotation := 0.0
var scan_time := 0.0
var player: Node2D

func _ready() -> void:
	add_to_group("security_device")
	base_rotation = rotation
	player = get_tree().get_first_node_in_group("player") as Node2D
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_offline: return
	if not is_instance_valid(player): player = get_tree().get_first_node_in_group("player") as Node2D
	scan_time += delta * scan_speed
	rotation = base_rotation + sin(scan_time) * deg_to_rad(scan_arc_degrees * 0.5)
	var sees_player := is_instance_valid(player) and not bool(player.get("is_dead")) and _can_see_player()
	if sees_player:
		hidden_time = 0.0
		detection_progress = minf(1.0, detection_progress + delta / maxf(0.05, detection_time))
		if detection_progress >= 1.0 and not alarm_latched: _trigger_alarm(player.global_position)
	else:
		detection_progress = maxf(0.0, detection_progress - delta * 1.8)
		hidden_time += delta
		if hidden_time >= 1.25: alarm_latched = false
	queue_redraw()

func _can_see_player() -> bool:
	return EnemyPerception.can_see_target(self, player, detection_range, vision_fov_degrees, 32)

func _trigger_alarm(player_position: Vector2) -> void:
	alarm_latched = true
	alarm_triggered.emit(self, player_position)
	var likely_direction := global_position.direction_to(player_position)
	Events.publish_tactical_alert(player_position, likely_direction, "security_camera", self)
	Events.publish_combat_noise(player_position, alert_radius, "security_alarm")

func interact(actor: Node2D) -> bool:
	if is_offline or not is_instance_valid(actor) or global_position.distance_to(actor.global_position) > interaction_range: return false
	disable()
	return true

func receive_projectile_impact(_impact_velocity: Vector2, _hit_position: Vector2) -> void:
	disable()

func disable() -> void:
	if is_offline: return
	is_offline = true
	detection_progress = 0.0
	set_physics_process(false)
	disabled.emit(self)
	queue_redraw()

func get_interaction_prompt() -> String:
	return "" if is_offline else "[ E ] DISABLE CAMERA"

func _draw() -> void:
	var body_color := Color("454552") if is_offline else Color("c8d5db")
	var lens_color := Color("3b4548") if is_offline else (Color("ff315c") if alarm_latched else Color("65f7ff"))
	draw_line(Vector2(-7, 0), Vector2(-3, 0), body_color, 2.0)
	draw_rect(Rect2(-3, -4, 8, 8), body_color)
	draw_polygon(PackedVector2Array([Vector2(5, -3), Vector2(9, 0), Vector2(5, 3)]), PackedColorArray([body_color]))
	draw_circle(Vector2(5, 0), 1.5, lens_color)
	if is_offline:
		draw_line(Vector2(-2, -5), Vector2(7, 5), Color("ffcf66"), 1.5)
		return
	var vision_color := Color(1.0, 0.14, 0.3, 0.08 + detection_progress * 0.16)
	var half_fov := deg_to_rad(vision_fov_degrees * 0.5)
	var points := PackedVector2Array([Vector2.ZERO])
	for index in range(9):
		points.append(Vector2.RIGHT.rotated(lerpf(-half_fov, half_fov, index / 8.0)) * detection_range)
	draw_colored_polygon(points, vision_color)
	draw_arc(Vector2.ZERO, 12.0, -half_fov, half_fov, 12, lens_color, 1.0)
	if detection_progress > 0.0:
		draw_arc(Vector2.ZERO, 15.0, -PI * 0.5, -PI * 0.5 + TAU * detection_progress, 16, Color("ff315c"), 1.5)
