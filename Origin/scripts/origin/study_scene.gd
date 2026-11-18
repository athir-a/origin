extends Control
## The study diorama. A tiny pixel world (320x180) in which the student reads, writes and thinks.
## Three camera angles share one animation timeline: SIDE, OVER-SHOULDER (back-top) and POV.
## The environment grows with the player: tier 0 (ground under the lamp) to tier 4 (the village study hall).

const VW := 320.0
const VH := 180.0

const SKIN := Color("c98a5e")
const SKIN_D := Color("a56b45")
const SKIN_L := Color("dba074")
const HAIR := Color("3a261e")
const HAIR_L := Color("5a3a2c")
const SHIRT := Color("efe0bd")
const SHIRT_D := Color("cdb98f")
const VEST := Color("7ba05f")
const VEST_D := Color("587c46")
const PANTS := Color("3a4272")
const PANTS_D := Color("2b3156")
const SHOE := Color("6b4326")
const OUT := Color("2a1b14")
const WOOD := Color("9a6b40")
const WOOD_D := Color("6b4528")
const WOOD_L := Color("c4925a")
const WOOD_DD := Color("48301d")
const PAGE := Color("f4ead0")
const PAGE_D := Color("d8c9a3")
const INK := Color("5a4636")

var tier := 0
var angle := "side"
var dark := 0.0
var warm := 0.0
var weather := "sunny"
var season := "autumn"
var book_col := Color("b0524a")
var mentor := false
var paused := false
var t := 0.0
var _scale := 4.0
var _off := Vector2.ZERO
var _blink := 0.0
var _rng_seed := 3


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func configure(opts: Dictionary) -> void:
	tier = opts.get("tier", tier)
	dark = opts.get("dark", dark)
	weather = opts.get("weather", weather)
	season = opts.get("season", season)
	book_col = opts.get("book_col", book_col)
	mentor = opts.get("mentor", mentor)
	warm = maxf(0.0, 1.0 - absf(dark - 0.45) * 4.0)
	queue_redraw()


func set_angle(a: String) -> void:
	angle = a
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	if not paused:
		t += delta
	queue_redraw()


# ---------------------------------------------------------------------------------------------
# Animation timeline
# ---------------------------------------------------------------------------------------------
## Returns the current activity: "read", "write", "think" and the page-turn amount 0..1
func _act() -> Dictionary:
	var c := fmod(t, 30.0)
	var act := "read"
	var turn := 0.0
	if c < 10.0:
		act = "read"
	elif c < 12.0:
		act = "read"
		turn = sin((c - 10.0) / 2.0 * PI)
	elif c < 22.0:
		act = "write"
	elif c < 25.0:
		act = "think"
	elif c < 28.0:
		act = "read"
	else:
		act = "read"
		turn = sin((c - 28.0) / 2.0 * PI) if c < 30.0 else 0.0
	var blink := fmod(t + 1.3, 4.2) < 0.14
	return {"act": act, "turn": turn, "blink": blink, "c": c}


# ---------------------------------------------------------------------------------------------
# Drawing helpers (virtual pixel coordinates)
# ---------------------------------------------------------------------------------------------
func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x, y, w, h), c)


func _px(x: float, y: float, c: Color) -> void:
	draw_rect(Rect2(x, y, 1, 1), c)


func _circle(x: float, y: float, r: float, c: Color) -> void:
	# pixel-ish filled circle via rows
	var yy := -r
	while yy <= r:
		var half := sqrt(maxf(0.0, r * r - yy * yy))
		draw_rect(Rect2(floorf(x - half), floorf(y + yy), ceilf(half * 2.0), 1), c)
		yy += 1.0


func _poly(pts: PackedVector2Array, c: Color) -> void:
	draw_colored_polygon(pts, c)


func _glow(x: float, y: float, r: float, c: Color, strength: float) -> void:
	var steps := 16
	for i in steps:
		var k := float(i) / steps
		var cc := c
		cc.a = strength * 0.032
		_circle(x, y, r * (1.0 - k), cc)


func _hash(x: float, y: float) -> float:
	var n := int(x * 127.1 + y * 311.7) & 0x7fffffff
	n = (n * 1103515245 + 12345) & 0x7fffffff
	return float(n % 1000) / 1000.0


func _sky_cols() -> Array:
	var top := Color("5fa8e6").lerp(Color("0b1030"), clampf(dark * 1.15, 0.0, 1.0))
	var bot := Color("c0e4f6").lerp(Color("2c3a74"), clampf(dark * 1.1, 0.0, 1.0))
	top = top.lerp(Color("5a4a8c"), warm * 0.6)
	bot = bot.lerp(Color("f4a470"), warm * 0.85)
	if weather == "rain" or weather == "cloudy":
		var g := 0.55 if weather == "rain" else 0.3
		top = top.lerp(Color("707a8a").darkened(dark * 0.6), g)
		bot = bot.lerp(Color("a2acb8").darkened(dark * 0.6), g)
	return [top, bot]


## Sky + distant village seen through a window or from outside.
func _sky(x: float, y: float, w: float, h: float, horizon: float = 0.72) -> void:
	var cols := _sky_cols()
	var bands := 8
	for i in bands:
		var k := float(i) / (bands - 1)
		_r(x, y + floorf(h * i / bands), w, ceilf(h / bands) + 1, (cols[0] as Color).lerp(cols[1], k))
	if dark > 0.55:
		for i in int(w * h / 90.0):
			var sx := x + _hash(i, 1) * w
			var sy := y + _hash(i, 2) * h * 0.6
			if _hash(i, 3) > 0.4:
				var tw := 0.5 + 0.5 * sin(t * 2.0 + i)
				_px(sx, sy, Color(1, 1, 0.9, clampf((dark - 0.5) * 3.0, 0, 1) * tw))
		_circle(x + w * 0.78, y + h * 0.22, minf(w, h) * 0.05, Color("f4f0d0"))
		_circle(x + w * 0.78 + 2, y + h * 0.22 - 1, minf(w, h) * 0.04, Color("e8e4c0"))
	elif weather == "sunny" and dark < 0.5:
		_glow(x + w * 0.2, y + h * 0.25, minf(w, h) * 0.4, Color("fff2a8"), 1.0 - dark)
		_circle(x + w * 0.2, y + h * 0.25, minf(w, h) * 0.07, Color("fff6c8"))
	# clouds
	var cc := Color(1, 1, 1, 0.85 - dark * 0.5)
	if weather in ["cloudy", "rain", "snow"]:
		cc = Color("c3c9d2")
		cc.a = 0.95
		cc = cc.darkened(dark * 0.55)
	for i in 3:
		var cx := x + fposmod(t * (3.0 + i) + i * w * 0.4, w + 40.0) - 20.0
		var cy := y + h * (0.12 + 0.14 * i)
		if cx > x and cx + 18 < x + w:
			_r(cx, cy, 18, 4, cc)
			_r(cx + 3, cy - 2, 11, 3, cc)
	# hills
	var gy := y + h * horizon
	var hillc := Color("5f8f52").lerp(Color("1e2f3a"), dark * 0.85)
	if season == "winter":
		hillc = Color("dfe8f2").lerp(Color("3a4666"), dark * 0.8)
	elif season == "autumn":
		hillc = Color("93904a").lerp(Color("2a2f30"), dark * 0.85)
	var hill2 := hillc.darkened(0.15)
	for i in int(w):
		var hh := 4.0 + sin(i * 0.09 + 1.0) * 3.0 + sin(i * 0.23) * 1.2
		_r(x + i, gy - hh, 1, hh + h - (gy - y), hill2 if i % 2 == 0 or true else hillc)
	# tiny village on the horizon, grows with tier
	var nh := 2 + tier * 2
	for i in nh:
		var hx := x + 8.0 + _hash(i, 9) * (w - 20.0)
		var hw := 5.0 + _hash(i, 4) * 3.0
		var hhgt := 4.0 + _hash(i, 5) * 2.0
		var wall := Color("a0795a").lerp(Color("2a2c44"), dark * 0.8)
		_r(hx, gy - hhgt - 3, hw, hhgt, wall)
		_r(hx - 1, gy - hhgt - 5, hw + 2, 2, Color("8a3f36").lerp(Color("2a2030"), dark * 0.8))
		if dark > 0.4:
			_px(hx + 1, gy - hhgt - 1, Color("ffd57a"))
	if tier >= 3:
		_r(x + w - 14, gy - 22, 1, 20, Color("4a4a5a").lerp(Color("141828"), dark))
		_px(x + w - 14, gy - 23, Color("ff4a4a") if fmod(t, 1.6) < 0.6 else Color("5a2020"))
	# weather
	if weather == "rain":
		for i in int(w / 4.0):
			var rx := x + fposmod(_hash(i, 7) * w + t * 20.0, w)
			var ry := y + fposmod(_hash(i, 8) * h + t * 130.0, h - 4.0)
			_r(rx, ry, 1, 4, Color(0.85, 0.92, 1.0, 0.55))
	elif weather == "snow":
		for i in int(w / 4.0):
			var sx := x + fposmod(_hash(i, 7) * w + sin(t + i) * 4.0, w - 1.0)
			var sy := y + fposmod(_hash(i, 8) * h + t * 14.0, h - 1.0)
			_r(sx, sy, 1, 1, Color(1, 1, 1, 0.9))


func _grass_ground(y0: float) -> void:
	var gc := Color("6b9c52").lerp(Color("17261f"), dark * 0.85)
	var gc2 := gc.darkened(0.12)
	if season == "winter":
		gc = Color("e4ecf4").lerp(Color("303e5a"), dark * 0.8)
		gc2 = gc.darkened(0.08)
	elif season == "autumn":
		gc = Color("a09c4c").lerp(Color("2a2a1e"), dark * 0.85)
		gc2 = gc.darkened(0.12)
	_r(0, y0, VW, VH - y0, gc)
	for i in 160:
		var gx := _hash(i, 21) * VW
		var gy := y0 + _hash(i, 22) * (VH - y0)
		_r(gx, gy, 2, 1, gc2)
		if i % 7 == 0:
			_px(gx, gy - 1, gc2)


func _night_tint() -> void:
	# overall dusk/night wash drawn last; warm lamps are drawn after it
	if dark > 0.05:
		_r(0, 0, VW, VH, Color(0.05, 0.08, 0.22, dark * 0.38))


func _vignette() -> void:
	for i in 8:
		var a := 0.05 * (1.0 - float(i) / 8.0) * 1.6
		_r(0, i, VW, 1, Color(0, 0, 0, a))
		_r(0, VH - 1 - i, VW, 1, Color(0, 0, 0, a))
		_r(i, 0, 1, VH, Color(0, 0, 0, a))
		_r(VW - 1 - i, 0, 1, VH, Color(0, 0, 0, a))


# ---------------------------------------------------------------------------------------------
# Props shared by views
# ---------------------------------------------------------------------------------------------
func _flame(x: float, y: float, s: float = 1.0) -> void:
	var fl := 0.6 + 0.4 * sin(t * 11.0) * sin(t * 7.3)
	_glow(x, y, 26.0 * s, Color("ffb55a"), 0.55 + dark * 0.9 + fl * 0.1)
	_r(x - 1 * s, y - 2 * s, 3 * s, 4 * s, Color("ff9a3a"))
	_r(x, y - 3 * s - fl, 1 * s + 1, 3 * s, Color("ffe08a"))
	_px(x, y - 4 * s - fl, Color("fff6c8"))


func _oil_lantern(x: float, y: float, s: float = 1.0) -> void:
	_r(x - 4 * s, y - 6 * s, 8 * s, 1 * s + 1, OUT)
	_r(x - 3 * s, y - 5 * s, 6 * s, 9 * s, Color("453a32"))
	_r(x - 2 * s, y - 4 * s, 4 * s, 7 * s, Color("ffd58a", 0.55))
	_r(x - 4 * s, y + 4 * s, 8 * s, 2 * s, OUT)
	_flame(x, y, 0.8 * s)


func _plant(x: float, y: float) -> void:
	_r(x - 3, y - 4, 7, 5, Color("b2643e"))
	_r(x - 3, y - 4, 7, 1, Color("d98a5a"))
	for i in 5:
		var a := -1.2 + i * 0.6 + sin(t * 1.2 + i) * 0.05
		_r(x + sin(a) * 6.0, y - 5 - cos(a) * 8.0, 2, 4, Color("4f9a4a"))
	_r(x - 1, y - 9, 3, 5, Color("6fba5a"))


func _book_stack(x: float, y: float) -> void:
	_r(x, y - 3, 14, 3, Color("4a6aa8"))
	_r(x + 1, y - 6, 12, 3, Color("b0524a"))
	_r(x + 2, y - 9, 10, 3, Color("d8a84a"))
	_r(x, y - 3, 14, 1, Color("6a8ac8"))


func _shelf(x: float, y: float, w: float, h: float, rows: int) -> void:
	_r(x, y, w, h, WOOD_DD)
	_r(x + 2, y + 2, w - 4, h - 4, Color("2e1f14"))
	var rh := (h - 4.0) / rows
	var cols := [Color("b0524a"), Color("4a6aa8"), Color("d8a84a"), Color("5f9a6a"), Color("8a5aa0"), Color("e0c8a0"), Color("c0703a")]
	for r in rows:
		var by := y + 2 + rh * (r + 1) - 2
		_r(x + 2, by, w - 4, 2, WOOD)
		var bx := x + 3
		var i := 0
		while bx < x + w - 6:
			var bw := 2.0 + floorf(_hash(r * 17 + i, bx) * 3.0)
			var bh := rh - 5.0 - floorf(_hash(i, r) * 3.0)
			_r(bx, by - bh, bw, bh, cols[(i + r * 3) % cols.size()])
			_px(bx, by - bh, Color(1, 1, 1, 0.25))
			bx += bw + 0.5
			i += 1
			if _hash(r, i) > 0.85:
				bx += 3


func _desk_lamp(x: float, y: float, face_left: bool = true) -> void:
	# electric lamp: arm + shade, warm cone
	var d := -1.0 if face_left else 1.0
	_r(x - 5, y - 2, 11, 2, Color("26343a"))
	_r(x - 1, y - 18, 2, 16, Color("3a4c52"))
	_poly(PackedVector2Array([Vector2(x - 1, y - 18), Vector2(x + d * 12, y - 22), Vector2(x + d * 14, y - 19), Vector2(x + d * 2, y - 15)]), Color("4f9a7a"))
	_glow(x + d * 10, y - 12, 34.0, Color("fff0c0"), 0.8 + dark * 0.8)
	_r(x + d * 8, y - 18, 4, 2, Color("fffae0"))


func _monitor_glow() -> Color:
	return Color(0.45, 0.85, 1.0)


func _screen_content(x: float, y: float, w: float, h: float) -> void:
	_r(x, y, w, h, Color("0f2a3a"))
	var lines := int(h / 4.0) - 1
	var scroll := fmod(t * 4.0, 8.0)
	for i in lines:
		var ly := y + 2 + i * 4 - scroll * 0.0
		var indent := floorf(_hash(i + floorf(t * 0.5), 3) * 4.0) * 3.0
		var lw := 6.0 + _hash(i + floorf(t * 0.5), 5) * (w - 14.0 - indent)
		var col: Color = [Color("6fe0b0"), Color("7ab8ff"), Color("ffd27a"), Color("e89ad8")][int(_hash(i, floorf(t * 0.5)) * 4.0) % 4]
		_r(x + 2 + indent, ly, lw, 1, col)
	if fmod(t, 1.0) < 0.5:
		_r(x + w - 8, y + h - 5, 3, 2, Color("ffffff"))


# ---------------------------------------------------------------------------------------------
# Character (side view)
# ---------------------------------------------------------------------------------------------
## Seated student in profile (facing right). `cx` is the hip x, `hip` the hip y.
## `hand` is where the working hand rests (book, notebook or keyboard).
func _student_side(cx: float, hip: float, a: Dictionary, seated_ground: bool, hand_target: Vector2) -> void:
	var act: String = a.act
	var breathe := sin(t * 1.8) * 0.5
	var lean := 3.0
	var head_dy := 2.0
	if act == "write":
		lean = 5.0
		head_dy = 4.0
	elif act == "think":
		lean = -1.0
		head_dy = -3.0 + sin(t * 3.0) * 0.6
	else:
		lean = 3.0 + sin(t * 0.7) * 0.6
		head_dy = 2.0
	# legs
	if seated_ground:
		_r(cx - 9, hip - 4, 24, 7, PANTS)
		_r(cx - 9, hip - 4, 24, 1, PANTS_D)
		_r(cx + 9, hip - 9, 10, 10, PANTS)
		_r(cx + 9, hip - 9, 1, 10, PANTS_D)
		_r(cx + 13, hip + 1, 9, 4, SHOE)
		_r(cx + 13, hip + 1, 9, 1, Color("8a5a36"))
		_r(cx - 11, hip, 12, 4, SHOE)
	else:
		_r(cx - 6, hip - 5, 22, 7, PANTS)
		_r(cx - 6, hip - 5, 22, 1, PANTS_D)
		_r(cx + 12, hip - 3, 7, 19, PANTS)
		_r(cx + 12, hip - 3, 1, 19, PANTS_D)
		_r(cx + 12, hip + 15, 11, 5, SHOE)
		_r(cx + 12, hip + 15, 11, 1, Color("8a5a36"))
	# torso, leaning forward from the hips (parallelogram)
	var sy := hip - 29 + breathe
	var lx := lean
	_poly(PackedVector2Array([Vector2(cx - 7, hip - 1), Vector2(cx + 8, hip - 1), Vector2(cx + 9 + lx, sy), Vector2(cx - 6 + lx, sy)]), SHIRT)
	_poly(PackedVector2Array([Vector2(cx - 5, hip - 2), Vector2(cx + 7, hip - 2), Vector2(cx + 8 + lx, sy + 3), Vector2(cx - 5 + lx, sy + 3)]), VEST)
	_poly(PackedVector2Array([Vector2(cx - 5, hip - 2), Vector2(cx - 3, hip - 2), Vector2(cx - 3 + lx, sy + 3), Vector2(cx - 5 + lx, sy + 3)]), VEST_D)
	_r(cx - 6, hip - 3, 14, 2, PANTS_D)
	# satchel strap + bag at the back
	_poly(PackedVector2Array([Vector2(cx - 6 + lx, sy + 1), Vector2(cx - 2 + lx, sy + 1), Vector2(cx + 8, hip - 8), Vector2(cx + 4, hip - 8)]), Color("6b4326"))
	_r(cx - 11, hip - 15, 8, 10, Color("7a4e2c"))
	_r(cx - 11, hip - 15, 8, 2, Color("5a3a20"))
	_r(cx - 8, hip - 12, 2, 2, Color("d8b04a"))
	# neck + head
	var hx := cx - 1 + lx
	var hy := hip - 47 + head_dy + breathe
	_r(hx + 3, hy + 13, 5, 6, SKIN_D)
	_r(hx, hy + 2, 14, 13, SKIN)
	_r(hx + 1, hy + 1, 12, 1, SKIN)
	_r(hx + 12, hy + 6, 3, 3, SKIN)
	_r(hx + 14, hy + 7, 1, 2, SKIN_D)
	_r(hx + 11, hy + 11, 3, 1, Color("a15a46"))
	_r(hx, hy + 13, 14, 2, SKIN_D)
	# hair
	_r(hx - 2, hy - 2, 16, 6, HAIR)
	_r(hx - 2, hy + 2, 6, 11, HAIR)
	_r(hx + 8, hy - 3, 5, 3, HAIR)
	_r(hx + 1, hy - 3, 6, 2, HAIR_L)
	_r(hx + 11, hy + 3, 2, 2, HAIR)
	# ear, eye, brow
	_r(hx + 4, hy + 7, 3, 4, SKIN_D)
	if a.blink:
		_r(hx + 9, hy + 7, 3, 1, OUT)
	else:
		var look_down := 1.0 if act != "think" else 0.0
		_r(hx + 9, hy + 6 + look_down, 2, 3, OUT)
		_px(hx + 9, hy + 6 + look_down, Color.WHITE)
	_r(hx + 8, hy + 4, 4, 1, HAIR)
	# arm: shoulder -> elbow -> hand
	var shoulder := Vector2(cx + 3 + lx, sy + 4)
	var hnd := hand_target
	if act == "write":
		hnd += Vector2(sin(t * 5.0) * 1.5, sin(t * 9.0) * 0.6)
	elif act == "think":
		hnd = Vector2(hx + 11, hy + 12 + sin(t * 2.0) * 0.5)
	var mid := (shoulder + hnd) * 0.5
	var elbow := mid + Vector2(-3.0, 7.0)
	draw_line(shoulder, elbow, SHIRT_D, 5.0)
	draw_line(elbow, hnd, SHIRT, 4.0)
	_r(hnd.x - 2, hnd.y - 2, 5, 4, SKIN)
	_px(hnd.x + 2, hnd.y - 2, SKIN_L)


func _fireflies(x: float, y: float, w: float, h: float) -> void:
	if w <= 0.0:
		return
	for i in 10:
		var fx := x + _hash(i, 31) * w + sin(t * 0.8 + i) * 10.0
		var fy := y + _hash(i, 32) * h + cos(t * 0.7 + i * 1.7) * 6.0
		var b := 0.5 + 0.5 * sin(t * 2.0 + i * 3.0)
		_glow(fx, fy, 5.0, Color("fff0a0"), b)
		_px(fx, fy, Color(1, 1, 0.7, b))


## A small open book seen from the side: a slab with a gentle V and fluttering page on a turn.
func _book_side(x: float, y: float, w: float, a: Dictionary) -> void:
	_r(x, y, w, 3, book_col)
	_r(x, y + 2, w, 1, book_col.darkened(0.3))
	_r(x + 1, y - 2, w * 0.5 - 1, 2, PAGE)
	_r(x + w * 0.5 + 1, y - 2, w * 0.5 - 2, 2, PAGE)
	_r(x + w * 0.5 - 1, y - 1, 2, 2, PAGE_D)
	if a.turn > 0.05:
		var f: float = a.turn
		var px := x + w * 0.5
		_poly(PackedVector2Array([Vector2(px, y - 2), Vector2(px + w * 0.5 * cos(f * PI), y - 2 - 7 * sin(f * PI)), Vector2(px + w * 0.5 * cos(f * PI) * 0.95, y - 1 - 5 * sin(f * PI)), Vector2(px, y - 1)]), PAGE)


# ---------------------------------------------------------------------------------------------
# View: SIDE
# ---------------------------------------------------------------------------------------------
func _view_side() -> void:
	var a := _act()
	if tier == 0:
		_sky(0, 0, VW, 140, 0.84)
		_grass_ground(124)
		# fence + Tiya watching
		for i in 7:
			_r(250 + i * 10, 112, 3, 14, WOOD_D)
			_r(251 + i * 10, 113, 1, 12, WOOD)
		_r(248, 116, 72, 2, WOOD_D)
		_r(248, 121, 72, 2, WOOD_D)
		var peek := fmod(t, 45.0)
		if peek > 14.0 and peek < 38.0:
			var rise := minf(1.0, minf((peek - 14.0) * 0.7, (38.0 - peek) * 0.7))
			var ty := 123.0 - 11.0 * rise
			_r(270, ty, 10, 12, Color("e6b84d"))
			_r(271, ty - 8, 8, 9, SKIN_L)
			_r(270, ty - 10, 10, 3, HAIR)
			_r(268, ty - 9, 3, 3, Color("f2d24a"))
			_r(279, ty - 9, 3, 3, Color("f2d24a"))
			if not a.blink:
				_r(272, ty - 4, 2, 2, OUT)
				_r(276, ty - 4, 2, 2, OUT)
			if peek > 24.0 and peek < 28.0:
				_r(283, ty - 2 + sin(t * 12.0) * 2.0, 3, 3, SKIN_L)
		# lamp post
		_r(220, 36, 4, 100, Color("2e2a30"))
		_r(217, 130, 10, 6, Color("3a363c"))
		_r(219, 60, 6, 2, Color("3a363c"))
		_oil_lantern(222, 34, 1.2)
		_glow(222, 134, 90.0, Color("ffc470"), 0.35 + dark * 0.7)
		# satchel left behind
		_r(52, 118, 14, 10, Color("7a4e2c"))
		_r(52, 118, 14, 3, Color("5a3a20"))
		_r(58, 121, 3, 3, Color("d8b04a"))
		# a cat curled up near the student
		_r(74, 124, 12, 5, Color("c98a4a"))
		_r(84, 121, 5, 5, Color("c98a4a"))
		_px(85, 120, Color("c98a4a"))
		_px(88, 120, Color("c98a4a"))
		_r(73, 126, 4, 2, Color("f0e0c0"))
		_student_side(112, 128, a, true, Vector2(130, 120))
		_book_side(122, 120, 22, a)
		# hen strolling
		var hx := fposmod(t * 6.0, 380.0) - 30.0
		_r(hx, 126, 8, 5, Color("f4f0e6"))
		_r(hx + 6, 123, 4, 4, Color("f4f0e6"))
		_px(hx + 9, 124, Color("e8892a"))
		_r(hx + 7, 122, 2, 1, Color("c93a3a"))
		_r(hx + 1, 131, 1, 2, Color("e8892a"))
		_r(hx + 5, 131, 1, 2, Color("e8892a"))
		if dark > 0.4:
			_fireflies(0, 90, VW, 50)
	else:
		_room_side(a)
	_night_tint()
	if tier == 0:
		_flame(222, 34, 1.0)
	_vignette()


func _room_side(a: Dictionary) -> void:
	# wall
	var wall := Color("b58d62").lerp(Color("5a4636"), dark * 0.5)
	if tier >= 2:
		wall = Color("c9b08a").lerp(Color("5a4a3a"), dark * 0.5)
	if tier >= 4:
		wall = Color("a8b8a0").lerp(Color("3c4a48"), dark * 0.5)
	_r(0, 0, VW, 132, wall)
	for i in 20:
		_r(i * 16, 0, 1, 132, Color(0, 0, 0, 0.09))
	if tier >= 2:
		_r(0, 100, VW, 3, Color("8a5e38"))
	# floor
	_r(0, 132, VW, 48, Color("7a5230").lerp(Color("2a1c12"), dark * 0.55))
	for i in 10:
		_r(0, 132 + i * 5, VW, 1, Color(0, 0, 0, 0.18))
	_r(0, 130, VW, 3, WOOD_DD)
	# window
	var wx := 192.0
	var wy := 22.0
	_r(wx - 3, wy - 3, 70, 64, WOOD_DD)
	_sky(wx, wy, 64, 58, 0.78)
	_r(wx + 31, wy, 2, 58, WOOD_DD)
	_r(wx, wy + 28, 64, 2, WOOD_DD)
	_r(wx - 5, wy + 58, 74, 4, WOOD)
	_r(wx - 5, wy - 4, 8, 64, Color("a85a52"))
	_r(wx + 62, wy - 4, 8, 64, Color("a85a52"))
	# peeking Tiya in the window now and then
	var peek := fmod(t, 50.0)
	if peek > 20.0 and peek < 32.0:
		var rise := minf(1.0, minf((peek - 20.0), (32.0 - peek)))
		var ty := wy + 58.0 - 12.0 * rise
		_r(wx + 16, ty, 10, 10, SKIN_L)
		_r(wx + 15, ty - 2, 12, 4, HAIR)
		_r(wx + 12, ty, 3, 3, Color("f2d24a"))
		_r(wx + 27, ty, 3, 3, Color("f2d24a"))
	# bookshelves (wall)
	if tier >= 1:
		_shelf(18, 40, 60, 54 if tier >= 2 else 40, 3 if tier >= 2 else 2)
	if tier >= 4:
		_shelf(84, 30, 44, 64, 4)
		for i in 12:
			var lx := 10.0 + i * 26.0
			var ly := 12.0 + sin(i * 0.9) * 3.0
			_px(lx, ly, Color("2a2a2a"))
			_r(lx, ly + 1, 2, 2, Color("ffd88a") if (i + int(t * 2)) % 3 != 0 else Color("ffb85a"))
		_r(150, 10, 18, 18, WOOD_DD)
		_circle(159, 19, 7, Color("f4ead0"))
		draw_line(Vector2(159, 19), Vector2(159 + cos(t * 0.1) * 5, 19 + sin(t * 0.1) * 5), OUT, 1.0)
		_circle(159, 19, 1, OUT)
	# desk
	_r(130, 104, 170, 6, WOOD_L)
	_r(130, 104, 170, 1, Color("e0b680"))
	_r(130, 110, 170, 4, WOOD)
	_r(138, 114, 6, 24, WOOD_D)
	_r(286, 114, 6, 24, WOOD_D)
	_r(132, 138, 164, 3, Color(0, 0, 0, 0.18))
	# chair
	var cx := 112.0
	_r(cx - 12, 90, 4, 30, WOOD_D)
	_r(cx - 12, 118, 36, 4, WOOD)
	_r(cx - 11, 122, 4, 18, WOOD_D)
	_r(cx + 18, 122, 4, 18, WOOD_D)
	# desk items
	if tier == 1:
		_oil_lantern(272, 98, 1.0)
	else:
		_desk_lamp(274, 104, true)
	if tier >= 3:
		_book_stack(238, 104)
		# monitor seen from the side + keyboard
		_r(214, 76, 6, 26, Color("2e3a44"))
		_r(204, 76, 12, 26, Color("1d2a33"))
		_r(206, 78, 6, 22, _monitor_glow().darkened(0.2 - dark * 0.2))
		_r(210, 100, 14, 4, Color("2e3a44"))
		_glow(206, 90, 40.0, _monitor_glow(), 0.45 + dark * 0.6)
		_r(150, 101, 36, 3, Color("39454d"))
		_r(150, 101, 36, 1, Color("5a6872"))
	else:
		_book_stack(236, 104)
	if tier >= 4:
		_r(248, 92, 6, 10, Color("2e3a44"))
		_plant(262, 104)
	elif tier >= 2:
		_plant(290, 104)
	# student at the desk
	var hand := Vector2(164, 99)
	if tier >= 3:
		hand = Vector2(168, 99)
		if a.act == "write":
			hand += Vector2(sin(t * 12.0) * 1.2, sin(t * 17.0) * 0.8)
	elif a.act == "write":
		hand = Vector2(170, 99)
	else:
		hand = Vector2(160, 99)
	_student_side(cx, 118, a, false, hand)
	if tier < 3:
		_book_side(144, 101, 30, a)
		if a.act == "write":
			_r(hand.x + 2, hand.y - 7, 1, 8, Color("e8c040"))
	if dark > 0.35 and tier >= 1:
		pass


# ---------------------------------------------------------------------------------------------
# View: OVER THE SHOULDER (behind and above)
# ---------------------------------------------------------------------------------------------
func _view_top() -> void:
	var a := _act()
	var act: String = a.act
	if tier == 0:
		_grass_ground(0)
		# worn dirt circle under the lamp
		_circle(166, 60, 62, Color("8a6a46").lerp(Color("1a1612"), dark * 0.8))
		_circle(166, 60, 54, Color("9a7a52").lerp(Color("201a14"), dark * 0.8))
		for i in 30:
			_px(110 + _hash(i, 51) * 112, 12 + _hash(i, 52) * 96, Color("7a5a3a"))
		# lamp base far right/top
		_circle(250, 30, 8, Color("3a363c"))
		_circle(250, 30, 5, Color("2e2a30"))
		_flame(250, 28, 0.9)
		_glow(214, 60, 120.0, Color("ffc470"), 0.4 + dark * 0.8)
		# satchel
		_r(236, 96, 22, 18, Color("7a4e2c"))
		_r(236, 96, 22, 5, Color("5a3a20"))
		_r(244, 101, 6, 5, Color("d8b04a"))
		# stones & tufts
		_r(70, 40, 8, 5, Color("8a8a90"))
		_r(86, 110, 7, 4, Color("7a7a80"))
		# book on lap
		_book_open_top(166, 76, 60, 38, a, 0.0)
	else:
		_room_floor_top()
		_desk_top(a)
	# character from behind
	_student_back(a)
	_night_tint()
	if tier == 0:
		_flame(250, 28, 0.9)
	_vignette()


func _room_floor_top() -> void:
	var floor_c := Color("7a5230").lerp(Color("2a1c12"), dark * 0.6)
	if tier >= 4:
		floor_c = Color("6a5a48").lerp(Color("241e18"), dark * 0.6)
	_r(0, 0, VW, VH, floor_c)
	for i in 14:
		_r(0, i * 13, VW, 1, Color(0, 0, 0, 0.2))
	for i in 24:
		_r(_hash(i, 61) * VW, floorf(_hash(i, 62) * 14) * 13, 1, 13, Color(0, 0, 0, 0.14))
	# rug
	_r(40, 120, 240, 60, Color("8a4a46").lerp(Color("2a1816"), dark * 0.6))
	_r(44, 124, 232, 52, Color("a85a50").lerp(Color("301c1a"), dark * 0.6))
	for i in 12:
		_r(50 + i * 19, 128, 8, 2, Color("e0b878", 0.5))


func _desk_top(a: Dictionary) -> void:
	# desk top as seen from above and behind
	_r(30, 6, 260, 104, WOOD_DD)
	_r(33, 9, 254, 98, WOOD)
	for i in 8:
		_r(33, 14 + i * 12, 254, 1, Color(0, 0, 0, 0.12))
	_r(33, 9, 254, 2, WOOD_L)
	# wall/shelves at the back
	_r(30, 0, 260, 8, Color("5a3a22"))
	# items on desk
	if tier == 1:
		_oil_lantern_top(252, 34)
		_book_stack_top(60, 30)
	else:
		_desk_lamp_top(262, 36)
		_book_stack_top(56, 30)
		_plant_top(262, 80)
	if tier >= 3:
		# monitor from behind, tall dark slab + stand, glow spill on desk and keyboard
		_glow(158, 60, 90.0, _monitor_glow(), 0.4 + dark * 0.7)
		_r(110, 14, 96, 38, Color("1d2a33"))
		_r(112, 16, 92, 34, Color("26343e"))
		_r(150, 52, 16, 8, Color("2e3a44"))
		_r(104, 12, 108, 2, Color("39454d"))
		# status led
		_r(160, 47, 3, 1, Color("5fe0a0") if fmod(t, 3.0) < 2.5 else Color("1a3a2a"))
		# keyboard
		_r(122, 70, 72, 20, Color("39454d"))
		_r(123, 71, 70, 18, Color("2a343b"))
		for r in 4:
			for c in 12:
				var lit: bool = _hash(r * 12 + c, floorf(t * 6.0)) > 0.92 and a.act == "write"
				_r(125 + c * 5.7, 73 + r * 4.2, 4, 3, Color("8ab0c0") if lit else Color("46535c"))
		# notebook to the right
		_book_open_top(232, 76, 40, 26, a, 0.15, true)
		if tier >= 4:
			_r(70, 56, 30, 18, Color("2e3a44"))
			_r(72, 58, 26, 14, _monitor_glow().darkened(0.3))
	else:
		_book_open_top(158, 60, 76, 46, a, 0.0)
		# pencil cup
		_r(214, 22, 8, 10, Color("6a8aa8"))
		_r(215, 18, 1, 5, Color("e8c040"))
		_r(218, 17, 1, 6, Color("c0503a"))


func _oil_lantern_top(x: float, y: float) -> void:
	_circle(x, y, 7, Color("453a32"))
	_circle(x, y, 4, Color("ffd58a"))
	_glow(x, y, 60.0, Color("ffb55a"), 0.7 + dark * 0.9)


func _desk_lamp_top(x: float, y: float) -> void:
	_circle(x, y, 8, Color("26343a"))
	_circle(x - 6, y + 4, 8, Color("4f9a7a"))
	_circle(x - 6, y + 4, 5, Color("fff6d0"))
	_glow(x - 12, y + 10, 76.0, Color("fff0c0"), 0.8 + dark * 0.9)


func _plant_top(x: float, y: float) -> void:
	_circle(x, y, 7, Color("b2643e"))
	for i in 7:
		var an := i * 0.9 + sin(t + i) * 0.04
		_r(x + cos(an) * 6.0 - 2, y + sin(an) * 6.0 - 2, 4, 4, Color("4f9a4a"))
	_circle(x, y, 3, Color("6fba5a"))


func _book_stack_top(x: float, y: float) -> void:
	_r(x, y, 26, 18, Color("4a6aa8"))
	_r(x + 2, y + 2, 24, 16, Color("b0524a"))
	_r(x + 4, y + 4, 22, 14, Color("d8a84a"))
	_r(x + 4, y + 4, 22, 1, Color(1, 1, 1, 0.3))


func _book_open_top(cx: float, cy: float, w: float, h: float, a: Dictionary, skew: float, notebook: bool = false) -> void:
	var x := cx - w * 0.5
	var y := cy - h * 0.5
	_r(x - 2, y - 2, w + 4, h + 4, book_col if not notebook else Color("3a6a8a"))
	_r(x, y, w * 0.5 - 1, h, PAGE)
	_r(x + w * 0.5 + 1, y, w * 0.5, h, PAGE)
	_r(x + w * 0.5 - 1, y, 2, h, PAGE_D)
	# text lines
	var lines := int(h / 5.0) - 1
	for i in lines:
		var ly := y + 4 + i * 5
		var lw := w * 0.5 - 8.0
		var l_w := lw * (0.7 + 0.3 * _hash(i, 71))
		_r(x + 3, ly, l_w, 1, INK)
		var r_w := lw * (0.6 + 0.4 * _hash(i, 72))
		if a.act == "write" or notebook:
			# right page is being filled in
			var prog := fmod(a.c - 12.0, 10.0) / 10.0 if a.act == "write" else 1.0
			if notebook or float(i) / maxf(1.0, lines) < prog:
				_r(x + w * 0.5 + 4, ly, r_w * (1.0 if not (a.act == "write" and float(i + 1) / lines > prog) else 0.5), 1, Color("3a4a8a"))
		else:
			_r(x + w * 0.5 + 4, ly, r_w, 1, INK)
	# reading highlight: moving soft marker
	if a.act == "read" and not notebook:
		var hi := fmod(t * 0.6, float(maxi(lines, 1)))
		_r(x + 2, y + 3 + floorf(hi) * 5, w * 0.5 - 6, 3, Color(1, 0.9, 0.4, 0.28))
	# page turn flap
	if a.turn > 0.05 and not notebook:
		var f: float = a.turn
		var px := x + w * 0.5
		_poly(PackedVector2Array([Vector2(px, y), Vector2(px + (w * 0.5) * cos(f * PI), y - 3 * f), Vector2(px + (w * 0.5) * cos(f * PI), y + h - 3 * f), Vector2(px, y + h)]), PAGE)
		_r(px + (w * 0.5) * cos(f * PI) - 1, y - 3 * f, 1, h, PAGE_D)


func _student_back(a: Dictionary) -> void:
	var act: String = a.act
	var br := sin(t * 1.8) * 0.6
	var nod := 0.0
	var tilt_x := 0.0
	if act == "write":
		nod = 3.0
		tilt_x = sin(t * 0.8) * 1.2
	elif act == "think":
		nod = -3.0 + sin(t * 3.0) * 0.4
		tilt_x = -3.0
	else:
		nod = 1.0 + sin(t * 0.7) * 0.5
		tilt_x = sin(t * 0.55) * 1.0
	var cx := 160.0
	var base := 192.0 if tier > 0 else 186.0
	# shoulders / back
	_r(cx - 54, base - 48 + br, 108, 56, SHIRT_D)
	_r(cx - 44, base - 52 + br, 88, 12, SHIRT)
	_r(cx - 38, base - 42 + br, 76, 56, VEST)
	_r(cx - 38, base - 42 + br, 76, 2, VEST_D)
	_r(cx - 1, base - 42 + br, 2, 52, VEST_D)
	# collar
	_r(cx - 14, base - 54 + br, 28, 6, SHIRT)
	# satchel strap across back
	_poly(PackedVector2Array([Vector2(cx - 36, base - 44 + br), Vector2(cx - 26, base - 44 + br), Vector2(cx + 38, base + 8), Vector2(cx + 28, base + 8)]), Color("6b4326"))
	_r(cx + 20, base - 6, 3, 3, Color("d8b04a"))
	# arms reaching forward to the desk
	var lh := Vector2(cx - 22, 84)
	var rh := Vector2(cx + 22, 84)
	if tier >= 3:
		lh = Vector2(cx - 24, 86 + (sin(t * 11.0) * 1.2 if act == "write" else 0.0))
		rh = Vector2(cx + 22, 86 + (sin(t * 13.0 + 1.0) * 1.2 if act == "write" else 0.0))
	elif act == "write":
		rh = Vector2(cx + 14 + sin(t * 5.0) * 2.0, 76 + sin(t * 9.0) * 1.2)
		lh = Vector2(cx - 20, 78)
	elif a.turn > 0.05:
		rh = Vector2(cx + 30 - 30 * a.turn, 70 + 4 * a.turn)
	var ls := Vector2(cx - 44, base - 40 + br)
	var rs := Vector2(cx + 44, base - 40 + br)
	if tier == 0:
		lh = Vector2(cx - 26, 96)
		rh = Vector2(cx + 26, 96)
		if act == "write":
			rh = Vector2(cx + 12 + sin(t * 5.0) * 2.0, 92)
	var le := Vector2(cx - 54, 124)
	var re := Vector2(cx + 54, 124)
	draw_line(ls, le, SHIRT_D, 12.0)
	draw_line(le, lh + Vector2(0, 8), SHIRT, 10.0)
	draw_line(rs, re, SHIRT_D, 12.0)
	draw_line(re, rh + Vector2(0, 8), SHIRT, 10.0)
	_r(lh.x - 5, lh.y - 4, 10, 10, SKIN)
	_r(lh.x - 5, lh.y - 4, 10, 2, SKIN_L)
	_r(rh.x - 5, rh.y - 4, 10, 10, SKIN)
	_r(rh.x - 5, rh.y - 4, 10, 2, SKIN_L)
	if act == "write" and tier < 3:
		draw_line(rh + Vector2(1, -2), rh + Vector2(-1, -12), Color("e8c040"), 2.0)
		_px(rh.x, rh.y - 13, Color("e89aa0"))
	# head from behind
	var hx := cx + tilt_x
	var hy := base - 78 + nod + br
	_r(hx - 16, hy + 20, 32, 6, SKIN_D)
	_circle(hx, hy + 6, 21, HAIR)
	_circle(hx - 4, hy + 2, 15, HAIR_L)
	# hair texture
	for i in 18:
		var ang := -2.6 + i * 0.3
		_r(hx + cos(ang) * 14.0 - 1, hy + 6 + sin(ang) * 12.0, 2, 3, HAIR_L if i % 2 == 0 else Color("2a1a14"))
	_r(hx - 21, hy + 8, 3, 8, SKIN_D)
	_r(hx + 18, hy + 8, 3, 8, SKIN_D)
	_r(hx - 6, hy + 22, 12, 5, SKIN)
	# pencil behind the ear
	_r(hx + 17, hy + 3, 2, 10, Color("e8c040"))
	if mentor:
		# little Asha beside, shown as a hint
		_r(cx + 66, base - 20, 30, 40, Color("e07f9a"))
		_circle(cx + 80, base - 28, 14, Color("2a1a14"))
		_r(cx + 66, base - 24, 10, 14, Color("2a1a14"))


# ---------------------------------------------------------------------------------------------
# View: POV
# ---------------------------------------------------------------------------------------------
func _view_pov() -> void:
	var a := _act()
	var act: String = a.act
	var sway := Vector2(sin(t * 0.6) * 1.2, sin(t * 1.1) * 0.8)
	var look := 0.0
	if act == "think":
		look = lerpf(0.0, -18.0, clampf((a.c - 22.0) * 2.0, 0.0, 1.0))
		if a.c > 24.0:
			look = lerpf(-18.0, 0.0, clampf((a.c - 24.0), 0.0, 1.0))
	var off := Vector2(sway.x, sway.y - look * 0.0)
	# whole scene shifted by look (looking up moves scene down)
	var shift := Vector2(sway.x, sway.y + (-look))
	draw_set_transform(_off + shift * _scale, 0.0, Vector2(_scale, _scale))
	if tier == 0:
		_sky(-8, -30, VW + 16, 170, 0.8)
		_grass_ground(106)
		# fence far away + Tiya
		for i in 12:
			_r(30 + i * 22, 96, 3, 13, WOOD_D)
		_r(28, 100, 270, 2, WOOD_D)
		var peek := fmod(t, 45.0)
		if peek > 14.0 and peek < 38.0:
			var rise := minf(1.0, minf((peek - 14.0) * 0.7, (38.0 - peek) * 0.7))
			var ty := 100.0 - 9.0 * rise
			_r(86, ty, 8, 10, Color("e6b84d"))
			_r(87, ty - 7, 7, 8, SKIN_L)
			_r(86, ty - 8, 9, 3, HAIR)
			_r(84, ty - 7, 3, 3, Color("f2d24a"))
			_r(94, ty - 7, 3, 3, Color("f2d24a"))
		# lamp post close on the right
		_r(262, -6, 6, 118, Color("2e2a30"))
		_r(258, 106, 14, 8, Color("3a363c"))
		_oil_lantern(265, -6, 2.0)
		_glow(265, 108, 110.0, Color("ffc470"), 0.3 + dark * 0.7)
		if dark > 0.4:
			_fireflies(10, 50, 280, 60)
	else:
		_pov_room()
	# reset to non-shifted for hands/UI-layer: hands also sway but less
	draw_set_transform(_off + sway * 0.4 * _scale, 0.0, Vector2(_scale, _scale))
	_pov_hands(a)
	draw_set_transform(_off, 0.0, Vector2(_scale, _scale))
	_night_tint()
	if tier == 0:
		pass
	_vignette()
	# eyelid blink
	if a.blink:
		_r(0, 0, VW, 34, Color(0.04, 0.03, 0.03, 0.92))
		_r(0, VH - 34, VW, 34, Color(0.04, 0.03, 0.03, 0.92))
	elif act == "think":
		pass


func _pov_room() -> void:
	var wall := Color("b58d62").lerp(Color("5a4636"), dark * 0.5)
	if tier >= 2:
		wall = Color("c9b08a").lerp(Color("5a4a3a"), dark * 0.5)
	if tier >= 4:
		wall = Color("a8b8a0").lerp(Color("3c4a48"), dark * 0.5)
	_r(-8, -30, VW + 16, 170, wall)
	for i in 22:
		_r(-8 + i * 15, -30, 1, 170, Color(0, 0, 0, 0.09))
	# window left
	_r(14, 4, 84, 70, WOOD_DD)
	_sky(17, 7, 78, 64, 0.78)
	_r(55, 7, 2, 64, WOOD_DD)
	_r(17, 38, 78, 2, WOOD_DD)
	_r(10, 74, 92, 5, WOOD)
	_r(10, 0, 8, 76, Color("a85a52"))
	_r(94, 0, 8, 76, Color("a85a52"))
	# shelf right
	_shelf(204, 4, 88, 56 if tier < 2 else 68, 3 if tier < 2 else 4)
	if tier >= 4:
		for i in 12:
			_px(14 + i * 26, 2 + sin(i) * 2, Color("ffd88a") if (i + int(t * 2)) % 3 else Color("ffb85a"))
	# desk plane
	_r(-8, 98, VW + 16, 90, WOOD)
	_r(-8, 98, VW + 16, 3, WOOD_L)
	for i in 6:
		_r(-8, 106 + i * 12, VW + 16, 1, Color(0, 0, 0, 0.14))
	# lamp on the desk
	if tier == 1:
		_oil_lantern(262, 94, 1.5)
	else:
		_desk_lamp(268, 98, true)
	if tier >= 3:
		# monitor in front
		_r(100, 26, 124, 76, Color("1d2a33"))
		_r(104, 30, 116, 66, Color("0f2a3a"))
		_screen_content(106, 32, 112, 62)
		_glow(162, 62, 100.0, _monitor_glow(), 0.35 + dark * 0.6)
		_r(150, 100, 24, 6, Color("2e3a44"))
		_r(140, 104, 44, 4, Color("39454d"))
	else:
		_book_stack(32, 98)
		if tier >= 2:
			_plant(66, 98)
		# pencil cup
		_r(222, 90, 9, 12, Color("6a8aa8"))
		_r(224, 84, 1, 7, Color("e8c040"))
		_r(228, 83, 1, 8, Color("c0503a"))


func _pov_hands(a: Dictionary) -> void:
	var act: String = a.act
	if tier >= 3:
		# keyboard & typing hands
		_r(90, 138, 140, 30, Color("39454d"))
		_r(92, 140, 136, 26, Color("2a343b"))
		for r in 4:
			for c in 18:
				var lit := _hash(r * 18 + c, floorf(t * 7.0)) > 0.93 and act == "write"
				_r(94 + c * 7.4, 143 + r * 5.8, 5, 4, Color("8ab0c0") if lit else Color("46535c"))
		var ty := 142.0 + (sin(t * 12.0) * 2.0 if act == "write" else 0.0)
		var ty2 := 142.0 + (sin(t * 14.0 + 1.0) * 2.0 if act == "write" else 0.0)
		_hand_pov(120, ty + 10, false)
		_hand_pov(200, ty2 + 10, true)
		# notebook corner at left bottom
		_r(10, 150, 64, 36, book_col)
		_r(13, 153, 58, 30, PAGE)
		for i in 5:
			_r(16, 158 + i * 5, 40 + _hash(i, 3) * 12, 1, INK)
	else:
		# open book in perspective, hands on its sides
		var bx := 66.0
		var by := 122.0
		var wv := 188.0
		_poly(PackedVector2Array([Vector2(bx - 8, by + 70), Vector2(bx + 6, by - 10), Vector2(bx + wv - 6, by - 10), Vector2(bx + wv + 8, by + 70)]), book_col)
		_poly(PackedVector2Array([Vector2(bx - 3, by + 66), Vector2(bx + 8, by - 6), Vector2(bx + wv / 2 - 1, by - 6), Vector2(bx + wv / 2 - 1, by + 66)]), PAGE)
		_poly(PackedVector2Array([Vector2(bx + wv / 2 + 1, by - 6), Vector2(bx + wv - 8, by - 6), Vector2(bx + wv + 3, by + 66), Vector2(bx + wv / 2 + 1, by + 66)]), PAGE)
		_r(bx + wv / 2 - 1, by - 6, 2, 72, PAGE_D)
		# text lines on both pages (perspective: narrower toward the top)
		for i in 9:
			var ly := by - 2 + i * 7.4
			var k := float(i) / 8.0
			var inset := lerpf(14.0, 4.0, k)
			var lw := lerpf(60.0, 76.0, k) * (0.75 + 0.25 * _hash(i, 41))
			_r(bx + inset + 4, ly, lw, 1, INK)
			var rw := lerpf(58.0, 74.0, k) * (0.7 + 0.3 * _hash(i, 42))
			if act == "write":
				var prog := fmod(a.c - 12.0, 10.0) / 10.0
				if float(i) / 9.0 <= prog:
					_r(bx + wv / 2 + 6, ly, rw, 1, Color("3a4a8a"))
			else:
				_r(bx + wv / 2 + 6, ly, rw, 1, INK)
		# reading highlight scanning left to right on a line
		if act == "read":
			var line := fmod(floorf(t * 0.35), 9.0)
			var sx := fmod(t * 0.35, 1.0)
			var ly := by - 2 + line * 7.4
			_r(bx + 14 + sx * 70.0, ly - 1, 14, 3, Color(1, 0.9, 0.4, 0.3))
		# page turn
		if a.turn > 0.05:
			var f: float = a.turn
			var mid := bx + wv / 2
			var tipx := mid + (wv / 2 - 10) * cos(f * PI)
			_poly(PackedVector2Array([Vector2(mid, by - 6), Vector2(tipx, by - 14 - 8 * f), Vector2(tipx + 4, by + 56 - 10 * f), Vector2(mid, by + 66)]), PAGE)
			_r(tipx, by - 14 - 8 * f, 2, 70, PAGE_D)
		# hands
		var lhx := 58.0
		_hand_pov(lhx, 188 - 6, false)
		var rhx := 262.0
		var rhy := 176.0
		if act == "write":
			rhx = 168.0 + sin(t * 5.0) * 4.0
			rhy = 150.0 + sin(t * 9.0) * 1.5
		elif a.turn > 0.05:
			rhx = lerpf(262.0, 150.0, a.turn)
			rhy = lerpf(176.0, 140.0, a.turn)
		_hand_pov(rhx, rhy, true)
		if act == "write":
			draw_line(Vector2(rhx - 6, rhy - 2), Vector2(rhx - 18, rhy - 22), Color("e8c040"), 3.0)
			_r(rhx - 20, rhy - 26, 4, 5, Color("e89aa0"))
			_r(rhx - 8, rhy, 3, 2, Color("3a2a1a"))


func _hand_pov(x: float, y: float, right: bool) -> void:
	_poly(PackedVector2Array([Vector2(x - 20, 190), Vector2(x - 12, y + 6), Vector2(x + 12, y + 6), Vector2(x + 20, 190)]), SHIRT)
	_poly(PackedVector2Array([Vector2(x - 20, 190), Vector2(x - 12, y + 6), Vector2(x - 8, y + 6), Vector2(x - 14, 190)]), SHIRT_D)
	_r(x - 11, y - 6, 22, 14, SKIN)
	_r(x - 11, y - 6, 22, 2, SKIN_L)
	for i in 4:
		_r(x - 10 + i * 6, y - 11, 4, 7, SKIN)
		_r(x - 10 + i * 6, y - 11, 4, 1, SKIN_L)
		_px(x - 8 + i * 6, y - 10, Color("e8b894"))
	if right:
		_r(x - 18, y - 2, 6, 8, SKIN)
	else:
		_r(x + 12, y - 2, 6, 8, SKIN)


# ---------------------------------------------------------------------------------------------
func _draw() -> void:
	_scale = maxf(size.x / VW, size.y / VH)
	_off = Vector2((size.x - VW * _scale) * 0.5, (size.y - VH * _scale) * 0.5)
	draw_set_transform(_off, 0.0, Vector2(_scale, _scale))
	match angle:
		"top": _view_top()
		"pov": _view_pov()
		_: _view_side()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
