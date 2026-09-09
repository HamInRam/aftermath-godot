extends Node2D
class Player:
	extends Node2D
	var controls_enabled := true
	var is_dead := false
var count := 0
func _ready() -> void:
	var player := Player.new()
	add_child(player)
	var exit := FloorExit.new()
	exit.player = player
	add_child(exit)
	exit.set_process(false)
	exit.entered.connect(func() -> void: count += 1)
	exit._process(1.0)
	assert(count == 0, "standing on newly unlocked exit must not teleport")
	player.position = Vector2(40,0)
	exit._process(0.01)
	player.position = Vector2.ZERO
	player.controls_enabled = false
	exit._process(0.01)
	assert(count == 0, "disabled player cannot trigger exit")
	player.controls_enabled = true
	exit._process(0.01)
	exit._process(0.01)
	assert(count == 1, "crossing triggers exactly once")
	for audio in exit.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	exit.queue_free()
	player.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("FLOOR_EXIT_OK")
	get_tree().quit()
