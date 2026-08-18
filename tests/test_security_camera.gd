extends Node2D

const CAMERA_SCENE := preload("res://scenes/props/security_camera.tscn")

class DummyPlayer:
	extends CharacterBody2D
	var is_dead := false

var failures := 0
var alarms := 0
var shutdowns := 0

func _ready() -> void:
	var player := DummyPlayer.new()
	player.add_to_group("player")
	player.global_position = Vector2(38, 0)
	add_child(player)
	var camera := CAMERA_SCENE.instantiate() as SecurityCamera
	camera.scan_arc_degrees = 0.0
	camera.detection_time = 0.04
	camera.alarm_triggered.connect(func(_device: SecurityCamera, _position: Vector2): alarms += 1)
	camera.disabled.connect(func(_device: SecurityCamera): shutdowns += 1)
	add_child(camera)
	for frame in range(6): await get_tree().physics_frame
	_expect(alarms == 1 and camera.alarm_latched, "clear sustained vision should trigger one latched alarm")
	_expect(camera.detection_progress >= 1.0, "camera should expose full detection progress")
	player.global_position = Vector2(10, 0)
	_expect(camera.interact(player), "nearby player should be able to disable a camera")
	_expect(camera.is_offline and shutdowns == 1, "disabled camera should report one shutdown")
	for frame in range(4): await get_tree().physics_frame
	_expect(alarms == 1, "offline camera must stop creating alarms")
	_expect(not camera.interact(player), "offline camera should reject duplicate interaction")
	if failures == 0: print("security camera regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
