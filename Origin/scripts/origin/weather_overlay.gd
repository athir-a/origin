extends Control
## Screen-space weather and seasonal drift: rain, snow, petals, falling leaves, birds.

var world: Node2D
var drops: Array = []
var motes: Array = []
var birds: Array = []
var _t := 0.0
var reduced_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 170:
		drops.append({"x": rng.randf() * 1300.0, "y": rng.randf() * 740.0, "s": rng.randf_range(0.8, 1.3), "r": rng.randf()})
	for i in 40:
		motes.append({"x": rng.randf() * 1300.0, "y": rng.randf() * 740.0, "s": rng.randf_range(0.6, 1.4), "ph": rng.randf() * 10.0})
	for i in 3:
		birds.append({"x": -100.0 - i * 260.0, "y": 60.0 + i * 38.0, "s": 40.0 + i * 8.0, "ph": float(i)})


func _process(delta: float) -> void:
	if world == null or not visible:
		return
	_t += delta
	var h := Vector2(get_viewport_rect().size)
	for d in drops:
		if world.weather == "rain":
			d.y += 560.0 * d.s * delta
			d.x -= 110.0 * d.s * delta
		else:
			d.y += 46.0 * d.s * delta
			d.x += sin(_t + d.r * 6.0) * 14.0 * delta
		if d.y > h.y + 10.0:
			d.y = -12.0
			d.x = randf() * (h.x + 120.0)
		if d.x < -20.0:
			d.x = h.x + 10.0
	for m in motes:
		m.y += 22.0 * m.s * delta
		m.x += (18.0 + sin(_t * 0.8 + m.ph) * 16.0) * m.s * delta
		if m.y > h.y + 8.0:
			m.y = -8.0
			m.x = randf() * h.x
		if m.x > h.x + 8.0:
			m.x = -8.0
	for b in birds:
		b.x += b.s * delta
		if b.x > h.x + 80.0:
			b.x = -90.0 - randf() * 300.0
			b.y = randf_range(40.0, 170.0)
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var amt: float = world.weather_amount
	if world.weather == "rain" and amt > 0.05:
		var c := Color(0.75, 0.84, 0.95, 0.5 * amt)
		for d in drops:
			draw_line(Vector2(d.x, d.y), Vector2(d.x - 5.0, d.y + 14.0 * d.s), c, 2.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.14, 0.24, 0.12 * amt))
	elif world.weather == "snow" and amt > 0.05:
		for d in drops:
			var s := 3.0 if d.r > 0.5 else 2.0
			draw_rect(Rect2(d.x, d.y, s, s), Color(1, 1, 1, 0.85 * amt))
	elif world.weather == "cloudy" and amt > 0.05:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.4, 0.5, 0.08 * amt))
	if reduced_motion:
		return
	# seasonal drift on clear and cloudy days
	if world.weather in ["sunny", "cloudy"]:
		var col := Color(0, 0, 0, 0)
		match world.season:
			"autumn": col = Color(0.88, 0.5, 0.18, 0.9)
			"spring": col = Color(1.0, 0.75, 0.82, 0.8)
		if col.a > 0.0:
			for i in 18:
				var m: Dictionary = motes[i]
				draw_rect(Rect2(m.x, m.y, 4, 3), col)
				draw_rect(Rect2(m.x + 1, m.y + 1, 2, 1), col.lightened(0.25))
	# birds on bright, clear days
	if world.weather == "sunny" and world.darkness < 0.25:
		for b in birds:
			var f := 1 if sin(_t * 9.0 + b.ph) > 0.0 else -1
			var p := Vector2(b.x, b.y + sin(_t + b.ph) * 6.0)
			var c := Color("2e2a3a")
			draw_rect(Rect2(p.x - 6, p.y + f, 4, 2), c)
			draw_rect(Rect2(p.x - 2, p.y, 4, 2), c)
			draw_rect(Rect2(p.x + 2, p.y + f, 4, 2), c)
