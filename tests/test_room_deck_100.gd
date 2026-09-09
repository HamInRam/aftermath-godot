extends Node
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _ready() -> void:
	var errors := HandcraftedRoomCatalog.validate_catalog()
	check(errors.is_empty(), str(errors))
	var modules := HandcraftedRoomCatalog.get_modules()
	check(modules.size() == 100, "100 base compositions, not counting rotations")
	for module in modules:
		for orientation in 8:
			var variant := HandcraftedRoomCatalog._transform_module(module.duplicate(true),orientation)
			for point: Vector2 in variant.enemies + variant.props:
				check(Rect2(.139,.139,.722,.722).has_point(point), "rotated anchor bounds")
			for direction: Vector2 in variant.patrols: check(is_equal_approx(direction.length(),1.0), "patrol heading")
	for seed_value in [1,19,552,99001]:
		var deck := HandcraftedRoomCatalog.get_assignments(seed_value,100)
		check(deck == HandcraftedRoomCatalog.get_assignments(seed_value,100), "explicit seed reproduces the deck")
		var ids := {}
		for module in deck: ids[module.id] = true
		check(ids.size() == 100, "no repeated modules before deck exhaustion")
	check(HandcraftedRoomCatalog.get_assignments(1,8) != HandcraftedRoomCatalog.get_assignments(19,8), "different seed rearranges modules")
	var first := TileWorld.new()
	var second := TileWorld.new()
	first.layout_variant = "nightclub"
	second.layout_variant = "nightclub"
	first.room_entry_nonce = 123
	second.room_entry_nonce = 124
	check(first._get_room_run_seed() != second._get_room_run_seed(), "new entry re-deals")
	check(first._get_room_run_seed() == first._get_room_run_seed(), "props and enemies use same entry seed")
	first.room_run_seed_override = 17
	second.room_run_seed_override = 17
	check(first._get_room_run_seed() == second._get_room_run_seed(), "debug seed overrides entry randomness")
	first.free(); second.free()
	print("ROOM_DECK_100_OK" if failures == 0 else "ROOM_DECK_100_FAILED")
	get_tree().quit(failures)
