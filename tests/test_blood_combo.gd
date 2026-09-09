extends Node2D
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var enemy := Actor.new()
	add_child(enemy)
	enemy.add_to_group("enemy")
	var ctx := DamageContext.create(Vector2.ZERO, Vector2.RIGHT, 20, "pistol", 0, false, "torso", Vector2.ZERO, enemy)
	ctx.configure_blood_yield(true, 0)
	check(ctx.blood_yield_multiplier == 1, "fresh chain baseline")
	ctx.lethal = true
	ctx.configure_blood_yield(true, 4)
	check(ctx.blood_yield_multiplier == 1.5, "lethal hit includes its own kill")
	ctx.configure_blood_yield(true, 100)
	check(ctx.blood_yield_multiplier == 2, "combo capped")
	ctx.blood_budget_raw = 50
	ctx.configure_blood_yield(true, 10)
	check(ctx.blood_yield_multiplier == 1, "finite ledger excluded")
	ctx.blood_budget_raw = -1
	enemy.is_dead = true
	ctx.configure_blood_yield(true, 10)
	check(ctx.blood_yield_multiplier == 1, "dead actor excluded")
	enemy.is_dead = false
	enemy.set_meta("polluter", true)
	ctx.configure_blood_yield(true, 10)
	check(ctx.blood_yield_multiplier == 1, "polluter excluded")
	enemy.set_meta("polluter", false)
	ctx.configure_blood_yield(false, 10)
	check(ctx.blood_yield_multiplier == 1, "legacy mode excluded")
	ctx.blood_enhanced = true
	ctx.configure_blood_yield(true, 10)
	check(ctx.blood_yield_multiplier == 1, "enhanced shot excluded")
	ctx.blood_enhanced = false
	ctx.damage = 0
	ctx.configure_blood_yield(true, 10)
	check(ctx.blood_yield_multiplier == 1, "zero damage excluded")
	ctx.damage = 20
	enemy.remove_from_group("enemy")
	ctx.configure_blood_yield(true, 10)
	check(ctx.blood_yield_multiplier == 1, "non-hostile actor excluded")
	enemy.add_to_group("enemy")
	var a := PixelBloodCanvas.new()
	var b := PixelBloodCanvas.new()
	add_child(a)
	add_child(b)
	a.splash_coverage = 1.8
	b.splash_coverage = 1.8
	seed(72)
	var base := a.stamp_splatter(Vector2.ZERO, Vector2.RIGHT, 1, "dots", 0.85, "", -1, 32, 1)
	seed(72)
	var boosted := b.stamp_splatter(Vector2.ZERO, Vector2.RIGHT, 1, "dots", 0.85, "", -1, 32, 2)
	check(boosted > base and boosted <= base * 2.1, "mass gain bounded with integer rounding")
	for x in range(-45, 46):
		for y in range(-45, 46):
			check((a.get_blood_amount(Vector2(x,y)) > 0) == (b.get_blood_amount(Vector2(x,y)) > 0), "yield preserves pixel footprint")
	var system := BloodSystem.new()
	add_child(system)
	ctx.lethal = false
	system.emit_context(ctx)
	check(ctx.blood_emitted, "context marks emission")
	seed(88)
	system.emit_context(ctx)
	var after := randf()
	seed(88)
	check(after == randf(), "duplicate emission does not consume RNG or spawn")
	var limited := b.stamp_splatter(Vector2(300, 300), Vector2.RIGHT, 1, "dots", 0.85, "", 50, 32, 2)
	check(limited <= 50, "explicit raw budget remains strict")
	print("BLOOD_COMBO_OK" if failures == 0 else "BLOOD_COMBO_FAILED")
	get_tree().quit(0 if failures == 0 else 1)
