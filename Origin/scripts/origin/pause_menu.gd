extends Control
## Pause menu: resume, journal, sky controls (time, weather, season), settings, return to title.

signal resume_requested
signal journal_requested
signal title_requested
signal reduced_motion_changed(on: bool)

const UI = preload("res://scripts/origin/ui_kit.gd")

var world: Node2D
var state: Node
var _hour_slider: HSlider
var _hour_label: Label
var _freeze: CheckButton
var _reduced: CheckButton
var _weather_btns: Dictionary = {}
var _season_btns: Dictionary = {}
var _badge: Label
var _syncing := false


func _ready() -> void:
	state = get_node("/root/OriginState")
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.1, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := UI.panel(UI.PARCH, UI.INK, 20)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(620, 0)
	add_child(p)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.heading("Paused", 34))
	_badge = UI.label("", 16, Color("a0501e"), true)
	v.add_child(_badge)
	var row := UI.hbox(10)
	v.add_child(row)
	var res := UI.button("Resume", "moss", 20, Vector2(0, 48))
	res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res.pressed.connect(func() -> void: resume_requested.emit())
	row.add_child(res)
	var jr := UI.button("Journal", "wood", 20, Vector2(0, 48))
	jr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jr.pressed.connect(func() -> void: journal_requested.emit())
	row.add_child(jr)
	v.add_child(HSeparator.new())
	v.add_child(UI.label("The sky", 20, UI.INK, true))
	var hrow := UI.hbox(10)
	v.add_child(hrow)
	hrow.add_child(UI.label("Time of day", 17, UI.INK_L))
	_hour_slider = HSlider.new()
	_hour_slider.min_value = 0.0
	_hour_slider.max_value = 23.9
	_hour_slider.step = 0.1
	_hour_slider.custom_minimum_size = Vector2(260, 24)
	_hour_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hour_slider.value_changed.connect(_on_hour)
	hrow.add_child(_hour_slider)
	_hour_label = UI.label("", 17, UI.INK, true)
	_hour_label.custom_minimum_size = Vector2(90, 0)
	hrow.add_child(_hour_label)
	_freeze = CheckButton.new()
	_freeze.text = "Hold time still"
	_freeze.add_theme_color_override("font_color", UI.INK)
	_freeze.toggled.connect(func(on: bool) -> void:
		if world and not _syncing:
			world.time_frozen = on)
	v.add_child(_freeze)
	var wrow := UI.hbox(8)
	v.add_child(wrow)
	wrow.add_child(UI.label("Weather", 17, UI.INK_L))
	for w in [["sunny", "Clear"], ["cloudy", "Cloudy"], ["rain", "Rain"], ["snow", "Snow"]]:
		var b := UI.button(w[1], "parch", 16, Vector2(80, 36))
		b.toggle_mode = true
		b.pressed.connect(_on_weather.bind(w[0]))
		wrow.add_child(b)
		_weather_btns[w[0]] = b
	var srow := UI.hbox(8)
	v.add_child(srow)
	srow.add_child(UI.label("Season", 17, UI.INK_L))
	for s in [["spring", "Spring"], ["summer", "Summer"], ["autumn", "Autumn"], ["winter", "Winter"]]:
		var b := UI.button(s[1], "parch", 16, Vector2(80, 36))
		b.toggle_mode = true
		b.pressed.connect(_on_season.bind(s[0]))
		srow.add_child(b)
		_season_btns[s[0]] = b
	v.add_child(HSeparator.new())
	_reduced = CheckButton.new()
	_reduced.text = "Reduce motion (fewer drifting particles)"
	_reduced.add_theme_color_override("font_color", UI.INK)
	_reduced.toggled.connect(func(on: bool) -> void:
		if not _syncing:
			state.d.settings.reduced_motion = on
			state.save()
			reduced_motion_changed.emit(on))
	v.add_child(_reduced)
	var trow := UI.hbox(0)
	trow.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(trow)
	var tb := UI.button("Save and return to title", "parch", 18, Vector2(260, 44))
	tb.pressed.connect(func() -> void: title_requested.emit())
	trow.add_child(tb)


func open_menu() -> void:
	visible = true
	_syncing = true
	_badge.text = "STORY PREVIEW  (separate save, your real progress is safe)" if state.slot == "preview" else ""
	_badge.visible = _badge.text != ""
	if world:
		_hour_slider.value = world.hour
		_hour_label.text = world.time_text()
		_freeze.button_pressed = world.time_frozen
		for k: String in _weather_btns:
			(_weather_btns[k] as Button).set_pressed_no_signal(k == world.weather)
		for k: String in _season_btns:
			(_season_btns[k] as Button).set_pressed_no_signal(k == world.season)
	_reduced.button_pressed = bool(state.d.settings.get("reduced_motion", false))
	_syncing = false


func _on_hour(val: float) -> void:
	if _syncing or world == null:
		return
	world.set_sky(val, "", "")
	_hour_label.text = world.time_text()


func _on_weather(w: String) -> void:
	if world == null:
		return
	world.weather_locked = true
	world.set_sky(world.hour, w, "")
	for k: String in _weather_btns:
		(_weather_btns[k] as Button).set_pressed_no_signal(k == w)


func _on_season(s: String) -> void:
	if world == null:
		return
	world.set_sky(world.hour, "", s)
	for k: String in _season_btns:
		(_season_btns[k] as Button).set_pressed_no_signal(k == s)
