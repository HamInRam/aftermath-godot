extends Node

const CORPSE_SCENE := preload("res://scenes/corpse.tscn")

class DummyInvestigator:
	extends Node
	var is_dead := false

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var first = CORPSE_SCENE.instantiate()
	var nearby = CORPSE_SCENE.instantiate()
	var distant = CORPSE_SCENE.instantiate()
	add_child(first)
	add_child(nearby)
	add_child(distant)
	first.global_position = Vector2.ZERO
	nearby.global_position = Vector2(24, 0)
	distant.global_position = Vector2(96, 0)
	var investigator_a := DummyInvestigator.new()
	var investigator_b := DummyInvestigator.new()
	add_child(investigator_a)
	add_child(investigator_b)
	_expect(first.try_claim_investigation(investigator_a), "first investigator should claim the incident")
	_expect(not first.try_claim_investigation(investigator_b), "a second investigator must not claim the same corpse")
	_expect(not nearby.try_claim_investigation(investigator_b), "nearby corpses should share one active incident investigator")
	_expect(distant.try_claim_investigation(investigator_b), "a distant corpse should allow a separate investigator")
	first.complete_investigation(investigator_a)
	_expect(first.is_investigation_complete(), "the claimed corpse should become complete")
	_expect(not nearby.try_claim_investigation(investigator_b), "a completed nearby incident should resolve the corpse cluster")
	_expect(nearby.is_investigation_complete(), "the nearby corpse should inherit the resolved incident state")
	var chain_a = CORPSE_SCENE.instantiate()
	var chain_b = CORPSE_SCENE.instantiate()
	var chain_c = CORPSE_SCENE.instantiate()
	add_child(chain_a)
	add_child(chain_b)
	add_child(chain_c)
	chain_a.global_position = Vector2(0, 120)
	chain_b.global_position = Vector2(40, 120)
	chain_c.global_position = Vector2(80, 120)
	_expect(chain_a.try_claim_investigation(investigator_a), "a chained incident should accept its first investigator")
	_expect(not chain_c.try_claim_investigation(investigator_b), "A-B-C proximity chains must share one investigator")
	chain_a.complete_investigation(investigator_a)
	_expect(chain_c.is_investigation_complete(), "completion must propagate through an A-B-C incident chain")
	if failures == 0:
		print("corpse coordination regression: PASS")
	get_tree().quit(failures)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
