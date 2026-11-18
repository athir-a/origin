extends Node2D
## The living village. Everything visible here reflects progress stored in OriginState.

signal prompt_changed(text: String)
signal interact_requested(kind: String, id: String)

const Content = preload("res://scripts/origin/content.gd")
const ActorScript = preload("res://scripts/origin/actor.gd")

const WORLD_W := 1200
const WORLD_H := 800
const TS := 16
const LAMP_POS := Vector2(610, 490)
const SPAWN := Vector2(566, 524)
const NORTH_GATE := Rect2(640, 316, 80, 12)
const EAST_GATE := Rect2(856, 480, 12, 64)
const SEASONS := ["spring", "summer", "autumn", "winter"]

const SITES := {
	"home": Vector2(330, 430), "cottage": Vector2(250, 560), "library": Vector2(500, 440), "shop": Vector2(780, 450),
	"market": Vector2(780, 568), "school": Vector2(360, 268), "clinic": Vector2(800, 268), "computer": Vector2(975, 440),
	"tower": Vector2(1110, 430), "well": Vector2(372, 548), "farm": Vector2(540, 704),
}
const PLOT_POS := [Vector2(468, 668), Vector2(538, 668), Vector2(608, 668), Vector2(468, 742), Vector2(538, 742), Vector2(608, 742)]

var state: Node
var hour := 17.0
var weather := "sunny"
var weather_amount := 0.0
var season := "autumn"
var time_scale := 1.0 / 30.0
var time_frozen := false
var weather_locked := false
var darkness := 0.0
var input_enabled := true
var player: Node2D
var actors: Dictionary = {}
var animals: Array = []
var extras: Array = []
var blockers: Array[Rect2] = []
var targets: Array = []
var statics: Array = []
var lights: Array = []
var lit_levels: Dictionary = {}
var current_target: Dictionary = {}
var _last_prompt := ""
var _tex_cache: Dictionary = {}
var _weather_timer := 120.0
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _shadow_tex: Texture2D
var _light_tex: Texture2D
var _road_tiles: Dictionary = {}
var _plaza_tiles: Dictionary = {}
var focus_pos: Variant = null
var focus_zoom := 1.5
var base_zoom := 1.5
var _cam_zoom := 1.5
var follow_pos := Vector2.ZERO

var ground: Node2D
var objects: Node2D
var fx: Node2D
var cam: Camera2D
var modulate_node: CanvasModulate
var ambient: Node2D
var ground_atlas: Texture2D
var road_level := 0
var zone_states := {"north": false, "east": false}
var _pop_id := ""
var _lv: Dictionary = {}


func _ready() -> void:
	_rng.seed = 7
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	state = get_node("/root/OriginState")
	ground_atlas = load("res://assets/origin/ground/ground_atlas.png")
	_shadow_tex = _make_shadow_tex()
	_light_tex = _make_light_tex()

	modulate_node = CanvasModulate.new()
	add_child(modulate_node)
	ground = GroundLayer.new()
	ground.w = self
	ground.z_index = -20
	add_child(ground)
	objects = Node2D.new()
	objects.y_sort_enabled = true
	add_child(objects)
	ambient = AmbientLayer.new()
	ambient.w = self
	ambient.z_index = 40
	add_child(ambient)
	fx = FxLayer.new()
	fx.z_index = 45
	add_child(fx)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = WORLD_W
	cam.limit_bottom = WORLD_H
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()

	var now := Time.get_time_dict_from_system()
	hour = float(now.hour) + float(now.minute) / 60.0
	_set_season_from_date()
	_pick_weather(true)

	player = ActorScript.new()
	var hf := _tex("chars/hero_front")
	player.setup("player", "You", hf, _tex("chars/hero_back"), _tex("chars/hero_side"))
	player.speed = 64.0
	player.shadow_w = 8.0
	objects.add_child(player)
	player.position = SPAWN
	follow_pos = SPAWN
	cam.position = SPAWN
	refresh()


func _set_season_from_date() -> void:
	var m: int = Time.get_date_dict_from_system().month
	if m in [12, 1, 2]:
		season = "winter"
	elif m in [3, 4, 5]:
		season = "spring"
	elif m in [6, 7, 8]:
		season = "summer"
	else:
		season = "autumn"


func _tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load("res://assets/origin/%s.png" % name)
	return _tex_cache[name]


func _make_shadow_tex() -> Texture2D:
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 64:
			var dx := (x - 31.5) / 32.0
			var dy := (y - 15.5) / 16.0
			var dd := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - dd, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, minf(0.34, a * 0.8)))
	return ImageTexture.create_from_image(img)


func _make_light_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.4, Color(1, 1, 1, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 256
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	return gt


# ---------------------------------------------------------------------------------------------
# Public control API
# ---------------------------------------------------------------------------------------------
func set_sky(h: float, w: String, s: String) -> void:
	hour = fposmod(h, 24.0)
	if w != "":
		weather = w
		weather_amount = 1.0 if w in ["rain", "snow"] else (0.6 if w == "cloudy" else 0.0)
	if s != "" and s != season:
		season = s
		refresh()
	_update_light(0.0, true)


func snap_player(p: Vector2) -> void:
	player.position = p
	follow_pos = p
	cam.position = p


func focus_on(p: Vector2, zoom: float = 2.2) -> void:
	focus_pos = p
	focus_zoom = zoom


func release_focus() -> void:
	focus_pos = null
	focus_zoom = base_zoom


func time_text() -> String:
	var hh := int(floor(hour))
	var mm := int((hour - floor(hour)) * 60.0)
	var suffix := "AM" if hh < 12 else "PM"
	var h12 := hh % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, suffix]


func is_night() -> bool:
	return darkness > 0.55


func weather_text() -> String:
	match weather:
		"cloudy": return "Cloudy"
		"rain": return "Rain"
		"snow": return "Snow"
	return "Clear"


func spawn_dust(p: Vector2, n: int = 14) -> void:
	fx.burst(p, n, Color(0.86, 0.78, 0.62, 0.9), 26.0, 0.9, 3.0)


func spawn_sparkles(p: Vector2, n: int = 16) -> void:
	fx.sparkle(p, n)


# ---------------------------------------------------------------------------------------------
# Rebuild everything that depends on progress
# ---------------------------------------------------------------------------------------------
func refresh(pop: String = "") -> void:
	_pop_id = pop
	_lv = state.shown_levels()
	zone_states.north = state.zone_shown("north")
	zone_states.east = state.zone_shown("east")
	road_level = clampi(int(_lv.roads), 0, 2)
	for n in statics:
		if is_instance_valid(n):
			n.queue_free()
	statics.clear()
	lights.clear()
	blockers.clear()
	targets.clear()
	_build_roads()
	_build_statics()
	_sync_actors()
	ground.queue_redraw()
	ambient.queue_redraw()
	_update_light(0.0, true)


func _build_roads() -> void:
	_road_tiles.clear()
	_plaza_tiles.clear()
	var rects: Array[Rect2] = [
		Rect2(48, 496, 806 if not zone_states.east else 1054, 32),
		Rect2(320, 432, 32, 66), Rect2(496, 444, 32, 54), Rect2(768, 454, 32, 44), Rect2(240, 526, 32, 40), Rect2(528, 526, 32, 76),
	]
	if zone_states.north:
		rects.append(Rect2(672, 272, 32, 226))
		rects.append(Rect2(336, 272, 480, 32))
		rects.append(Rect2(352, 272, 32, 8))
	if zone_states.east:
		rects.append(Rect2(960, 442, 32, 56))
	for r in rects:
		for ty in range(int(floor(r.position.y / TS)), int(ceil((r.position.y + r.size.y) / TS))):
			for tx in range(int(floor(r.position.x / TS)), int(ceil((r.position.x + r.size.x) / TS))):
				_road_tiles[Vector2i(tx, ty)] = true
	for ty in range(int(LAMP_POS.y / TS) - 4, int(LAMP_POS.y / TS) + 4):
		for tx in range(int(LAMP_POS.x / TS) - 4, int(LAMP_POS.x / TS) + 4):
			var c := Vector2(tx * TS + 8, ty * TS + 8)
			if c.distance_to(LAMP_POS + Vector2(0, 6)) < 40.0:
				_road_tiles[Vector2i(tx, ty)] = true
				_plaza_tiles[Vector2i(tx, ty)] = true


func _spawn(tex_name: String, pos: Vector2, opts: Dictionary = {}) -> Node2D:
	var tx := _tex(tex_name)
	var n := Node2D.new()
	n.position = pos
	var sp := Sprite2D.new()
	sp.texture = tx
	sp.centered = false
	var sz := tx.get_size()
	sp.position = Vector2(-sz.x * 0.5, -sz.y)
	n.add_child(sp)
	if opts.get("shadow", true):
		var sh := Sprite2D.new()
		sh.texture = _shadow_tex
		var sw: float = opts.get("shadow_w", sz.x * 0.9)
		sh.scale = Vector2(sw / 64.0, maxf(0.5, minf(sw * 0.22, 26.0) / 32.0))
		sh.position = Vector2(0, -1)
		sh.z_index = -6
		n.add_child(sh)
	if opts.has("tint"):
		sp.modulate = opts.tint
	objects.add_child(n)
	statics.append(n)
	if opts.get("block", false):
		var bw: float = opts.get("block_w", sz.x * 0.8)
		var bh: float = opts.get("block_h", 16.0)
		blockers.append(Rect2(pos.x - bw * 0.5, pos.y - bh, bw, bh))
	if opts.has("light"):
		var l: Dictionary = opts.light
		var lt := PointLight2D.new()
		lt.texture = _light_tex
		lt.texture_scale = float(l.get("radius", 70.0)) / 128.0
		lt.color = l.get("color", Color(1.0, 0.82, 0.5))
		lt.energy = 0.0
		lt.position = l.get("offset", Vector2(0, -sz.y * 0.4))
		lt.shadow_enabled = false
		n.add_child(lt)
		lights.append({"node": lt, "energy": float(l.get("energy", 0.9)), "flicker": float(l.get("flicker", 0.0)), "always": bool(l.get("always", false)), "seed": _rng.randf() * 10.0})
	if opts.get("pop", false) and _pop_id != "":
		n.scale = Vector2(1.0, 0.05)
		var tw := create_tween()
		tw.tween_property(n, "scale", Vector2(1.0, 1.12), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.5)
		tw.tween_property(n, "scale", Vector2(1.0, 1.0), 0.2)
	return n


func _add_target(pos: Vector2, r: float, kind: String, id: String, label: String) -> void:
	targets.append({"pos": pos, "r": r, "kind": kind, "id": id, "label": label})


func _is_pop(id: String) -> bool:
	return _pop_id == id


func _build_statics() -> void:
	var lv := _lv
	var night_light := {"radius": 74.0, "color": Color(1.0, 0.8, 0.5), "energy": 0.85}
	# --- homes
	var home := _spawn("buildings/home", SITES.home, {"block": true, "light": night_light})
	_add_target(SITES.home + Vector2(0, 8), 30, "flavor", "home", "Look at your family home")
	_spawn("buildings/cottage", SITES.cottage, {"block": true, "light": night_light})
	_add_target(SITES.cottage + Vector2(0, 8), 30, "flavor", "cottage", "Look at Tiya's house")
	_spawn("props/well", SITES.well, {"block": true, "block_w": 26, "block_h": 12})
	_add_target(SITES.well + Vector2(0, 6), 24, "flavor", "well", "Look at the village well")
	# --- lamp (the place where it all begins)
	_spawn("props/oil_lamp", LAMP_POS, {"block": true, "block_w": 8, "block_h": 5, "shadow_w": 20,
		"light": {"radius": 120.0, "color": Color(1.0, 0.76, 0.42), "energy": 1.15, "flicker": 0.12, "offset": Vector2(0, -52), "always": false}})
	_add_target(LAMP_POS + Vector2(-2, 14), 34, "study", "lamp", "Study beneath the lamp" if not state.ended() else "Study beside Asha")
	# --- library (bookshelf -> hut -> library -> center)
	var ll: int = lv.library
	var lib_names := ["buildings/library_0", "buildings/library_1", "buildings/library_2", "buildings/library_3"]
	var lib_opts := {"block": true, "pop": _is_pop("library")}
	if ll >= 1:
		lib_opts["light"] = night_light
	_spawn(lib_names[ll], SITES.library, lib_opts)
	_add_target(SITES.library + Vector2(0, 8), 34, "building", "library", "Visit the library" if ll > 0 else "Look at the lone bookshelf")
	# --- shop + market
	var shop_light := {"radius": 84.0, "color": Color(1.0, 0.82, 0.5), "energy": 0.9}
	_spawn("buildings/shop", SITES.shop, {"block": true, "light": shop_light})
	_add_target(SITES.shop + Vector2(0, 8), 34, "building", "shop", "Visit Kabir's shop")
	if lv.shop >= 2:
		_spawn("buildings/market", SITES.market, {"block": true, "block_h": 22, "pop": _is_pop("shop"), "light": {"radius": 100.0, "color": Color(1.0, 0.85, 0.55), "energy": 0.8, "offset": Vector2(0, -50)}})
	# --- farm
	for i in PLOT_POS.size():
		var stage := 0
		match int(lv.farm):
			1: stage = 1 if i < 3 else 0
			2: stage = 2 if i < 3 else 1
			3: stage = 3
		_spawn("props/plot_%d" % stage, PLOT_POS[i], {"block": true, "block_w": 54, "block_h": 46, "shadow": false, "pop": _is_pop("farm")})
	_add_target(SITES.farm, 74, "building", "farm", "Look over the farms")
	_spawn("props/scarecrow", Vector2(660, 712), {"block": true, "block_w": 8, "block_h": 6, "shadow_w": 16})
	_spawn("props/hay", Vector2(676, 750), {"block": true, "block_w": 30, "block_h": 12, "shadow_w": 32})
	if lv.farm >= 2:
		_spawn("props/crates", Vector2(420, 736), {"block": true, "block_w": 32, "block_h": 12, "shadow_w": 34})
	# --- north hill
	if zone_states.north:
		if lv.school >= 1:
			_spawn("buildings/school_%d" % lv.school, SITES.school, {"block": true, "pop": _is_pop("school"), "light": night_light})
			_add_target(SITES.school + Vector2(0, 8), 34, "building", "school", "Visit the school")
		else:
			_spawn("buildings/plot", SITES.school, {"block": false, "shadow_w": 56})
			_add_target(SITES.school + Vector2(0, 6), 36, "building", "school", "Look at the empty plot")
		if lv.clinic >= 1:
			_spawn("buildings/clinic", SITES.clinic, {"block": true, "pop": _is_pop("clinic"), "light": {"radius": 84.0, "color": Color(0.85, 1.0, 0.9), "energy": 0.85}})
			_add_target(SITES.clinic + Vector2(0, 8), 34, "building", "clinic", "Visit the clinic")
			if lv.clinic >= 2:
				_spawn("props/flowers", SITES.clinic + Vector2(-70, 6), {"shadow": false})
				_spawn("props/flowers", SITES.clinic + Vector2(66, 8), {"shadow": false})
				_spawn("props/bench", SITES.clinic + Vector2(-48, 16), {"block": true, "block_w": 30, "block_h": 8})
		else:
			_spawn("buildings/plot", SITES.clinic, {"block": false, "shadow_w": 56})
			_add_target(SITES.clinic + Vector2(0, 6), 36, "building", "clinic", "Look at the empty plot")
	# --- east road
	if zone_states.east:
		if lv.computer >= 1:
			_spawn("buildings/computer_%d" % lv.computer, SITES.computer, {"block": true, "pop": _is_pop("computer"), "light": {"radius": 100.0, "color": Color(0.7, 0.95, 1.0), "energy": 0.9}})
			_add_target(SITES.computer + Vector2(0, 8), 36, "building", "computer", "Visit the computer center")
		else:
			_spawn("buildings/plot", SITES.computer, {"block": false, "shadow_w": 56})
			_add_target(SITES.computer + Vector2(0, 6), 36, "building", "computer", "Look at the empty plot")
		if lv.internet >= 1:
			var tw := _spawn("buildings/tower", SITES.tower, {"block": true, "block_w": 34, "block_h": 14, "shadow_w": 50, "pop": _is_pop("internet")})
			tw.set_meta("tower", true)
			_add_target(SITES.tower + Vector2(0, 8), 36, "building", "internet", "Look at the communications tower")
		_spawn("props/rocks", Vector2(1000, 600), {"block": true, "block_w": 34, "block_h": 12})
		_spawn("props/crates", Vector2(930, 590), {"block": true, "block_w": 32, "block_h": 12, "shadow_w": 34})
	# --- electricity
	if lv.electricity >= 1:
		for x in [210, 440, 700, 890, 1040]:
			if x > 860 and not zone_states.east:
				continue
			_spawn("props/power_pole", Vector2(x, 492), {"block": true, "block_w": 8, "block_h": 5, "shadow_w": 14})
		var lamp_xs := [300, 560, 730, 830]
		if lv.electricity >= 2:
			lamp_xs.append_array([150, 420, 640])
		for x in lamp_xs:
			_spawn("props/electric_lamp", Vector2(x, 536), {"block": true, "block_w": 8, "block_h": 5, "shadow_w": 14,
				"light": {"radius": 82.0, "color": Color(1.0, 0.95, 0.82), "energy": 0.85, "offset": Vector2(-6, -52)}})
		if zone_states.east:
			for x in [940, 1030]:
				_spawn("props/electric_lamp", Vector2(x, 536), {"block": true, "block_w": 8, "block_h": 5, "shadow_w": 14,
					"light": {"radius": 82.0, "color": Color(1.0, 0.95, 0.82), "energy": 0.85, "offset": Vector2(-6, -52)}})
	# --- gates / barriers
	if not zone_states.north:
		blockers.append(NORTH_GATE)
		_spawn("props/barrier", Vector2(680, 338), {"shadow_w": 40})
		_spawn("props/bush", Vector2(650, 334), {"shadow_w": 22})
		_spawn("props/bush", Vector2(712, 334), {"shadow_w": 22})
		_add_target(Vector2(680, 346), 34, "barrier", "north", "Inspect the overgrown path")
	if not zone_states.east:
		blockers.append(EAST_GATE)
		_spawn("props/barrier", Vector2(850, 512), {"shadow_w": 40})
		_spawn("props/signpost", Vector2(838, 540), {"shadow_w": 16})
		_add_target(Vector2(844, 518), 34, "barrier", "east", "Look down the east track")
	# --- fences (blockers; drawn by the ground layer)
	_add_fence_blockers()
	_scatter_nature()


func _add_fence_blockers() -> void:
	# northern fence line y=320 with a gate gap, eastern line x=860 with a gap
	blockers.append(Rect2(40, 316, 640 - 40, 8))
	blockers.append(Rect2(720, 316, 1160 - 720, 8))
	blockers.append(Rect2(856, 316, 8, 480 - 316))
	blockers.append(Rect2(856, 544, 8, 760 - 544))


func _scatter_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var tree_name := "props/tree_%s" % season
	var occupied: Array[Rect2] = []
	for b in blockers:
		occupied.append(b.grow(18.0))
	var free := func(p: Vector2, margin: float) -> bool:
		if p.x < 44 or p.x > WORLD_W - 44 or p.y < 76 or p.y > WORLD_H - 18:
			return false
		var tile := Vector2i(int(p.x / TS), int(p.y / TS))
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if _road_tiles.has(Vector2i(tile.x + dx, tile.y + dy)):
					return false
		var r := Rect2(p.x - margin, p.y - margin * 0.7, margin * 2.0, margin * 1.4)
		for o in occupied:
			if o.intersects(r):
				return false
		for s in SITES.values():
			if (s as Vector2).distance_to(p) < 62.0:
				return false
		if p.distance_to(LAMP_POS) < 70.0:
			return false
		return true
	var placed: Array[Vector2] = []
	var try_tree := func(p: Vector2, big: bool) -> void:
		if not free.call(p, 16.0):
			return
		for q in placed:
			if q.distance_to(p) < 26.0:
				return
		placed.append(p)
		var nm := tree_name if (big or rng.randf() < 0.7) else "props/pine"
		var tn := _spawn(nm, p, {"block": true, "block_w": 10, "block_h": 6, "shadow_w": 30})
		if nm == "props/pine" and season == "winter":
			tn.modulate = Color(0.86, 0.94, 1.0)
	# border bands
	var x := 52.0
	while x < WORLD_W - 40:
		try_tree.call(Vector2(x + rng.randf_range(-6, 6), 92 + rng.randf_range(-6, 14)), true)
		try_tree.call(Vector2(x + rng.randf_range(-6, 6), WORLD_H - 22 + rng.randf_range(-6, 0)), true)
		x += 34.0
	var y := 100.0
	while y < WORLD_H - 30:
		try_tree.call(Vector2(54 + rng.randf_range(-4, 8), y + rng.randf_range(-6, 6)), true)
		try_tree.call(Vector2(WORLD_W - 52 + rng.randf_range(-8, 4), y + rng.randf_range(-6, 6)), true)
		y += 34.0
	for i in 160:
		try_tree.call(Vector2(rng.randf_range(60, WORLD_W - 60), rng.randf_range(100, WORLD_H - 30)), false)
	# bushes / flowers / rocks
	for i in 120:
		var p := Vector2(rng.randf_range(60, WORLD_W - 60), rng.randf_range(100, WORLD_H - 20))
		if not free.call(p, 8.0):
			continue
		var k := rng.randf()
		if k < 0.4:
			var bn := _spawn("props/bush", p, {"shadow_w": 22})
			if season == "autumn":
				bn.modulate = Color(1.0, 0.82, 0.6)
			elif season == "winter":
				bn.modulate = Color(0.88, 0.95, 1.0)
		elif k < 0.8 and season != "winter":
			_spawn("props/flowers", p, {"shadow": false})
		elif k < 0.9:
			_spawn("props/rocks", p, {"block": true, "block_w": 28, "block_h": 10, "shadow_w": 30})


# ---------------------------------------------------------------------------------------------
# Actors (villagers and animals)
# ---------------------------------------------------------------------------------------------
func _chars(id: String) -> Array:
	return [_tex("chars/%s_front" % id), _tex("chars/%s_back" % id), _tex("chars/%s_side" % id)]


func _make_actor(id: String, nm: String, tex: Array, pos: Vector2, radius: float, speed: float, shadow: float) -> Node2D:
	var a: Node2D = ActorScript.new()
	a.setup(id, nm, tex[0], tex[1], tex[2])
	a.position = pos
	a.home = pos
	a.wander_radius = radius
	a.speed = speed
	a.shadow_w = shadow
	objects.add_child(a)
	return a


func _sync_actors() -> void:
	var lv := _lv
	# player look depends on the story
	var hero := "hero_grown" if state.ended() else "hero"
	var ph := _chars(hero)
	player.set_textures(ph[0], ph[1], ph[2])

	var want: Dictionary = {
		"grandma": {"pos": Vector2(298, 476), "r": 24.0, "sp": 12.0},
		"mother": {"pos": Vector2(356, 462), "r": 30.0, "sp": 16.0},
		"shopkeeper": {"pos": Vector2(770, 476), "r": 26.0, "sp": 14.0},
		"child": {"pos": Vector2(654, 526), "r": 0.0, "sp": 0.0},
		"farmer": {"pos": Vector2(690, 668), "r": 34.0, "sp": 14.0},
	}
	if lv.school >= 1 and zone_states.north:
		want["teacher"] = {"pos": Vector2(420, 296), "r": 40.0, "sp": 15.0}
	if lv.clinic >= 1 and zone_states.north:
		want["doctor"] = {"pos": Vector2(770, 296), "r": 32.0, "sp": 15.0}
	if lv.computer >= 1 and zone_states.east:
		want["tech"] = {"pos": Vector2(950, 478), "r": 30.0, "sp": 18.0}
	for id in want.keys():
		if not actors.has(id):
			var info: Dictionary = Content.VILLAGERS[id]
			var a := _make_actor(id, info.name, _chars(id), want[id].pos, want[id].r, want[id].sp, 8.0 if id != "child" else 6.5)
			a.look_at_player = id == "child"
			actors[id] = a
	if state.ended() and not actors.has("asha"):
		var at := _tex("chars/asha_study")
		var asha := _make_actor("asha", "Asha", [at, at, at], LAMP_POS + Vector2(28, 14), 0.0, 0.0, 9.0)
		asha.static_pose = true
		actors["asha"] = asha
	for id: String in actors:
		(actors[id] as Node2D).has_news = state.pending_for(id).size() > 0
	# animals
	if animals.is_empty():
		var defs := [
			["hen", Vector2(486, 716), 20.0], ["hen_peck", Vector2(560, 770), 22.0], ["chick", Vector2(500, 776), 16.0],
			["cat", Vector2(372, 442), 12.0], ["dog", Vector2(742, 500), 26.0],
		]
		for df in defs:
			var tx := _tex("props/%s" % df[0])
			var an := _make_actor("animal", df[0], [tx, tx, tx], df[1], df[2], 16.0 if df[0] != "chick" else 11.0, 5.0)
			an.is_animal = true
			an.set_meta("kind", df[0])
			animals.append(an)
	if zone_states.east and not _has_animal("goat"):
		var gt := _tex("props/goat")
		var g := _make_actor("animal", "goat", [gt, gt, gt], Vector2(1040, 620), 30.0, 10.0, 9.0)
		g.is_animal = true
		g.set_meta("kind", "goat")
		animals.append(g)
	# market crowd
	for e in extras:
		if is_instance_valid(e):
			e.queue_free()
	extras.clear()
	if lv.shop >= 2:
		var tints := [Color(0.85, 1.0, 0.85), Color(1.0, 0.85, 0.85), Color(0.85, 0.9, 1.0)]
		var srcs := ["mother", "farmer", "teacher"]
		for i in 3:
			var ex := _make_actor("extra", "Villager", _chars(srcs[i]), SITES.market + Vector2(-50 + i * 50, 18), 30.0, 14.0, 8.0)
			ex.sprite.modulate = tints[i]
			extras.append(ex)


func _has_animal(kind: String) -> bool:
	for a in animals:
		if a.get_meta("kind") == kind:
			return true
	return false


func refresh_news() -> void:
	for id: String in actors:
		(actors[id] as Node2D).has_news = state.pending_for(id).size() > 0
	ambient.queue_redraw()


# ---------------------------------------------------------------------------------------------
# Movement & collision
# ---------------------------------------------------------------------------------------------
func _blocked(p: Vector2) -> bool:
	if p.x < 46 or p.x > WORLD_W - 46 or p.y < 60 or p.y > WORLD_H - 14:
		return true
	var foot := Rect2(p.x - 4, p.y - 3, 8, 4)
	for b in blockers:
		if b.intersects(foot):
			return true
	return false


func try_move(actor: Node2D, step: Vector2) -> bool:
	var moved := false
	var p: Vector2 = actor.position
	if step.x != 0.0 and not _blocked(p + Vector2(step.x, 0)):
		p.x += step.x
		moved = true
	if step.y != 0.0 and not _blocked(p + Vector2(0, step.y)):
		p.y += step.y
		moved = true
	actor.position = p
	return moved


func _physics_process(delta: float) -> void:
	_t += delta
	var dir := Vector2.ZERO
	if input_enabled:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.1:
		var step: Vector2 = dir * float(player.speed) * delta
		if try_move(player, step):
			player.moving = true
		else:
			player.moving = false
		player.face_dir(dir)
	else:
		player.moving = false
	for id: String in actors:
		(actors[id] as Node2D).think(delta, self, player.position)
	for a in animals:
		a.think(delta, self, player.position)
	for e in extras:
		if is_instance_valid(e):
			e.think(delta, self, player.position)
	_update_camera(delta)
	_update_interaction()


func _update_camera(delta: float) -> void:
	var want_pos: Vector2 = player.position + Vector2(0, -14)
	var z := base_zoom
	if focus_pos != null:
		want_pos = focus_pos
		z = focus_zoom
	var k := 1.0 - exp(-delta * 4.0)
	follow_pos = follow_pos.lerp(want_pos, k)
	_cam_zoom = lerpf(_cam_zoom, z, 1.0 - exp(-delta * 3.0))
	cam.zoom = Vector2(_cam_zoom, _cam_zoom)
	cam.position = follow_pos.round()


func _update_interaction() -> void:
	current_target = {}
	if not input_enabled:
		_set_prompt("")
		return
	var best := 1e9
	var foot: Vector2 = player.position
	for t: Dictionary in targets:
		var dd: float = foot.distance_to(t.pos)
		if dd < t.r and dd < best:
			best = dd
			current_target = t
	for id: String in actors:
		var a: Node2D = actors[id]
		var dd := foot.distance_to(a.position)
		var rr := 30.0
		if dd < rr and dd < best:
			best = dd
			current_target = {"pos": a.position, "r": rr, "kind": "talk", "id": id, "label": "Talk to %s" % a.display_name}
	_set_prompt(current_target.get("label", ""))


func _set_prompt(txt: String) -> void:
	if txt != _last_prompt:
		_last_prompt = txt
		prompt_changed.emit(txt)


func activate() -> void:
	if current_target.is_empty():
		return
	if current_target.kind == "talk" and actors.has(current_target.id):
		var a: Node2D = actors[current_target.id]
		a.talk_pause = 4.0
		a.face_dir(player.position - a.position)
		player.face_dir(a.position - player.position)
	interact_requested.emit(current_target.kind, current_target.id)


# ---------------------------------------------------------------------------------------------
# Time, weather and light
# ---------------------------------------------------------------------------------------------
const SKY_KEYS := [
	[0.0, Color(0.20, 0.25, 0.46), 0.85], [4.5, Color(0.24, 0.29, 0.50), 0.8], [6.0, Color(0.92, 0.70, 0.66), 0.4],
	[7.5, Color(1.0, 0.95, 0.88), 0.05], [12.0, Color(1.0, 1.0, 1.0), 0.0], [16.5, Color(1.0, 0.96, 0.86), 0.04],
	[18.3, Color(1.0, 0.72, 0.52), 0.3], [19.8, Color(0.58, 0.46, 0.66), 0.62], [21.5, Color(0.26, 0.31, 0.52), 0.82],
	[24.0, Color(0.20, 0.25, 0.46), 0.85],
]


func _sky_at(h: float) -> Array:
	for i in SKY_KEYS.size() - 1:
		var a: Array = SKY_KEYS[i]
		var b: Array = SKY_KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var f: float = (h - a[0]) / (b[0] - a[0])
			f = f * f * (3.0 - 2.0 * f)
			return [(a[1] as Color).lerp(b[1], f), lerpf(a[2], b[2], f)]
	return [Color.WHITE, 0.0]


func _pick_weather(first: bool = false) -> void:
	if weather_locked:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var r := rng.randf()
	var w := "sunny"
	if season == "winter":
		w = "sunny" if r < 0.5 else ("cloudy" if r < 0.75 else "snow")
	elif season == "summer":
		w = "sunny" if r < 0.6 else ("cloudy" if r < 0.8 else "rain")
	else:
		w = "sunny" if r < 0.45 else ("cloudy" if r < 0.75 else "rain")
	weather = w
	_weather_timer = rng.randf_range(100.0, 220.0)


func _process(delta: float) -> void:
	if not time_frozen:
		hour = fposmod(hour + delta * time_scale, 24.0)
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_pick_weather()
	var target_amt := 0.0
	match weather:
		"rain", "snow": target_amt = 1.0
		"cloudy": target_amt = 0.55
	weather_amount = move_toward(weather_amount, target_amt, delta * 0.25)
	_update_light(delta, false)


func _update_light(delta: float, snap: bool) -> void:
	var sk := _sky_at(hour)
	var c: Color = sk[0]
	var dark: float = sk[1]
	var wet := weather_amount
	var storm := Color(0.78, 0.82, 0.92) if weather == "rain" else (Color(0.9, 0.93, 1.0) if weather == "snow" else Color(0.9, 0.92, 0.96))
	c = c.lerp(c * storm, wet)
	if season == "winter":
		c = c.lerp(c * Color(0.92, 0.97, 1.05), 0.6)
	elif season == "autumn":
		c = c.lerp(c * Color(1.05, 0.97, 0.9), 0.5)
	modulate_node.color = c
	darkness = clampf(dark + wet * 0.15, 0.0, 1.0)
	var factor := clampf((darkness - 0.18) / 0.5, 0.0, 1.0)
	for l: Dictionary in lights:
		var n: PointLight2D = l.node
		if not is_instance_valid(n):
			continue
		var fl := 1.0
		if l.flicker > 0.0:
			fl = 1.0 - l.flicker * (0.5 + 0.5 * sin(_t * 9.0 + l.seed) * sin(_t * 5.3 + l.seed * 2.0))
		n.energy = l.energy * factor * fl
		n.visible = n.energy > 0.01
	if snap:
		ground.queue_redraw()


# ---------------------------------------------------------------------------------------------
# Inner layers
# ---------------------------------------------------------------------------------------------
class GroundLayer extends Node2D:
	var w: Node2D

	func _h(x: int, y: int, s: int) -> float:
		var n: int = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
		n = (n ^ (n >> 13)) * 1274126177
		n = n ^ (n >> 16)
		return float(n & 0xFFFF) / 65535.0

	func _draw() -> void:
		if w == null or w.ground_atlas == null:
			return
		var atlas: Texture2D = w.ground_atlas
		var si: int = w.SEASONS.find(w.season)
		var cols := WORLD_W / TS
		var rows := WORLD_H / TS
		var overgrown_n: bool = not w.zone_states.north
		var overgrown_e: bool = not w.zone_states.east
		for ty in rows:
			for tx in cols:
				var hv0 := _h(tx, ty, 1)
				var v := 0 if hv0 < 0.55 else (1 if hv0 < 0.75 else (2 if hv0 < 0.9 else 3))
				draw_texture_rect_region(atlas, Rect2(tx * TS, ty * TS, TS, TS), Rect2(v * TS, si * TS, TS, TS))
		# decor
		for ty in rows:
			for tx in cols:
				if w._road_tiles.has(Vector2i(tx, ty)):
					continue
				var hv := _h(tx, ty, 2)
				var wild := (overgrown_n and ty < 20) or (overgrown_e and tx > 54 and ty >= 20)
				var thr := 0.34 if wild else 0.1
				if hv < thr:
					var kind := int(_h(tx, ty, 3) * 4.0) % 4
					if wild:
						kind = 0 if hv < 0.2 else kind
					draw_texture_rect_region(atlas, Rect2(tx * TS, ty * TS, TS, TS), Rect2(kind * TS, (4 + si) * TS, TS, TS))
		# roads
		for key in w._road_tiles.keys():
			var t: Vector2i = key
			var m := 0
			if w._road_tiles.has(Vector2i(t.x, t.y - 1)): m |= 1
			if w._road_tiles.has(Vector2i(t.x + 1, t.y)): m |= 2
			if w._road_tiles.has(Vector2i(t.x, t.y + 1)): m |= 4
			if w._road_tiles.has(Vector2i(t.x - 1, t.y)): m |= 8
			var lvl: int = w.road_level
			if w._plaza_tiles.has(t):
				lvl = maxi(lvl, 2) if w.state.ended() else lvl
			draw_texture_rect_region(atlas, Rect2(t.x * TS, t.y * TS, TS, TS), Rect2(m * TS, (8 + lvl) * TS, TS, TS))
		# darker overgrowth wash over locked zones
		if overgrown_n:
			draw_rect(Rect2(40, 60, WORLD_W - 80, 260), Color(0.05, 0.18, 0.08, 0.16))
		if overgrown_e:
			draw_rect(Rect2(868, 324, WORLD_W - 920, WORLD_H - 360), Color(0.05, 0.18, 0.08, 0.16))
		# fences
		_fence_h(40.0, 640.0, 320.0)
		_fence_h(720.0, 1160.0, 320.0)
		_fence_v(860.0, 320.0, 480.0)
		_fence_v(860.0, 544.0, 760.0)

	func _post(x: float, y: float) -> void:
		draw_rect(Rect2(x - 2, y - 10, 4, 11), Color("3a281b"))
		draw_rect(Rect2(x - 1, y - 9, 2, 9), Color("9a6b40"))
		draw_rect(Rect2(x - 1, y - 9, 2, 1), Color("c99a62"))

	func _fence_h(x0: float, x1: float, y: float) -> void:
		draw_rect(Rect2(x0, y - 7, x1 - x0, 3), Color("3a281b"))
		draw_rect(Rect2(x0, y - 6, x1 - x0, 1), Color("b58650"))
		draw_rect(Rect2(x0, y - 3, x1 - x0, 3), Color("3a281b"))
		draw_rect(Rect2(x0, y - 2, x1 - x0, 1), Color("a37646"))
		var x := x0
		while x <= x1:
			_post(x, y)
			x += 24.0

	func _fence_v(x: float, y0: float, y1: float) -> void:
		draw_rect(Rect2(x - 1, y0 - 10, 3, y1 - y0 + 10), Color("3a281b"))
		draw_rect(Rect2(x, y0 - 9, 1, y1 - y0 + 8), Color("a37646"))
		var y := y0
		while y <= y1:
			_post(x, y)
			y += 24.0


class AmbientLayer extends Node2D:
	var w: Node2D
	var flies: Array = []
	var puffs: Array = []
	var _t := 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 34:
			flies.append({"p": Vector2(rng.randf_range(80, 1100), rng.randf_range(340, 740)), "ph": rng.randf() * 10.0, "sp": rng.randf_range(0.4, 1.0)})

	func _process(delta: float) -> void:
		if w == null:
			return
		_t += delta
		if randf() < delta * 1.4:
			puffs.append({"p": Vector2(w.SITES.home.x - 22, w.SITES.home.y - 88), "a": 0.0})
		for pf in puffs:
			pf.a += delta
			pf.p += Vector2(4.0 + sin(pf.a * 2.0) * 3.0, -9.0) * delta
		puffs = puffs.filter(func(pf: Dictionary) -> bool: return pf.a < 4.0)
		queue_redraw()

	func _draw() -> void:
		if w == null:
			return
		for pf in puffs:
			var k: float = pf.a / 4.0
			var c := Color(0.92, 0.92, 0.94, 0.5 * (1.0 - k)) if w.darkness < 0.5 else Color(0.8, 0.82, 0.9, 0.4 * (1.0 - k))
			draw_circle(pf.p, 2.0 + k * 4.0, c)
		if w.darkness > 0.4 and w.season != "winter" and w.weather != "rain":
			var amt: float = clampf((w.darkness - 0.4) * 2.0, 0.0, 1.0)
			for f in flies:
				var p: Vector2 = f.p + Vector2(sin(_t * f.sp + f.ph) * 14.0, cos(_t * f.sp * 1.3 + f.ph) * 9.0)
				var blink := 0.5 + 0.5 * sin(_t * 2.0 * f.sp + f.ph * 3.0)
				draw_circle(p, 3.0, Color(1.0, 0.95, 0.5, 0.12 * amt * blink))
				draw_rect(Rect2(p.x - 0.5, p.y - 0.5, 1.5, 1.5), Color(1.0, 1.0, 0.7, amt * blink))
		# tower light
		for n in w.statics:
			if is_instance_valid(n) and n.has_meta("tower"):
				var on := fmod(_t, 1.6) < 0.5
				var tp: Vector2 = n.position + Vector2(-1, -145)
				if on:
					draw_circle(tp, 4.0, Color(1, 0.2, 0.2, 0.25))
					draw_rect(Rect2(tp.x - 1, tp.y - 1, 3, 3), Color(1, 0.35, 0.3))
				var ring := fmod(_t, 2.4) / 2.4
				draw_arc(n.position + Vector2(22, -120), 6.0 + ring * 22.0, -0.9, 0.9, 12, Color(0.5, 0.9, 1.0, 0.5 * (1.0 - ring)), 1.0)


class FxLayer extends Node2D:
	var parts: Array = []

	func burst(p: Vector2, n: int, col: Color, spd: float, life: float, size: float) -> void:
		for i in n:
			var a := randf() * TAU
			parts.append({"p": p + Vector2(randf_range(-10, 10), randf_range(-4, 4)), "v": Vector2(cos(a), sin(a) * 0.5 - 0.4) * spd * randf_range(0.3, 1.0), "age": 0.0, "life": life * randf_range(0.6, 1.0), "size": size * randf_range(0.6, 1.4), "col": col, "kind": 0})

	func sparkle(p: Vector2, n: int) -> void:
		for i in n:
			var a := randf() * TAU
			parts.append({"p": p + Vector2(randf_range(-6, 6), randf_range(-30, 0)), "v": Vector2(cos(a), sin(a)) * randf_range(10, 36) + Vector2(0, -16), "age": 0.0, "life": randf_range(0.8, 1.5), "size": randf_range(1.5, 3.0), "col": Color(1.0, 0.9, 0.5), "kind": 1})

	func _process(delta: float) -> void:
		if parts.is_empty():
			return
		for q in parts:
			q.age += delta
			q.p += q.v * delta
			q.v *= 0.97
		parts = parts.filter(func(q: Dictionary) -> bool: return q.age < q.life)
		queue_redraw()

	func _draw() -> void:
		for q in parts:
			var k: float = q.age / q.life
			var c: Color = q.col
			c.a *= 1.0 - k
			if q.kind == 0:
				draw_circle(q.p, q.size * (0.6 + k), c)
			else:
				var s: float = q.size
				draw_rect(Rect2(q.p.x - s * 0.5, q.p.y - s * 0.5, s, s), c)
				draw_rect(Rect2(q.p.x - 0.5, q.p.y - s, 1, s * 2), c)
				draw_rect(Rect2(q.p.x - s, q.p.y - 0.5, s * 2, 1), c)
