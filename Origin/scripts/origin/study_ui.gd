extends Control
## Study flow: pick a subject and goal, then settle into the animated study scene.

signal session_finished(subject: String, seconds: int, target_min: int)
signal session_abandoned
signal setup_cancelled
signal session_started

const UI = preload("res://scripts/origin/ui_kit.gd")
const Content = preload("res://scripts/origin/content.gd")
const StudyScene = preload("res://scripts/origin/study_scene.gd")

const TIER_NAMES := [
	"Cross-legged beneath the street lamp",
	"A reading corner with a lantern and a few books",
	"A proper desk by the window, with electric light",
	"A desk with a computer and a growing bookshelf",
	"The village study hall, full of light",
]
const QUOTES := [
	"Small steps still move you forward.",
	"Breathe. One page at a time.",
	"You do not have to be perfect, only present.",
	"The lamp is lit. The village is with you.",
	"Rest is part of learning too.",
	"Where you begin does not decide where you end.",
]

var state: Node
var scene: Control
var _setup: Control
var _run: Control
var _confirm: Control
var _confirm_box: VBoxContainer

var subject := "Mathematics"
var target_min := 25
var mentor := false
var running := false
var paused := false
var _start_ms := 0
var _paused_ms := 0
var _pause_began := 0
var _goal_shown := false
var _quote_t := 0.0
var _quote_i := 0

# setup widgets
var _subject_grid: GridContainer
var _subject_buttons: Dictionary = {}
var _duration_buttons: Array = []
var _custom_edit: LineEdit
var _setup_title: Label
var _setup_sub: Label
var _env_label: Label
# run widgets
var _clock: Label
var _subject_lbl: Label
var _goal_bar: Control
var _goal_lbl: Label
var _pause_btn: Button
var _angle_buttons: Dictionary = {}
var _toast: Label
var _paused_banner: Control
var _quote_lbl: Label
var _xp_lbl: Label
var _env_run: Label


func _ready() -> void:
	state = get_node("/root/OriginState")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene = StudyScene.new()
	scene.visible = false
	add_child(scene)
	_build_setup()
	_build_run()
	_build_confirm()
	_setup.visible = false
	_run.visible = false
	_confirm.visible = false
	visible = false


# ---------------------------------------------------------------------------------------------
# Setup panel
# ---------------------------------------------------------------------------------------------
func _build_setup() -> void:
	_setup = Control.new()
	_setup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_setup)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.14, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup.add_child(dim)
	var panel := UI.panel(UI.PARCH, UI.INK, 18)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(800, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_setup.add_child(panel)
	var col := UI.vbox(10)
	panel.add_child(col)
	_setup_title = UI.heading("Settle in beneath the lamp", 32)
	col.add_child(_setup_title)
	_setup_sub = UI.wrap_label("Choose what you will study. There is no wrong answer, and no pressure. Showing up is the whole point.", 17, UI.INK_L)
	col.add_child(_setup_sub)
	col.add_child(UI.label("What will you study?", 19, UI.INK, true))
	_subject_grid = GridContainer.new()
	_subject_grid.columns = 4
	_subject_grid.add_theme_constant_override("h_separation", 8)
	_subject_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(_subject_grid)
	var custom_row := UI.hbox(8)
	col.add_child(custom_row)
	_custom_edit = LineEdit.new()
	_custom_edit.placeholder_text = "Or add your own subject..."
	_custom_edit.max_length = 22
	_custom_edit.custom_minimum_size = Vector2(300, 38)
	_custom_edit.add_theme_font_size_override("font_size", 18)
	_custom_edit.add_theme_color_override("font_color", UI.INK)
	_custom_edit.add_theme_color_override("font_placeholder_color", UI.INK_L)
	_custom_edit.add_theme_stylebox_override("normal", UI.box(Color("fff6dc"), UI.INK, 2, 8, false))
	_custom_edit.add_theme_stylebox_override("focus", UI.box(Color("fff6dc"), Color("c78a1e"), 3, 8, false))
	_custom_edit.text_submitted.connect(func(_t: String) -> void: _add_custom())
	custom_row.add_child(_custom_edit)
	var add := UI.button("Add subject", "parch", 17, Vector2(0, 38))
	add.pressed.connect(_add_custom)
	custom_row.add_child(add)
	col.add_child(UI.label("For how long?", 19, UI.INK, true))
	var drow := UI.hbox(8)
	col.add_child(drow)
	for dur: Dictionary in Content.DURATIONS:
		var b := UI.button(dur.label, "parch", 17, Vector2(98, 40))
		b.toggle_mode = true
		b.set_meta("minutes", dur.minutes)
		b.pressed.connect(_pick_duration.bind(dur.minutes))
		drow.add_child(b)
		_duration_buttons.append(b)
	_env_label = UI.wrap_label("", 16, UI.INK_L)
	col.add_child(_env_label)
	var foot := UI.hbox(12)
	foot.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(foot)
	var cancel := UI.button("Not now", "parch", 19, Vector2(150, 46))
	cancel.pressed.connect(func() -> void:
		_setup.visible = false
		visible = false
		setup_cancelled.emit())
	foot.add_child(cancel)
	var go := UI.button("Begin studying", "moss", 21, Vector2(230, 46))
	go.pressed.connect(_begin)
	foot.add_child(go)


func _rebuild_subjects() -> void:
	for c in _subject_grid.get_children():
		c.queue_free()
	_subject_buttons.clear()
	for s: Dictionary in state.subjects_all():
		var b := UI.button("  " + s.name, "parch", 16, Vector2(184, 44))
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_meta("subject", s.name)
		var bar := ColorRect.new()
		bar.color = s.color
		bar.custom_minimum_size = Vector2(8, 0)
		bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		bar.offset_left = 6
		bar.offset_right = 14
		bar.offset_top = 8
		bar.offset_bottom = -8
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bar)
		b.text = "      " + s.name
		b.pressed.connect(_pick_subject.bind(s.name))
		_subject_grid.add_child(b)
		_subject_buttons[s.name] = b
	_pick_subject(subject if _subject_buttons.has(subject) else "Mathematics")


func _pick_subject(n: String) -> void:
	subject = n
	for k: String in _subject_buttons:
		(_subject_buttons[k] as Button).set_pressed_no_signal(k == n)


func _pick_duration(m: int) -> void:
	target_min = m
	for b: Button in _duration_buttons:
		b.set_pressed_no_signal(int(b.get_meta("minutes")) == m)


func _add_custom() -> void:
	var n: String = state.add_custom_subject(_custom_edit.text)
	_custom_edit.text = ""
	if n == "":
		return
	_rebuild_subjects()
	_pick_subject(n)


func open_setup(is_mentor: bool, env_opts: Dictionary) -> void:
	mentor = is_mentor
	scene.configure(env_opts)
	subject = str(state.d.last_subject)
	target_min = int(state.d.last_target)
	_setup_title.text = "Study beside Asha" if mentor else "Settle in beneath the lamp"
	_setup_sub.text = ("Hold the lamp for her. Teaching is the deepest way to learn." if mentor
		else "Choose what you will study. There is no wrong answer, and no pressure. Showing up is the whole point.")
	_env_label.text = "Your study spot: " + TIER_NAMES[env_opts.get("tier", 0)]
	_rebuild_subjects()
	_pick_duration(target_min)
	visible = true
	_setup.visible = true
	_run.visible = false
	scene.visible = false
	await get_tree().process_frame
	if _subject_buttons.has(subject):
		(_subject_buttons[subject] as Button).grab_focus()


# ---------------------------------------------------------------------------------------------
# Run overlay
# ---------------------------------------------------------------------------------------------
func _build_run() -> void:
	_run = Control.new()
	_run.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_run.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_run)
	# top-left: what you are studying
	var tl := UI.panel(Color(0.1, 0.09, 0.16, 0.78), Color("0c0a12"), 12)
	tl.position = Vector2(20, 18)
	_run.add_child(tl)
	var tlc := UI.vbox(2)
	tl.add_child(tlc)
	_subject_lbl = UI.label("Mathematics", 24, UI.CREAM, true)
	tlc.add_child(_subject_lbl)
	_env_run = UI.label("", 14, Color("c9bfa0"))
	tlc.add_child(_env_run)
	# top-center: the big clock
	var tc := UI.panel(Color(0.1, 0.09, 0.16, 0.78), Color("0c0a12"), 12)
	tc.anchor_left = 0.5
	tc.anchor_right = 0.5
	tc.offset_left = -150
	tc.offset_right = 150
	tc.offset_top = 14
	tc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_run.add_child(tc)
	var tcc := UI.vbox(4)
	tc.add_child(tcc)
	_clock = UI.title("00:00", 54, UI.CREAM)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tcc.add_child(_clock)
	_goal_bar = UI.bar(0.0, 12, UI.GOLD, Color("2a2540"))
	tcc.add_child(_goal_bar)
	_goal_lbl = UI.label("", 15, Color("c9bfa0"))
	_goal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tcc.add_child(_goal_lbl)
	# top-right: view angle
	var tr := UI.panel(Color(0.1, 0.09, 0.16, 0.78), Color("0c0a12"), 10)
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -276
	tr.offset_right = -20
	tr.offset_top = 18
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_run.add_child(tr)
	var trc := UI.vbox(6)
	tr.add_child(trc)
	trc.add_child(UI.label("Camera angle", 15, Color("c9bfa0")))
	var arow := UI.hbox(6)
	trc.add_child(arow)
	for def in [["side", "Side", "1"], ["top", "Over shoulder", "2"], ["pov", "POV", "3"]]:
		var b := UI.button(def[1], "night", 15, Vector2(0, 36))
		b.toggle_mode = true
		b.tooltip_text = "Key %s" % def[2]
		b.pressed.connect(_set_angle.bind(def[0]))
		arow.add_child(b)
		_angle_buttons[def[0]] = b
	trc.add_child(UI.label("Keys 1 / 2 / 3 or C", 13, Color("9a92b0")))
	# bottom controls
	var bottom := UI.hbox(14)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -78
	bottom.offset_bottom = -22
	_run.add_child(bottom)
	_pause_btn = UI.button("Pause", "night", 20, Vector2(160, 52))
	_pause_btn.pressed.connect(_toggle_pause)
	bottom.add_child(_pause_btn)
	var fin := UI.button("Finish and record", "moss", 20, Vector2(240, 52))
	fin.pressed.connect(_finish_pressed)
	bottom.add_child(fin)
	var leave := UI.button("Step away", "night", 20, Vector2(160, 52))
	leave.pressed.connect(_leave_pressed)
	bottom.add_child(leave)
	# bottom-left: quote
	_quote_lbl = UI.label(QUOTES[0], 16, Color("e8dcb8"))
	_quote_lbl.position = Vector2(24, 650)
	_quote_lbl.add_theme_color_override("font_outline_color", Color("120e18"))
	_quote_lbl.add_theme_constant_override("outline_size", 6)
	_quote_lbl.anchor_top = 1.0
	_quote_lbl.anchor_bottom = 1.0
	_quote_lbl.offset_top = -108
	_quote_lbl.offset_left = 24
	_run.add_child(_quote_lbl)
	_xp_lbl = UI.label("", 16, Color("f0d890"))
	_xp_lbl.anchor_left = 1.0
	_xp_lbl.anchor_right = 1.0
	_xp_lbl.anchor_top = 1.0
	_xp_lbl.anchor_bottom = 1.0
	_xp_lbl.offset_left = -300
	_xp_lbl.offset_top = -108
	_xp_lbl.offset_right = -24
	_xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_xp_lbl.add_theme_color_override("font_outline_color", Color("120e18"))
	_xp_lbl.add_theme_constant_override("outline_size", 6)
	_run.add_child(_xp_lbl)
	# toast + paused banner
	_toast = UI.label("", 20, UI.CREAM, true)
	_toast.add_theme_color_override("font_outline_color", Color("120e18"))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.offset_top = 128
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_run.add_child(_toast)
	_paused_banner = UI.panel(Color(0.08, 0.07, 0.14, 0.82), Color("0c0a12"), 14)
	_paused_banner.set_anchors_preset(Control.PRESET_CENTER)
	_paused_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_paused_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	var pb := UI.vbox(2)
	_paused_banner.add_child(pb)
	var pt := UI.title("Paused", 36, UI.CREAM)
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb.add_child(pt)
	pb.add_child(UI.label("Take your time. The lamp will wait.", 18, Color("d6cca8")))
	_paused_banner.visible = false
	_run.add_child(_paused_banner)


func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var p := UI.panel(UI.PARCH, UI.INK, 20)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(520, 0)
	_confirm.add_child(p)
	var v := UI.vbox(10)
	_confirm_box = v
	p.add_child(v)


func _ask(title: String, body: String, buttons: Array) -> void:
	var v: VBoxContainer = _confirm_box
	for c in v.get_children():
		c.queue_free()
	v.add_child(UI.heading(title, 28))
	v.add_child(UI.wrap_label(body, 18, UI.INK_L))
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	for b: Dictionary in buttons:
		var btn := UI.button(b.text, b.kind, 18, Vector2(150, 44))
		btn.pressed.connect(func() -> void:
			_confirm.visible = false
			b.call.call())
		row.add_child(btn)
	_confirm.visible = true


# ---------------------------------------------------------------------------------------------
# Session control
# ---------------------------------------------------------------------------------------------
func _begin() -> void:
	_setup.visible = false
	running = true
	paused = false
	_goal_shown = false
	_start_ms = Time.get_ticks_msec()
	_paused_ms = 0
	scene.visible = true
	scene.t = 0.0
	scene.paused = false
	_run.visible = true
	_paused_banner.visible = false
	_pause_btn.text = "Pause"
	var s: Dictionary = Content.subject_by_name(subject, state.d.custom_subjects)
	scene.book_col = (s.color as Color).darkened(0.15)
	scene.mentor = mentor
	_subject_lbl.text = ("With Asha: " if mentor else "") + subject
	_env_run.text = TIER_NAMES[scene.tier]
	_goal_bar.visible = target_min > 0
	_set_angle(_current_angle())
	_quote_t = 0.0
	session_started.emit()


func _current_angle() -> String:
	return scene.angle if scene.angle in ["side", "top", "pov"] else "side"


func _set_angle(a: String) -> void:
	scene.set_angle(a)
	for k: String in _angle_buttons:
		(_angle_buttons[k] as Button).set_pressed_no_signal(k == a)


func elapsed_seconds() -> int:
	if not running:
		return 0
	var now := Time.get_ticks_msec()
	var p := _paused_ms + ((now - _pause_began) if paused else 0)
	return maxi(0, (now - _start_ms - p) / 1000)


func _toggle_pause() -> void:
	if not running:
		return
	paused = not paused
	if paused:
		_pause_began = Time.get_ticks_msec()
	else:
		_paused_ms += Time.get_ticks_msec() - _pause_began
	scene.paused = paused
	_paused_banner.visible = paused
	_pause_btn.text = "Resume" if paused else "Pause"


func _finish_pressed() -> void:
	var secs := elapsed_seconds()
	if secs < state.MIN_RECORD_SECONDS:
		_ask("Just a moment", "A session needs at least a minute to be recorded. Keep going a little longer, or step away. Nothing is lost either way.",
			[{"text": "Keep going", "kind": "moss", "call": func() -> void: pass},
			 {"text": "Step away", "kind": "parch", "call": _abandon}])
		return
	if not paused:
		_toggle_pause()
	_ask("Finish this session?", "You studied %s of %s. Record it and see how the village grows?" % [UI.fmt_duration(secs), subject],
		[{"text": "Not yet", "kind": "parch", "call": func() -> void: if paused: _toggle_pause()},
		 {"text": "Record it", "kind": "moss", "call": _finish}])


func _finish() -> void:
	var secs := elapsed_seconds()
	running = false
	_run.visible = false
	scene.visible = false
	visible = false
	session_finished.emit(subject, secs, target_min)


func _leave_pressed() -> void:
	if not paused:
		_toggle_pause()
	_ask("Step away?", "Leave without recording? That is okay. You can come back to the lamp anytime, and nothing is taken from you.",
		[{"text": "Stay", "kind": "moss", "call": func() -> void: if paused: _toggle_pause()},
		 {"text": "Step away", "kind": "parch", "call": _abandon}])


func _abandon() -> void:
	running = false
	_run.visible = false
	scene.visible = false
	visible = false
	session_abandoned.emit()


func refresh_env(opts: Dictionary) -> void:
	scene.configure(opts)


func _toast_msg(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 1.2)


func _process(delta: float) -> void:
	if not running:
		return
	var secs := elapsed_seconds()
	_clock.text = UI.fmt_clock(secs)
	var xp_now := int(floor(secs / 60.0 * state.XP_PER_MINUTE))
	_xp_lbl.text = "+%d XP so far" % xp_now if secs >= 60 else "Settling in..."
	if target_min > 0:
		var frac := clampf(float(secs) / float(target_min * 60), 0.0, 1.0)
		UI.set_bar(_goal_bar, frac)
		_goal_lbl.text = "Goal: %d min" % target_min if frac < 1.0 else "Goal reached. Finish whenever you like."
		if frac >= 1.0 and not _goal_shown:
			_goal_shown = true
			_toast_msg("Goal reached. Finish when you are ready, or keep going.")
	else:
		_goal_lbl.text = "Free session"
	_quote_t += delta
	if _quote_t > 45.0:
		_quote_t = 0.0
		_quote_i = (_quote_i + 1) % QUOTES.size()
		_quote_lbl.text = QUOTES[_quote_i]


func _unhandled_input(event: InputEvent) -> void:
	if not running or _confirm.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _set_angle("side")
			KEY_2: _set_angle("top")
			KEY_3: _set_angle("pov")
			KEY_C:
				var order := ["side", "top", "pov"]
				_set_angle(order[(order.find(scene.angle) + 1) % 3])
			KEY_P, KEY_SPACE: _toggle_pause()
			_: return
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_leave_pressed()
		get_viewport().set_input_as_handled()
