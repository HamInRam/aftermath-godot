class_name ProjectilePool
extends Node2D

const SCENE := preload("res://scenes/bullet.tscn")
var available: Array[Node] = []
var leased: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func warm(count := 200) -> void:
	for index in range(maxi(0, count - get_child_count())):
		var bullet = SCENE.instantiate()
		add_child(bullet)
		bullet.pool_release = release
		bullet.park()
		available.append(bullet)

func acquire() -> Node:
	if available.is_empty(): return null
	var bullet = available.back()
	if not RuntimeBudget.track_pooled("bullet", bullet): return null
	available.pop_back()
	leased[bullet.get_instance_id()] = bullet
	bullet.reset_for_reuse()
	return bullet

func release(bullet: Node) -> void:
	if not leased.erase(bullet.get_instance_id()): return
	RuntimeBudget.release_pooled("bullet", bullet)
	bullet.park()
	available.append(bullet)

func _exit_tree() -> void:
	for bullet in leased.values():
		if is_instance_valid(bullet): RuntimeBudget.release_pooled("bullet", bullet)
	leased.clear()
	available.clear()
