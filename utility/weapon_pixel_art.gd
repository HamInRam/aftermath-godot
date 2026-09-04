class_name WeaponPixelArt
extends RefCounted

const PIXELS := preload("res://utility/pixel_art_painter.gd")

const WEAPON_PATTERNS := {
	"pistol": [
		"..OOOOOOOO.",
		"..OBBBBBBO.",
		"....OOO....",
		"....OGGO...",
		"....OGGO...",
		".....OO....",
	],
	"smg": [
		".OOOOOOOOOOOO.",
		".OBBBBBBBBBAO.",
		"....OOOOOO....",
		"....OGG.OO....",
		"....OGG.......",
		".....OO.......",
	],
	"shotgun": [
		"OOOOOOOOOOOOOOOOO",
		"OBBBBBBBBBBBBBAOO",
		"OOOOOWWWWWOOOO...",
		".....OWWWO.......",
		"......OOO........",
	],
	"lmg": [
		"OOOOOOOOOOOOOOOO.",
		"OBBBBBBBBBBBBBAO.",
		"OOOOBBBBBBOOOO...",
		"....OGGGGO.......",
		"....OGGGGO.......",
		".....OOOO........",
	],
}

static func visual_length(weapon_id: String) -> int:
	match weapon_id:
		"smg": return 12
		"shotgun": return 15
		"lmg": return 14
		_: return 9

static func draw_weapon(canvas: CanvasItem, weapon_id: String, origin := Vector2.ZERO, direction := Vector2.RIGHT, floor_shadow := false) -> void:
	var forward := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	var side := forward.orthogonal()
	var body_color := Color("d8e2df")
	var accent := Color("27c9ca")
	var grip_color := Color("55313a")
	match weapon_id:
		"smg": body_color = Color("76878e"); accent = Color("ff3d84")
		"shotgun": body_color = Color("858f91"); accent = Color("ffe06b"); grip_color = Color("a8643b")
		"lmg": body_color = Color("66757a"); accent = Color("ff6a3d")
	var pattern: Array = WEAPON_PATTERNS.get(weapon_id, WEAPON_PATTERNS.pistol)
	var width := str(pattern[0]).length()
	var height := pattern.size()
	var offset_x := -floori(float(width) * 0.5)
	var offset_y := -floori(float(height) * 0.5)
	if floor_shadow:
		for y in range(height):
			var shadow_row := str(pattern[y])
			for x in range(width):
				if shadow_row[x] == ".": continue
				var shadow_position := origin + forward * float(offset_x + x) + side * float(offset_y + y) + Vector2(1, 2)
				PIXELS.pixel(canvas, shadow_position.round(), Color(0.03, 0.02, 0.05, 0.58))
	for y in range(height):
		var row := str(pattern[y])
		for x in range(width):
			var code := row[x]
			if code == ".": continue
			var color := Color("17141b")
			if code == "B": color = body_color
			elif code == "A": color = accent
			elif code in ["G", "W"]: color = grip_color
			var pixel_position := origin + forward * float(offset_x + x) + side * float(offset_y + y)
			PIXELS.pixel(canvas, pixel_position.round(), color)
