extends Node
const BLOOD := preload("res://scripts/roguelike/blood_resource_controller.gd")
const OFFER := preload("res://scripts/roguelike/safe_build_offer.gd")
const ROOMS := preload("res://scripts/roguelike/room_run_controller.gd")
var failures := 0

func _ready() -> void:
	call_deferred("run_test")

func run_test() -> void:
	for run_seed in range(40):
		var rooms := HandcraftedRoomCatalog.get_assignments(run_seed, 8)
		check(rooms == HandcraftedRoomCatalog.get_assignments(run_seed, 8), "seeded encounters must replay exactly")
		var seen := {}
		var previous := ""
		for room in rooms:
			check(not seen.has(room.id), "room deck must not repeat before exhaustion")
			check(room.combat_kind != previous, "early encounter rhythm must vary")
			seen[room.id] = true
			previous = room.combat_kind
	var blood := BLOOD.new()
	var rooms := ROOMS.new()
	add_child(blood)
	add_child(rooms)
	var offer := OFFER.new()
	offer.blood = blood
	offer.rooms = rooms
	add_child(offer)
	offer.offer(2)
	offer._process(0.0)
	check(not offer.label.visible, "no reward after every room")
	offer.offer(3)
	rooms.engaged_rooms["contact"] = true
	offer._process(0.0)
	check(not offer.label.visible, "reward must not interrupt ongoing combat")
	rooms.engaged_rooms.clear()
	offer._process(0.5)
	check(not offer.label.visible, "choice must allow outgoing attack effects to settle")
	offer._process(0.5)
	check(offer.label.visible and not get_tree().paused, "safe choice is optional and never pauses gameplay")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F1
	event.pressed = true
	offer._unhandled_key_input(event)
	check(blood.build_id == "harvester" and blood.capacity == 70.0, "harvester must apply its capacity tradeoff")
	offer.offer(6)
	check(not offer.pending, "one choice per floor prevents stacking abuse")
	blood.set_build("heavy")
	check(blood.enhanced_round_cost == 5.0 and blood.enhanced_damage_multiplier == 2.1, "heavy build pays for its power")
	blood.set_build("mobile")
	check(blood.stance_move_multiplier == 0.94 and blood.enhanced_damage_multiplier == 1.35, "mobility trades damage for speed")
	blood.set_build("balanced")
	check(blood.enhanced_round_cost == 3.5 and blood.capacity == 100.0, "build changes must not compound modifiers")
	print("COMBAT_FLOW_UPGRADE ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(failures)

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
