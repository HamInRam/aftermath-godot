@static_unload
class_name PixelActorArt
extends RefCounted

## Native-pixel overhead tailoring. All actors share this authoring grid; the
## live Verlet rig supplies motion, never a different, unused preview drawing.
## Templates face east. Rotation samples destination pixel centres, so neither
## diagonals nor continuous aim can turn a source texel into a rotated quad.
const TORSO := [
	"....iii..", "..iieeci.", ".iecccci.", "icccccci.", "iccsscci.",
	"iccsscci.", "icccccci.", ".iccccci.", "..iiccci.", "....iii..",
]
const HEAVY_TORSO := [
	"....iii.", "..iieeci", ".iecccci", "ieccssci", "iccsssci",
	"iccsssci", "icccssci", "iiccccci", ".iicccci", "..iieci.", "....iii.",
]
const MASK := [".iii.", "ikppi", "ikppi", "ikppi", ".iii."]
const CROWN := [".iii.", "ikkki", "ikgki", "ikkki", ".iii."]
const HELMET := [".iii.", "iggki", "igkki", "ikkki", ".iii."]
const HOUND_BODY := [
	"...iiii....", ".iiecccii..", "iecccsscci.", "icccsscccci",
	"icccsscccci", ".iccccccci.", "..iicccii..", "....iii....",
]
const HOUND_HEAD := ["i....", "kii..", "ikggi", "ikgki", "kii..", "i...."]

static func palette(role: String) -> Dictionary:
	var cloth := Color("dedede")
	var sleeve := Color("dedede")
	var edge := Color("fafafa")
	var seam := Color("a2a2a2")
	match role:
		"player": cloth = Color("202020"); sleeve = cloth; edge = Color("999999"); seam = Color("454545")
		"assault": cloth = Color("494949"); edge = Color("ababab"); seam = Color("272727")
		"heavy": cloth = Color("555555"); sleeve = Color("bcbcbc"); edge = Color("d0d0d0"); seam = Color("2c2c2c")
		"melee": cloth = Color("c8c8c8"); sleeve = cloth; seam = Color("909090")
		"hound": cloth = Color("555555"); sleeve = cloth; edge = Color("bcbcbc"); seam = Color("343434")
	return {"i": Color("090909"), "c": cloth, "e": edge, "s": seam,
		"h": Color("b5b5b5"), "p": Color("f5f5f5"), "k": Color("202020"),
		"g": Color("646464"), "u": sleeve, "b": Color("292929"), "n": Color("d7d7d7")}

static func human_pixels(role: String, angle: float, hands: Array[Vector2], offsets := {}) -> Dictionary:
	var cells := {}
	var colors := palette(role)
	# Hands and shoulders share the ground plane. There are no north-only face,
	# chest or sleeve patches, and no fixed screen-up body-height projection.
	var heavy := role == "heavy"
	var shoulder_span := 4.5 if heavy else 3.8
	for index in 2:
		var sign_value := 1.0 if index == 0 else -1.0
		var shoulder := Vector2(0, sign_value * shoulder_span)
		var hand: Vector2 = hands[index] + (offsets.get("hand_a" if index == 0 else "hand_b", Vector2.ZERO) as Vector2)
		# The support elbow folds toward the fore-end; the trigger elbow stays
		# beside the ribs. Asymmetry makes the grip readable at native resolution.
		var elbow := Vector2(1.5 if index == 0 else 3.0, sign_value * (shoulder_span + 0.5))
		_segment(cells, shoulder, elbow, 3.0, colors.i, "arm_a" if index == 0 else "arm_b")
		_segment(cells, elbow, hand - Vector2(1, 0), 3.0, colors.i, "arm_a" if index == 0 else "arm_b")
		_segment(cells, shoulder, elbow, 1.0, colors.u, "arm_a" if index == 0 else "arm_b")
		_segment(cells, elbow, hand - Vector2(1, 0), 1.0, colors.h if role == "melee" else colors.u, "arm_a" if index == 0 else "arm_b")
		_put(cells, (hand - Vector2(1, 0)).round(), colors.p if role != "player" else colors.e, "cuff")
		_stamp(cells, [".ii", "ihh", ".ii"], hand, colors, "hand_a" if index == 0 else "hand_b")
	_stamp(cells, HEAVY_TORSO if heavy else TORSO, Vector2(-1, 0), colors, "torso")
	# Structural role differences: long coat hem, rolled cuffs, tactical vest,
	# broad plated shoulders. Identification never depends on a coloured badge.
	if role == "player":
		_stamp(cells, ["ii.", "isc", "ic.", ".i."], Vector2(-4, 1), colors, "coat")
	elif role == "assault":
		_segment(cells, Vector2(-2, -2), Vector2(0, -2), 1, colors.i, "webbing")
		_segment(cells, Vector2(-2, 2), Vector2(0, 2), 1, colors.i, "webbing")
	elif role == "heavy":
		_put(cells, Vector2(0, -4), colors.p, "shoulder")
		_put(cells, Vector2(0, 4), colors.p, "shoulder")
	var head_offset: Vector2 = offsets.get("head", Vector2.ZERO)
	_stamp(cells, MASK if role == "player" else (HELMET if heavy else CROWN), Vector2(2, 0) + head_offset, colors, "head")
	return rotate_pixels(cells, angle)

static func hound_pixels(angle: float, stride := 0.0) -> Dictionary:
	var cells := {}
	var colors := palette("hound")
	_segment(cells, Vector2(-5, 0), Vector2(-8, -1 - stride * 0.5), 1, colors.e, "tail")
	for sign_value in [-1.0, 1.0]:
		_segment(cells, Vector2(0, sign_value * 2), Vector2(2 + stride * sign_value, sign_value * 4), 1, colors.g, "front_paw")
		_segment(cells, Vector2(-4, sign_value * 2), Vector2(-5 - stride * sign_value, sign_value * 3), 1, colors.g, "rear_paw")
	_stamp(cells, HOUND_BODY, Vector2(-1, 0), colors, "torso")
	_stamp(cells, HOUND_HEAD, Vector2(5, 0), colors, "head")
	# Two folded ears and a short muzzle distinguish the quadruped from a
	# human shoulder silhouette, without painting a side-on face or long legs.
	_put(cells, Vector2(4, -3), colors.i, "ear")
	_put(cells, Vector2(4, 3), colors.i, "ear")
	_put(cells, Vector2(6, 0), colors.e, "muzzle")
	_put(cells, Vector2(7, 0), colors.i, "nose")
	return rotate_pixels(cells, angle)

static func rotate_pixels(cells: Dictionary, angle: float) -> Dictionary:
	var result := {}
	var lower := Vector2.ZERO
	var upper := Vector2.ZERO
	for source_cell: Vector2 in cells:
		var rotated := source_cell.rotated(angle)
		lower = lower.min(rotated - Vector2.ONE)
		upper = upper.max(rotated + Vector2.ONE)
	for y in range(floori(lower.y), ceili(upper.y) + 1):
		for x in range(floori(lower.x), ceili(upper.x) + 1):
			var source := Vector2(x, y).rotated(-angle).round()
			if cells.has(source): result[Vector2(x, y)] = cells[source]
	return result

static func _stamp(cells: Dictionary, rows: Array, center: Vector2, colors: Dictionary, part: String) -> void:
	var origin := center.round() - Vector2(floori(float(str(rows[0]).length()) * 0.5), floori(float(rows.size()) * 0.5))
	for y in rows.size():
		for x in str(rows[y]).length():
			var token := str(rows[y])[x]
			if colors.has(token): _put(cells, origin + Vector2(x, y), colors[token], part)

static func _segment(cells: Dictionary, start: Vector2, finish: Vector2, width: float, color: Color, part: String) -> void:
	var minimum := start.min(finish) - Vector2.ONE * width
	var maximum := start.max(finish) + Vector2.ONE * width
	for y in range(floori(minimum.y), ceili(maximum.y) + 1):
		for x in range(floori(minimum.x), ceili(maximum.x) + 1):
			var cell := Vector2(x, y)
			if Geometry2D.get_closest_point_to_segment(cell, start, finish).distance_to(cell) <= width * 0.5:
				_put(cells, cell, color, part)

static func _put(cells: Dictionary, at: Vector2, color: Color, part: String) -> void:
	cells[at] = {"color": color, "part": part}

static func to_image(cells: Dictionary, size := 32) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for at: Vector2 in cells:
		var cell := Vector2i(at) + Vector2i(size / 2, size / 2)
		if cell.x >= 0 and cell.y >= 0 and cell.x < size and cell.y < size:
			image.set_pixelv(cell, cells[at].color)
	return image
