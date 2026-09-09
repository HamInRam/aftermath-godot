class_name FloorExit
extends Node2D
signal entered
var player: Node2D
var armed := false
var spent := false
var delay := 0.75
func _ready() -> void:
	z_index = 20
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
	var latch := AudioStreamPlayer.new()
	latch.stream = preload("res://assets/audio/sfx/pistol_reload.wav")
	latch.bus = "SFX"
	latch.volume_db = -12.0
	latch.pitch_scale = 0.75
	add_child(latch)
	latch.play()
func _process(delta: float) -> void:
	if not is_instance_valid(player) or spent: return
	queue_redraw()
	delay -= delta
	var distance := global_position.distance_to(player.global_position)
	# Clearing while standing at the exit never causes an unsolicited transfer.
	if distance > 24.0: armed = true
	if armed and delay <= 0.0 and distance < 12.0 and player.controls_enabled and not player.is_dead:
		spent = true
		entered.emit()
func _draw() -> void:
	draw_rect(Rect2(-12,-9,24,18), Color("111111"))
	draw_rect(Rect2(-12,-9,24,18), Color.WHITE, false, 1.0)
	for i in range(6):
		draw_rect(Rect2(-5+i,-5+i,2,2),Color.WHITE)
		draw_rect(Rect2(-5+i,5-i,2,2),Color.WHITE)
	if is_instance_valid(player) and global_position.distance_to(player.global_position) > 40.0:
		var direction := player.global_position.direction_to(global_position)
		var tip := to_local(player.global_position + direction * 24.0)
		for i in range(5):
			for side in [-1,1]:
				var point: Vector2 = (tip - direction * i + direction.orthogonal() * i * side).round()
				draw_rect(Rect2(point, Vector2.ONE),Color.WHITE)
