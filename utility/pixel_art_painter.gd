class_name PixelArtPainter
extends RefCounted

const GLYPHS := {
	"A": ["010", "101", "111", "101", "101"],
	"B": ["110", "101", "110", "101", "110"],
	"C": ["011", "100", "100", "100", "011"],
	"D": ["110", "101", "101", "101", "110"],
	"E": ["111", "100", "110", "100", "111"],
	"F": ["111", "100", "110", "100", "100"],
	"G": ["011", "100", "101", "101", "011"],
	"H": ["101", "101", "111", "101", "101"],
	"I": ["111", "010", "010", "010", "111"],
	"J": ["001", "001", "001", "101", "010"],
	"K": ["101", "101", "110", "101", "101"],
	"L": ["100", "100", "100", "100", "111"],
	"M": ["101", "111", "111", "101", "101"],
	"N": ["101", "111", "111", "111", "101"],
	"O": ["010", "101", "101", "101", "010"],
	"P": ["110", "101", "110", "100", "100"],
	"Q": ["010", "101", "101", "011", "001"],
	"R": ["110", "101", "110", "101", "101"],
	"S": ["011", "100", "010", "001", "110"],
	"T": ["111", "010", "010", "010", "010"],
	"U": ["101", "101", "101", "101", "111"],
	"V": ["101", "101", "101", "101", "010"],
	"W": ["101", "101", "111", "111", "101"],
	"X": ["101", "101", "010", "101", "101"],
	"Y": ["101", "101", "010", "010", "010"],
	"Z": ["111", "001", "010", "100", "111"],
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["110", "001", "010", "100", "111"],
	"3": ["110", "001", "010", "001", "110"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "110", "001", "110"],
	"6": ["011", "100", "111", "101", "111"],
	"7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"],
	"9": ["111", "101", "111", "001", "110"],
}

static func pixel(canvas: CanvasItem, position: Vector2, color: Color, size := 1) -> void:
	var snapped := Vector2(floori(position.x), floori(position.y))
	canvas.draw_rect(Rect2(snapped, Vector2.ONE * maxi(1, size)), color)

static func rect(canvas: CanvasItem, area: Rect2, color: Color, dither := 0) -> void:
	var left := floori(area.position.x)
	var top := floori(area.position.y)
	var right := ceili(area.end.x)
	var bottom := ceili(area.end.y)
	for y in range(top, bottom):
		for x in range(left, right):
			if dither > 0 and ((x * 3 + y * 5) & 3) >= dither: continue
			canvas.draw_rect(Rect2(x, y, 1, 1), color)

## Paints a surface one world pixel at a time.  Unlike a flat rect, every
## visible cell is selected independently from a compact material palette, so
## an 8px prop and a liquid droplet share the same apparent texel density.
static func material_rect(canvas: CanvasItem, area: Rect2, base: Color, highlight: Color, shadow: Color, seed := 0, pattern: StringName = &"grain") -> void:
	var left := floori(area.position.x)
	var top := floori(area.position.y)
	var right := ceili(area.end.x)
	var bottom := ceili(area.end.y)
	for y in range(top, bottom):
		for x in range(left, right):
			var hash := absi(x * 17 + y * 31 + seed * 43)
			var color := base
			match pattern:
				&"checker": color = highlight if ((x + y + seed) & 1) == 0 else shadow
				&"stripes":
					if posmod(y + seed, 3) == 0: color = shadow
					elif posmod(x + seed, 7) == 0: color = highlight
				&"wood":
					if posmod(y + seed, 3) == 0: color = shadow
					elif hash % 7 == 0: color = highlight
				&"metal":
					if hash % 11 == 0: color = highlight
					elif hash % 5 == 0: color = shadow
				&"fabric":
					if ((x + y + seed) & 3) == 0: color = highlight
					elif ((x - y + seed) & 3) == 0: color = shadow
				&"glass":
					if posmod(x - y + seed, 6) == 0: color = highlight
					elif hash % 9 == 0: color = shadow
				_:
					if hash % 13 == 0: color = highlight
					elif hash % 7 == 0: color = shadow
			canvas.draw_rect(Rect2(x, y, 1, 1), color)

## One-pixel outline plus a one-pixel material field. No stroke in this helper
## can ever become two world pixels thick.
static func material_panel(canvas: CanvasItem, area: Rect2, outline: Color, base: Color, highlight: Color, shadow: Color, seed := 0, pattern: StringName = &"grain") -> void:
	rect(canvas, area, outline)
	var inner := Rect2(area.position + Vector2.ONE, area.size - Vector2(2, 2))
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		material_rect(canvas, inner, base, highlight, shadow, seed, pattern)

static func stipple_rect(canvas: CanvasItem, area: Rect2, color: Color, seed := 0, spacing := 2) -> void:
	var step := maxi(2, spacing)
	for y in range(floori(area.position.y), ceili(area.end.y)):
		for x in range(floori(area.position.x), ceili(area.end.x)):
			if posmod(x * 3 + y * 5 + seed, step) == 0: pixel(canvas, Vector2(x, y), color)

static func material_circle(canvas: CanvasItem, center: Vector2, radius: int, base: Color, highlight: Color, shadow: Color, seed := 0, hollow := false) -> void:
	var r := maxi(1, radius)
	var inner_squared := maxi(0, r - 1) * maxi(0, r - 1)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var distance_squared := x * x + y * y
			if distance_squared > r * r or (hollow and distance_squared < inner_squared): continue
			var hash := absi((x + floori(center.x)) * 17 + (y + floori(center.y)) * 31 + seed * 43)
			var color := highlight if hash % 11 == 0 else (shadow if hash % 5 == 0 else base)
			pixel(canvas, center + Vector2(x, y), color)

## A compact sprite mass with the same one-cell material language used by
## floors, props and liquids. The silhouette may be larger than one pixel, but
## it is never rendered as one featureless enlarged texel.
static func material_block(canvas: CanvasItem, center: Vector2, size: Vector2, base: Color, seed := 0, pattern: StringName = &"fabric") -> void:
	var snapped_size := Vector2(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))
	var origin := Vector2(roundi(center.x), roundi(center.y)) - (snapped_size / 2.0).floor()
	material_rect(canvas, Rect2(origin, snapped_size), base, base.lightened(0.13), base.darkened(0.18), seed, pattern)

## Bresenham centerline expanded as individually selected one-pixel cells.
## The width changes the silhouette, never the texel size.
static func material_line(canvas: CanvasItem, start: Vector2, finish: Vector2, base: Color, width := 1, seed := 0, pattern: StringName = &"fabric") -> void:
	var x0 := roundi(start.x)
	var y0 := roundi(start.y)
	var x1 := roundi(finish.x)
	var y1 := roundi(finish.y)
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var error := dx + dy
	var radius := maxi(0, width - 1) / 2.0
	while true:
		material_rect(canvas, Rect2(Vector2(x0, y0) - Vector2.ONE * radius, Vector2.ONE * maxi(1, width)), base, base.lightened(0.13), base.darkened(0.18), seed + x0 * 3 + y0 * 5, pattern)
		if x0 == x1 and y0 == y1: break
		var twice := error * 2
		if twice >= dy:
			error += dy
			x0 += sx
		if twice <= dx:
			error += dx
			y0 += sy

static func line(canvas: CanvasItem, start: Vector2, finish: Vector2, color: Color, width := 1) -> void:
	var x0 := roundi(start.x)
	var y0 := roundi(start.y)
	var x1 := roundi(finish.x)
	var y1 := roundi(finish.y)
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var error := dx + dy
	var half := maxi(0, width - 1) / 2.0
	while true:
		rect(canvas, Rect2(Vector2(x0, y0) - Vector2.ONE * half, Vector2.ONE * width), color)
		if x0 == x1 and y0 == y1: break
		var twice := error * 2
		if twice >= dy:
			error += dy
			x0 += sx
		if twice <= dx:
			error += dx
			y0 += sy

static func circle(canvas: CanvasItem, center: Vector2, radius: int, color: Color, hollow := false) -> void:
	var r := maxi(1, radius)
	var inner_squared := maxi(0, r - 1) * maxi(0, r - 1)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var distance_squared := x * x + y * y
			if distance_squared > r * r: continue
			if hollow and distance_squared < inner_squared: continue
			pixel(canvas, center + Vector2(x, y), color)

static func polyline(canvas: CanvasItem, points: PackedVector2Array, color: Color, width := 1, close := false) -> void:
	if points.size() < 2: return
	for index in range(points.size() - 1): line(canvas, points[index], points[index + 1], color, width)
	if close: line(canvas, points[-1], points[0], color, width)

static func arc(canvas: CanvasItem, center: Vector2, radius: int, start_angle: float, end_angle: float, color: Color, steps := 20, width := 1) -> void:
	var points := PackedVector2Array()
	for index in range(maxi(2, steps) + 1):
		var angle := lerpf(start_angle, end_angle, float(index) / float(maxi(2, steps)))
		points.append(center + Vector2(roundi(cos(angle) * radius), roundi(sin(angle) * radius)))
	polyline(canvas, points, color, width)

static func text(canvas: CanvasItem, value: String, origin: Vector2, color: Color, scale := 1) -> void:
	var cursor := Vector2i(roundi(origin.x), roundi(origin.y))
	for character in value.to_upper():
		if character == " ":
			cursor.x += 4 * scale
			continue
		var rows: Array = GLYPHS.get(character, [])
		for y in range(rows.size()):
			var row := str(rows[y])
			for x in range(row.length()):
				if row[x] == "1": rect(canvas, Rect2(cursor + Vector2i(x, y) * scale, Vector2i.ONE * scale), color)
		cursor.x += 4 * scale

static func damage_crack(canvas: CanvasItem, impact: Vector2, color: Color, ink: Color) -> void:
	var center := Vector2(roundi(impact.x), roundi(impact.y)).clamp(Vector2(-3, -2), Vector2(3, 2))
	line(canvas, Vector2(-3, -3), center, color)
	line(canvas, center, Vector2(3, 2), ink)
	line(canvas, center, center + Vector2(-2, 2), color)
