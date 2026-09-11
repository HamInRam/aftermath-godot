extends Node
# Corpse investigation was removed; only combat remains.
func _ready() -> void:
	var corpse = preload("res://scenes/corpse.tscn").instantiate()
	assert(not corpse.has_method("try_claim_investigation"))
	assert(not corpse.has_method("complete_investigation"))
	assert(get_node_or_null("/root/CorpseIncidentRegistry") == null)
	assert(corpse.can_receive_overkill())
	corpse.overkill_hits = 1
	assert(not corpse.can_receive_overkill())
	corpse.free()
	print("corpse combat-only regression: PASS")
	get_tree().quit()
