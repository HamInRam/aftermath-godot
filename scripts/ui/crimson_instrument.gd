extends "res://scripts/ui/compact_progress_bar.gd"

var vertical := false
var raging := false:
	set(next):
		if raging == next: return
		raging = next
		queue_redraw()

func _draw() -> void:
	var ratio := clampf(value / max_value, 0.0, 1.0)
	var red := Color("d10b32")
	if vertical:
		# A narrow blood ampoule: stepped shoulders, calibrated rails, bottom-up fill.
		draw_rect(Rect2(3,0,size.x-6,size.y),Color("101010"))
		draw_rect(Rect2(2,3,1,size.y-6),Color("eeeeee"))
		draw_rect(Rect2(size.x-3,3,1,size.y-6),Color("eeeeee"))
		draw_rect(Rect2(3,1,size.x-6,1),Color.WHITE)
		draw_rect(Rect2(3,size.y-2,size.x-6,1),Color.WHITE)
		var h := floorf((size.y-8)*ratio)
		draw_rect(Rect2(5,size.y-4-h,size.x-10,h),red)
		if h > 0:
			draw_rect(Rect2(5,size.y-4-h,size.x-10,1),Color.WHITE if raging else Color("ef3150"))
		for i in range(1,10):
			var y := floorf(4+(size.y-8)*float(i)/10.0)
			draw_rect(Rect2(0,y,3,1),Color("949494"))
			draw_rect(Rect2(size.x-3,y,3,1),Color("949494"))
		if raging:
			draw_rect(Rect2(0,0,2,3),red)
			draw_rect(Rect2(size.x-2,size.y-3,2,3),red)
	else:
		# Cartridge windows replace a generic progress stripe.
		var count := 18
		for i in count:
			var x := floorf(i*size.x/count)
			var color := (red if raging else Color.WHITE) if float(i)/count < ratio else Color("393939")
			draw_rect(Rect2(x+1,1,2,size.y-1),color)
			draw_rect(Rect2(x+1,0,1,1),color)
