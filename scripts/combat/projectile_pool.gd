class_name ProjectilePool
extends Node2D

const SCENE := preload("res://scenes/bullet.tscn")
var available: Array[Node] = []
var leased: Dictionary = {}
var active: Array[Node] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	# Retirement is deferred; dispatch never mutates this list.
	for bullet in active:
		if is_instance_valid(bullet) and not bullet.retiring: bullet._physics_process(delta)

func warm(count := 200) -> void:
	for index in range(maxi(0, count - get_child_count())):
		var bullet = SCENE.instantiate()
		bullet.managed = true
		add_child(bullet)
		bullet.pool_release = release
		bullet.tree_exiting.connect(_forget_exiting.bind(bullet))
		bullet.park()
		available.append(bullet)

func acquire() -> Node:
	if available.is_empty(): return null
	var bullet = available.back()
	if not RuntimeBudget.track_pooled("bullet", bullet): return null
	available.pop_back()
	leased[bullet.get_instance_id()] = bullet
	active.append(bullet)
	set_physics_process(true)
	bullet.reset_for_reuse()
	return bullet

func release(bullet: Node) -> void:
	if not leased.erase(bullet.get_instance_id()): return
	active.erase(bullet)
	if active.is_empty(): set_physics_process(false)
	RuntimeBudget.release_pooled("bullet", bullet)
	bullet.park()
	available.append(bullet)

func _forget_exiting(bullet: Node) -> void:
	# Scene teardown and older callers can free a leased projectile directly.
	if leased.erase(bullet.get_instance_id()): RuntimeBudget.release_pooled("bullet", bullet)
	active.erase(bullet)
	available.erase(bullet)
	if active.is_empty(): set_physics_process(false)

func _exit_tree() -> void:
	for bullet in leased.values():
		if is_instance_valid(bullet): RuntimeBudget.release_pooled("bullet", bullet)
	leased.clear()
	active.clear()
	available.clear()
