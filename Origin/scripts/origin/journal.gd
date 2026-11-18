extends Control
## The journal: everything about your journey in one calm place.

signal closed

const UI = preload("res://scripts/origin/ui_kit.gd")
const Content = preload("res://scripts/origin/content.gd")

const TABS := ["Overview", "This Week", "Subjects", "History", "Village", "Achievements"]

var state: Node
var _content: Control
var _tab_buttons: Array = []
var _current := 0


func _ready() -> void:
	state = get_node("/root/OriginState")
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.1, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := UI.panel(UI.PARCH, UI.INK, 18)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -520
	panel.offset_right = 520
	panel.offset_top = -318
	panel.offset_bottom = 318
	add_child(panel)
	var col := UI.vbox(10)
	panel.add_child(col)
	var head := UI.hbox(8)
	col.add_child(head)
	var t := UI.heading("Journal", 32)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := UI.button("Close  (J)", "parch", 17, Vector2(120, 38))
	close.pressed.connect(close_journal)
	head.add_child(close)
	var tabs := UI.hbox(6)
	col.add_child(tabs)
	for i in TABS.size():
		var b := UI.button(TABS[i], "parch", 17, Vector2(0, 38))
		b.toggle_mode = true
		b.pressed.connect(show_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_content = UI.vbox(10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)


func open_journal(tab: int = 0) -> void:
	visible = true
	show_tab(tab)


func close_journal() -> void:
	visible = false
	closed.emit()


func show_tab(i: int) -> void:
	_current = i
	for k in _tab_buttons.size():
		(_tab_buttons[k] as Button).set_pressed_no_signal(k == i)
	for c in _content.get_children():
		c.queue_free()
	match i:
		0: _overview()
		1: _week()
		2: _subjects()
		3: _history()
		4: _village()
		5: _achievements()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("o_journal") or event.is_action_pressed("pause"):
		close_journal()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT or event.keycode == KEY_Q:
			show_tab((_current + TABS.size() - 1) % TABS.size())
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_E:
			show_tab((_current + 1) % TABS.size())
			get_viewport().set_input_as_handled()


func _card(color: Color = UI.PARCH_D) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(color, UI.INK_L, 2, 12, false))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


func _stat(title: String, value: String, sub: String = "") -> Control:
	var c := _card()
	var v := UI.vbox(0)
	c.add_child(v)
	v.add_child(UI.label(title, 15, UI.INK_L))
	v.add_child(UI.label(value, 28, UI.INK, true))
	if sub != "":
		v.add_child(UI.label(sub, 14, UI.INK_L))
	return c


# ---------------------------------------------------------------------------------------------
func _overview() -> void:
	var lp: Dictionary = state.level_progress()
	var top := _card(Color("e9d6a4"))
	_content.add_child(top)
	var tv := UI.vbox(6)
	top.add_child(tv)
	tv.add_child(UI.label("%s" % state.d.name, 30, UI.INK, true))
	tv.add_child(UI.label("Level %d  -  %s" % [lp.level, lp.title], 22, Color("7a5a1a"), true))
	var row := UI.hbox(10)
	tv.add_child(row)
	row.add_child(UI.bar(lp.frac, 18, UI.GOLD))
	row.add_child(UI.label("%d / %d XP" % [lp.into, lp.need], 17, UI.INK_L))
	var vl: int = state.village_level()
	tv.add_child(UI.label("Village level %d  -  %s" % [vl, Content.village_title(vl)], 20, Color("2f6a3a"), true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	grid.add_child(_stat("Total study time", UI.fmt_duration(int(state.d.seconds))))
	grid.add_child(_stat("Sessions", str(state.session_count())))
	grid.add_child(_stat("Days you showed up", str(state.days_count())))
	grid.add_child(_stat("Today", UI.fmt_duration(state.today_seconds()) if state.today_seconds() > 0 else "Not yet", "No pressure"))
	var r: int = state.rhythm()
	grid.add_child(_stat("Your rhythm", "%d day%s" % [r, "" if r == 1 else "s"] if r > 0 else "Starting fresh", "Breaks never erase progress"))
	grid.add_child(_stat("Achievements", "%d / %d" % [state.achievements_unlocked(), Content.ACHIEVEMENTS.size()]))
	var msg := _card(Color("dfe9c8"))
	_content.add_child(msg)
	msg.add_child(UI.wrap_label(_encouragement(), 19, Color("3a5a2a")))
	# milestones
	_content.add_child(UI.label("Milestones", 22, UI.INK, true))
	var mg := GridContainer.new()
	mg.columns = 3
	mg.add_theme_constant_override("h_separation", 10)
	mg.add_theme_constant_override("v_separation", 8)
	_content.add_child(mg)
	var mins: float = state.total_minutes()
	for m in [[1, "First minute"], [60, "One hour"], [300, "Five hours"], [600, "Ten hours"], [1500, "Twenty-five hours"], [3000, "Fifty hours"]]:
		var done: bool = mins >= m[0]
		var c := _card(Color("dfe9c8") if done else Color("d9cba6"))
		c.add_child(UI.label(("Done  " if done else "")+ m[1], 17, Color("3a5a2a") if done else UI.INK_L, done))
		mg.add_child(c)


func _encouragement() -> String:
	var gap: int = state.days_since_last_study()
	if state.session_count() == 0:
		return "Your journey starts with a single page. The lamp is lit and the village is waiting."
	if gap >= 2:
		return "It is good to see you. Taking time away is part of learning. Whenever you sit under the lamp, the village is glad."
	if state.rhythm() >= 3:
		return "You have been showing up. The village is growing around that quiet consistency."
	return "Every session is a stone in the road. Keep laying them, at your own pace."


func _week() -> void:
	var days: Array = state.week_days()
	var total: int = state.week_seconds()
	var top := UI.hbox(10)
	_content.add_child(top)
	top.add_child(_stat("This week", UI.fmt_duration(total) if total > 0 else "Nothing yet"))
	top.add_child(_stat("Days showed up", "%d / 7" % state.days_this_week()))
	var studied := 0
	for d: Dictionary in days:
		if d.seconds > 0:
			studied += 1
	top.add_child(_stat("Average on study days", UI.fmt_duration(total / maxi(1, studied)) if total > 0 else "-"))
	var chart_card := _card(Color("efe0b8"))
	_content.add_child(chart_card)
	var chart := WeekChart.new()
	chart.days = days
	chart.custom_minimum_size = Vector2(0, 280)
	chart_card.add_child(chart)
	_content.add_child(UI.wrap_label("Rest days are part of the rhythm. The village does not mind a quiet day.", 18, UI.INK_L))


func _subjects() -> void:
	var arr: Array = state.subject_totals()
	if arr.is_empty():
		_content.add_child(UI.wrap_label("No subjects yet. Study a first session to see where your time goes.", 20, UI.INK_L))
		return
	var total := 0
	for a: Dictionary in arr:
		total += a.seconds
	for a: Dictionary in arr:
		var s: Dictionary = Content.subject_by_name(a.name, state.d.custom_subjects)
		var c := _card()
		_content.add_child(c)
		var row := UI.hbox(12)
		c.add_child(row)
		row.add_child(UI.badge(s.code, s.color, 44))
		var v := UI.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var head := UI.hbox(8)
		v.add_child(head)
		var nm := UI.label(a.name, 20, UI.INK, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(nm)
		head.add_child(UI.label("%s  (%d%%)" % [UI.fmt_duration(a.seconds), int(round(100.0 * a.seconds / maxf(1.0, total)))], 17, UI.INK_L))
		v.add_child(UI.bar(float(a.seconds) / float(arr[0].seconds), 12, s.color))


func _history() -> void:
	var sessions: Array = state.d.sessions
	if sessions.is_empty():
		_content.add_child(UI.wrap_label("Your study history will appear here, session by session.", 20, UI.INK_L))
		return
	var shown := 0
	for i in range(sessions.size() - 1, -1, -1):
		var s: Dictionary = sessions[i]
		var sub: Dictionary = Content.subject_by_name(s.subject, state.d.custom_subjects)
		var c := _card()
		_content.add_child(c)
		var row := UI.hbox(12)
		c.add_child(row)
		row.add_child(UI.badge(sub.code, sub.color, 36))
		var v := UI.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var tag := "  (with Asha)" if s.get("mentor", false) else ""
		v.add_child(UI.label("%s%s" % [s.subject, tag], 19, UI.INK, true))
		v.add_child(UI.label(_date_text(int(s.ts)), 14, UI.INK_L))
		row.add_child(UI.label(UI.fmt_duration(int(s.seconds)), 19, UI.INK, true))
		row.add_child(UI.label("+%d XP" % int(s.xp), 18, Color("8a5a10"), true))
		shown += 1
		if shown >= 60:
			break


func _date_text(ts: int) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(ts + int(Time.get_time_zone_from_system().bias) * 60)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var h: int = dt.hour
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%s %d, %d:%02d %s" % [months[dt.month - 1], dt.day, h12, dt.minute, suffix]


func _village() -> void:
	var m: Dictionary = state.metrics()
	var lv: Dictionary = state.levels()
	var shown: Dictionary = state.shown_levels()
	var vl: int = state.village_level()
	var head := _card(Color("dfe9c8"))
	_content.add_child(head)
	var hv := UI.vbox(4)
	head.add_child(hv)
	hv.add_child(UI.label("%s  -  Village level %d" % [Content.village_title(vl), vl], 24, Color("2f5a2a"), true))
	if state.ended():
		hv.add_child(UI.wrap_label("The village has everything it needs to keep growing without you. Now it is Asha's turn.", 17, UI.INK_L))
	else:
		hv.add_child(UI.wrap_label(Content.finale_goal_text(m, lv), 17, UI.INK_L))
	for id: String in Content.BUILDING_ORDER:
		var b: Dictionary = Content.BUILDINGS[id]
		var cur: int = lv[id]
		var c := _card()
		_content.add_child(c)
		var v := UI.vbox(4)
		c.add_child(v)
		var r := UI.hbox(8)
		v.add_child(r)
		var nm := UI.label(b.name, 21, UI.INK, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(nm)
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.box(UI.WOODC, UI.INK, 2, 4, false))
		chip.add_child(UI.label(b.pillar.to_upper(), 13, UI.CREAM, true))
		r.add_child(chip)
		v.add_child(UI.label("Level %d / %d  -  %s" % [cur, Content.max_level(id), b.levels[cur]], 17, Color("7a5a1a")))
		var goal: Dictionary = Content.next_goal(id, m, lv)
		var br := UI.hbox(10)
		v.add_child(br)
		br.add_child(UI.bar(goal.frac, 12, UI.MOSS))
		v.add_child(UI.wrap_label(b.meaning if goal.done else "Next: " + goal.text, 15, UI.INK_L))
	for z: String in Content.ZONES:
		var open: bool = state.zone_open(z)
		var c := _card(Color("dfe9c8") if open else Color("d9cba6"))
		_content.add_child(c)
		c.add_child(UI.label(("%s  (open)" % Content.ZONES[z].name) if open else ("%s  -  %s" % [Content.ZONES[z].name, Content.ZONES[z].hint]), 17, UI.INK))


func _achievements() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	for a: Dictionary in Content.ACHIEVEMENTS:
		var got: bool = state.has_achievement(a.id)
		var c := _card(Color("f0dc9a") if got else Color("d4c7a2"))
		grid.add_child(c)
		var v := UI.vbox(2)
		c.add_child(v)
		v.add_child(UI.label(("%s" % a.name) if got else "Locked  -  %s" % a.name, 19, UI.INK if got else UI.INK_L, true))
		v.add_child(UI.wrap_label(a.desc, 15, UI.INK_L))


class WeekChart extends Control:
	var days: Array = []

	func _draw() -> void:
		var maxv := 1.0
		for d: Dictionary in days:
			maxv = maxf(maxv, float(d.seconds))
		var f := ThemeDB.fallback_font
		var left := 56.0
		var bottom := size.y - 34.0
		var top := 22.0
		var h := bottom - top
		for i in 5:
			var y := bottom - h * i / 4.0
			draw_line(Vector2(left, y), Vector2(size.x - 10, y), Color(0.3, 0.2, 0.1, 0.18), 1.0)
			var mins := int(round(maxv / 60.0 * i / 4.0))
			draw_string(f, Vector2(4, y + 5), "%dm" % mins, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("6e5539"))
		var slot := (size.x - left - 10.0) / days.size()
		for i in days.size():
			var d: Dictionary = days[i]
			var bh := h * float(d.seconds) / maxv
			var x := left + slot * i + slot * 0.18
			var w := slot * 0.64
			var col := Color("5d8f46") if not d.today else Color("e2a93a")
			if d.seconds > 0:
				draw_rect(Rect2(x - 2, bottom - bh - 2, w + 4, bh + 4), Color("2a1b14"))
				draw_rect(Rect2(x, bottom - bh, w, bh), col)
				draw_rect(Rect2(x, bottom - bh, w, 3), col.lightened(0.35))
				draw_string(f, Vector2(x, bottom - bh - 8), "%dm" % int(round(d.seconds / 60.0)), HORIZONTAL_ALIGNMENT_LEFT, w, 15, Color("3b2a1a"))
			else:
				draw_rect(Rect2(x, bottom - 3, w, 3), Color(0.3, 0.2, 0.1, 0.25))
			draw_string(f, Vector2(x, bottom + 22), d.label + (" *" if d.today else ""), HORIZONTAL_ALIGNMENT_LEFT, w + 8, 16, Color("3b2a1a"))
