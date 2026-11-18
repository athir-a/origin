extends Node
## Origin: game flow controller. Title -> intro -> village <-> study sessions -> story events -> finale -> mentoring.

const UI = preload("res://scripts/origin/ui_kit.gd")
const Content = preload("res://scripts/origin/content.gd")
const WorldScript = preload("res://scripts/origin/world.gd")
const WeatherScript = preload("res://scripts/origin/weather_overlay.gd")
const DialogueScript = preload("res://scripts/origin/dialogue_box.gd")
const StudyUIScript = preload("res://scripts/origin/study_ui.gd")
const SummaryScript = preload("res://scripts/origin/summary_card.gd")
const JournalScript = preload("res://scripts/origin/journal.gd")
const StoryScript = preload("res://scripts/origin/story_card.gd")
const TitleScript = preload("res://scripts/origin/title_screen.gd")
const PauseScript = preload("res://scripts/origin/pause_menu.gd")

const FLAVOR := {
	"home": ["Home. The roof has been patched more times than anyone remembers, mostly by Nani's stubborn hands.", "A bowl of warm dal is always kept aside here for a student who studies too late."],
	"cottage": ["Tiya's family cottage. A little wooden horse sits on the windowsill, and a small face is usually pressed to the glass.", "The chimney smoke always smells like roasted corn."],
	"well": ["The village well. Half the village's news travels up and down on this bucket rope.", "The water is cold and sweet, even in the hottest months."],
}
const ARRIVALS := {
	"farm:1": "Old Hari tends the first rows.",
	"library:1": "Villagers peek in to see what the shelves hold.",
	"school:1": "Ms. Anika arrives to teach the village's first class.",
	"clinic:1": "Dr. Farah opens the clinic doors.",
	"computer:1": "Rohan sets up the first computers.",
	"internet:1": "The village is online. Anyone can learn anything now.",
	"electricity:1": "As dusk falls, the first bulbs flicker on.",
}

var state: Node
var world: Node2D
var weather_overlay: Control
var hud: Control
var dialogue: Control
var study_ui: Control
var summary: Control
var journal: Control
var story: Control
var title_screen: Control
var pause_menu: Control
var fade_rect: ColorRect
var banner: Control
var toasts: VBoxContainer
var busy := true
var mode := "title"
var _hud_name: Label
var _hud_level: Label
var _hud_bar: Control
var _hud_xp: Label
var _hud_village: Label
var _hud_sky: Label
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _help_panel: Control
var _banner_title: Label
var _banner_sub: Label
var _banner_pillar: Label
var _banner_text: Label
var _banner_open := false
var _banner_done := false
var _env_timer: Timer
var _clock_timer: Timer
var _help_shown_ms := 0


func _ready() -> void:
	_setup_inputs()
	state = get_node("/root/OriginState")
	state.load_slot("main")
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

	world = WorldScript.new()
	add_child(world)
	world.visible = false
	world.input_enabled = false

	var wl := CanvasLayer.new()
	wl.layer = 2
	add_child(wl)
	weather_overlay = WeatherScript.new()
	weather_overlay.world = world
	weather_overlay.visible = false
	wl.add_child(weather_overlay)

	var study_layer := CanvasLayer.new()
	study_layer.layer = 5
	add_child(study_layer)
	study_ui = StudyUIScript.new()
	study_layer.add_child(study_ui)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	hud_layer.add_child(hud)
	_build_hud()

	var modal_layer := CanvasLayer.new()
	modal_layer.layer = 20
	add_child(modal_layer)
	dialogue = DialogueScript.new()
	modal_layer.add_child(dialogue)
	banner = _build_banner()
	modal_layer.add_child(banner)
	summary = SummaryScript.new()
	modal_layer.add_child(summary)
	journal = JournalScript.new()
	modal_layer.add_child(journal)
	pause_menu = PauseScript.new()
	pause_menu.world = world
	modal_layer.add_child(pause_menu)
	story = StoryScript.new()
	modal_layer.add_child(story)
	title_screen = TitleScript.new()
	modal_layer.add_child(title_screen)

	var top_layer := CanvasLayer.new()
	top_layer.layer = 30
	add_child(top_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	top_layer.add_child(fade_rect)
	toasts = UI.vbox(6)
	toasts.anchor_left = 0.5
	toasts.anchor_right = 0.5
	toasts.offset_left = -300
	toasts.offset_right = 300
	toasts.offset_top = 84
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_layer.add_child(toasts)

	world.prompt_changed.connect(_on_prompt)
	world.interact_requested.connect(_on_interact)
	state.changed.connect(_update_hud)
	study_ui.session_started.connect(_on_session_started)
	study_ui.session_finished.connect(_on_session_finished)
	study_ui.session_abandoned.connect(_on_session_abandoned)
	study_ui.setup_cancelled.connect(_on_setup_cancelled)
	journal.closed.connect(_on_journal_closed)
	pause_menu.resume_requested.connect(_close_pause)
	pause_menu.journal_requested.connect(func() -> void:
		pause_menu.visible = false
		journal.open_journal(0))
	pause_menu.title_requested.connect(_to_title)
	pause_menu.reduced_motion_changed.connect(func(on: bool) -> void: weather_overlay.reduced_motion = on)
	title_screen.start_new.connect(_on_new_game)
	title_screen.continue_pressed.connect(_on_continue)
	title_screen.preview_chapter.connect(_on_preview)
	title_screen.erase_confirmed.connect(func() -> void:
		state.wipe("main")
		state.load_slot("main"))

	_env_timer = Timer.new()
	_env_timer.wait_time = 4.0
	_env_timer.timeout.connect(_push_env)
	add_child(_env_timer)
	_env_timer.start()
	_clock_timer = Timer.new()
	_clock_timer.wait_time = 1.0
	_clock_timer.timeout.connect(_update_sky_chip)
	add_child(_clock_timer)
	_clock_timer.start()

	if not _debug_start():
		_show_title()


func _setup_inputs() -> void:
	var defs := {"o_interact": [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], "o_journal": [KEY_J, KEY_TAB]}
	for a: String in defs:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k: int in defs[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k as Key
			InputMap.action_add_event(a, ev)


# ---------------------------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------------------------
func _build_hud() -> void:
	var left := UI.panel(Color(0.96, 0.9, 0.74, 0.94), UI.INK, 10)
	left.position = Vector2(14, 12)
	left.custom_minimum_size = Vector2(300, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(left)
	var lv := UI.vbox(3)
	left.add_child(lv)
	_hud_name = UI.label("", 20, UI.INK, true)
	lv.add_child(_hud_name)
	_hud_level = UI.label("", 16, Color("7a5a1a"), true)
	lv.add_child(_hud_level)
	_hud_bar = UI.bar(0.0, 12, UI.GOLD)
	lv.add_child(_hud_bar)
	_hud_xp = UI.label("", 13, UI.INK_L)
	lv.add_child(_hud_xp)
	_hud_village = UI.label("", 14, Color("2f6a3a"), true)
	lv.add_child(_hud_village)

	var right := UI.hbox(8)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -430
	right.offset_right = -14
	right.offset_top = 12
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(right)
	var chip := UI.panel(Color(0.96, 0.9, 0.74, 0.94), UI.INK, 8)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_sky = UI.label("", 15, UI.INK, true)
	chip.add_child(_hud_sky)
	right.add_child(chip)
	var jb := UI.button("Journal  J", "wood", 16, Vector2(0, 44))
	jb.focus_mode = Control.FOCUS_NONE
	jb.pressed.connect(_open_journal)
	right.add_child(jb)
	var mb := UI.button("Menu  Esc", "wood", 16, Vector2(0, 44))
	mb.focus_mode = Control.FOCUS_NONE
	mb.pressed.connect(_open_pause)
	right.add_child(mb)

	_prompt_panel = UI.panel(Color(0.1, 0.09, 0.16, 0.88), Color("0c0a12"), 8)
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_top = -78
	_prompt_panel.offset_bottom = -26
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.visible = false
	hud.add_child(_prompt_panel)
	var pr := UI.hbox(10)
	_prompt_panel.add_child(pr)
	var key := PanelContainer.new()
	key.add_theme_stylebox_override("panel", UI.box(UI.GOLD, UI.INK, 2, 4, false))
	key.add_child(UI.label(" E ", 20, UI.INK, true))
	pr.add_child(key)
	_prompt_label = UI.label("", 22, UI.CREAM, true)
	pr.add_child(_prompt_label)

	_help_panel = UI.panel(Color(0.1, 0.09, 0.16, 0.8), Color("0c0a12"), 10)
	_help_panel.anchor_top = 1.0
	_help_panel.anchor_bottom = 1.0
	_help_panel.offset_left = 14
	_help_panel.offset_top = -108
	_help_panel.offset_bottom = -14
	_help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_help_panel)
	var hv := UI.vbox(2)
	_help_panel.add_child(hv)
	hv.add_child(UI.label("Move   W A S D  /  arrows", 14, UI.CREAM))
	hv.add_child(UI.label("Interact   E  /  Space", 14, UI.CREAM))
	hv.add_child(UI.label("Journal   J        Menu   Esc", 14, UI.CREAM))


func _build_banner() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	var p := UI.panel(Color(0.96, 0.9, 0.74, 0.97), UI.INK, 16)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = -400
	p.offset_right = 400
	p.offset_top = -232
	p.offset_bottom = -26
	root.add_child(p)
	var v := UI.vbox(4)
	p.add_child(v)
	var top := UI.hbox(10)
	v.add_child(top)
	_banner_pillar = UI.label("", 14, UI.CREAM, true)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UI.box(UI.MOSS, UI.INK, 2, 4, false))
	chip.add_child(_banner_pillar)
	top.add_child(chip)
	_banner_title = UI.heading("", 28)
	top.add_child(_banner_title)
	_banner_sub = UI.label("", 18, Color("7a5a1a"), true)
	v.add_child(_banner_sub)
	_banner_text = UI.wrap_label("", 18, UI.INK_L)
	v.add_child(_banner_text)
	var row := UI.hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var ok := UI.button("Continue  (E)", "moss", 18, Vector2(190, 42))
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(func() -> void: _banner_done = true)
	row.add_child(ok)
	return root


func _show_banner(pillar: String, title: String, sub: String, text: String, auto_s: float = 14.0) -> void:
	_banner_pillar.text = " " + pillar.to_upper() + " "
	_banner_title.text = title
	_banner_sub.text = sub
	_banner_text.text = text
	banner.visible = true
	banner.modulate.a = 0.0
	create_tween().tween_property(banner, "modulate:a", 1.0, 0.3)
	_banner_open = true
	_banner_done = false
	var t := 0.0
	while not _banner_done and t < auto_s:
		await get_tree().process_frame
		t += get_process_delta_time()
	_banner_open = false
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 0.0, 0.25)
	await tw.finished
	banner.visible = false


func toast(text: String, seconds: float = 4.0) -> void:
	var l := UI.label(text, 19, UI.CREAM, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color("120e18"))
	l.add_theme_constant_override("outline_size", 8)
	l.modulate.a = 0.0
	toasts.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.3)
	tw.tween_interval(seconds)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _update_hud() -> void:
	if state == null or state.d.is_empty():
		return
	var lp: Dictionary = state.level_progress()
	_hud_name.text = str(state.d.name)
	_hud_level.text = "Level %d  -  %s" % [lp.level, lp.title]
	UI.set_bar(_hud_bar, lp.frac)
	_hud_xp.text = "%d / %d XP" % [lp.into, lp.need]
	var vl: int = state.village_level()
	_hud_village.text = "%s  (village level %d)" % [Content.village_title(vl), vl]


func _update_sky_chip() -> void:
	if world == null:
		return
	var seas: String = str(world.season).capitalize()
	_hud_sky.text = "%s   %s   %s" % [world.time_text(), world.weather_text(), seas]


func _on_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_panel.visible = text != "" and mode == "world" and not busy


func _process(_d: float) -> void:
	if mode == "world":
		var want: bool = str(world.current_target.get("label", "")) != "" and not busy
		_prompt_panel.visible = want
		if want:
			_prompt_label.text = world.current_target.label
		if _help_panel.visible and Time.get_ticks_msec() - _help_shown_ms > 30000 and state.flag("tutorial_done", false):
			_help_panel.visible = false


# ---------------------------------------------------------------------------------------------
# Screen flow
# ---------------------------------------------------------------------------------------------
func _fade(to_alpha: float, dur: float = 0.4) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", to_alpha, dur)
	await tw.finished


func _show_title() -> void:
	mode = "title"
	busy = true
	if state.slot != "main":
		state.load_slot("main")
	world.visible = false
	world.input_enabled = false
	weather_overlay.visible = false
	hud.visible = false
	study_ui.visible = false
	title_screen.open_menu()
	fade_rect.modulate.a = 0.0


func _to_title() -> void:
	pause_menu.visible = false
	state.save()
	world.process_mode = Node.PROCESS_MODE_INHERIT
	await _fade(1.0, 0.3)
	_show_title()
	await _fade(0.0, 0.4)


func _on_continue() -> void:
	state.load_slot("main")
	_enter_game(false)


func _on_new_game(player_name: String) -> void:
	state.load_slot("main")
	state.new_game(player_name)
	await _fade(1.0, 0.3)
	title_screen.visible = false
	await _fade(0.0, 0.3)
	var pages: Array = Content.INTRO_PAGES.duplicate()
	pages.append("Your name is %s. The lamp is lit.\n\nWalk to it, sit down, and begin." % state.d.name)
	story.play(load("res://assets/origin/scenes/keyart.png"), pages)
	await story.finished
	state.set_flag("intro_done", true)
	_enter_game(true)


func _on_preview(chapter: int) -> void:
	var nm := "Traveler"
	if state.slot == "main" and state.has_save():
		nm = str(state.d.name)
	state.load_slot("preview")
	state.synthesize(chapter, nm)
	_enter_game(false)


func _enter_game(fresh: bool) -> void:
	await _fade(1.0, 0.3)
	title_screen.visible = false
	mode = "world"
	busy = true
	world.visible = true
	world.process_mode = Node.PROCESS_MODE_INHERIT
	weather_overlay.visible = true
	weather_overlay.reduced_motion = bool(state.d.settings.get("reduced_motion", false))
	hud.visible = true
	_help_panel.visible = true
	_help_shown_ms = Time.get_ticks_msec()
	world.refresh()
	world.snap_player(world.SPAWN)
	_update_hud()
	_update_sky_chip()
	world.input_enabled = false
	await _fade(0.0, 0.5)
	if state.slot == "preview":
		toast("Story preview: a separate save. Your real progress is untouched.", 5.0)
	elif not fresh:
		var gap: int = state.days_since_last_study()
		if state.session_count() > 0 and gap >= 2:
			toast("Welcome back, %s. The lamp kept your place." % state.d.name, 5.0)
		elif state.session_count() > 0:
			toast("Good to see you again, %s." % state.d.name, 4.0)
	if fresh:
		toast("Walk to the street lamp and press E to start your first session.", 8.0)
	await _run_events()
	busy = false
	world.input_enabled = true


# ---------------------------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if _banner_open and (event.is_action_pressed("o_interact") or event.is_action_pressed("ui_accept")):
		_banner_done = true
		get_viewport().set_input_as_handled()
		return
	if mode != "world" or busy or dialogue.is_active():
		return
	if event.is_action_pressed("o_interact"):
		world.activate()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("o_journal"):
		_open_journal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_open_pause()
		get_viewport().set_input_as_handled()


func _open_journal() -> void:
	if mode != "world" or busy:
		return
	busy = true
	world.input_enabled = false
	journal.open_journal(0)


func _on_journal_closed() -> void:
	if pause_menu.visible:
		return
	busy = false
	world.input_enabled = true


func _open_pause() -> void:
	if mode != "world" or busy:
		return
	busy = true
	world.input_enabled = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	pause_menu.open_menu()


func _close_pause() -> void:
	pause_menu.visible = false
	world.process_mode = Node.PROCESS_MODE_INHERIT
	busy = false
	world.input_enabled = true


# ---------------------------------------------------------------------------------------------
# Interactions
# ---------------------------------------------------------------------------------------------
func _on_interact(kind: String, id: String) -> void:
	if busy:
		return
	match kind:
		"talk": await _talk(id)
		"study": _open_study()
		"building": await _inspect_building(id)
		"barrier": await _barrier(id)
		"flavor": await _flavor(id)


func _say(speaker: String, role: String, portrait: Texture2D, pages: Array, color: Color = UI.GOLD) -> void:
	busy = true
	world.input_enabled = false
	dialogue.play(speaker, role, portrait, pages, color)
	await dialogue.finished
	busy = false
	world.input_enabled = true


func _talk(id: String) -> void:
	var info: Dictionary = Content.VILLAGERS[id]
	var pages: Array = state.dialogue_pages(id)
	var tex: Texture2D = load("res://assets/origin/chars/%s_front.png" % id)
	await _say(info.name, info.role, tex, pages, info.color)
	world.refresh_news()
	if id == "child" and state.talk_count("child") == 3 and not state.ended():
		toast("Tiya is always watching from the fence. She is learning from you.", 4.0)


func _flavor(id: String) -> void:
	await _say("", "", null, FLAVOR[id])


func _inspect_building(id: String) -> void:
	var key := id
	var b: Dictionary = Content.BUILDINGS[key]
	var lvl: int = state.shown_levels()[key]
	var lines: Array = []
	if lvl == 0 and key in ["school", "clinic", "computer"]:
		lines.append("An empty plot. %s" % _plot_story(key))
	else:
		lines.append("%s  -  %s.\n%s" % [b.name, b.levels[lvl], b.meaning])
	var goal: Dictionary = Content.next_goal(key, state.metrics(), state.levels())
	if goal.done:
		lines.append("This has grown as far as it can for now. It stands for %s, and all of it began with showing up." % b.pillar.to_lower())
	else:
		lines.append("This stands for %s. Next step: %s" % [b.pillar.to_lower(), goal.text])
	await _say("", "", null, lines)


func _plot_story(key: String) -> String:
	match key:
		"school": return "Someone has pegged out a string line. One day children will learn here."
		"clinic": return "A few stones mark where the clinic will stand. The village needs it."
		"computer": return "Cables are coiled in a crate. A computer center is waiting for the village to be ready."
	return ""


func _barrier(id: String) -> void:
	var z: Dictionary = Content.ZONES[id]
	var progress := ""
	if id == "north":
		progress = "You are Learner Level %d." % state.level()
	else:
		progress = "You have completed %d session%s." % [state.session_count(), "" if state.session_count() == 1 else "s"]
	var text := "The way is overgrown with weeds and thorny bushes. %s\n%s" % [z.hint, progress]
	await _say("", "", null, [text])


# ---------------------------------------------------------------------------------------------
# Study flow
# ---------------------------------------------------------------------------------------------
func _env_opts() -> Dictionary:
	return {"tier": state.study_tier(), "dark": world.darkness, "weather": world.weather, "season": world.season, "mentor": state.ended()}


func _push_env() -> void:
	if study_ui.running or study_ui.visible:
		var o := _env_opts()
		o.erase("tier")
		study_ui.refresh_env(o)


func _open_study() -> void:
	busy = true
	world.input_enabled = false
	study_ui.open_setup(state.ended(), _env_opts())


func _on_setup_cancelled() -> void:
	busy = false
	world.input_enabled = true


func _on_session_started() -> void:
	mode = "study"
	await _fade(1.0, 0.0)
	world.visible = false
	weather_overlay.visible = false
	hud.visible = false
	await _fade(0.0, 0.5)


func _return_to_world() -> void:
	await _fade(1.0, 0.3)
	mode = "world"
	world.visible = true
	weather_overlay.visible = true
	hud.visible = true
	await _fade(0.0, 0.4)


func _on_session_abandoned() -> void:
	await _return_to_world()
	busy = false
	world.input_enabled = true
	toast("The lamp will be here when you are ready.", 3.5)


func _on_session_finished(subject: String, seconds: int, target_min: int) -> void:
	var mentor: bool = state.ended()
	var res: Dictionary = state.record_session(subject, seconds, target_min, mentor)
	state.set_flag("tutorial_done", true)
	await _return_to_world()
	if not res.ok:
		busy = false
		world.input_enabled = true
		return
	_update_hud()
	world.spawn_sparkles(world.player.position, 10)
	summary.show_result(res, subject, mentor, str(state.d.name))
	await summary.closed
	await _run_events()
	busy = false
	world.input_enabled = true


# ---------------------------------------------------------------------------------------------
# Story events: the village changing in response to growth
# ---------------------------------------------------------------------------------------------
func _site_pos(id: String, lvl: int) -> Vector2:
	match id:
		"farm": return world.SITES.farm
		"library": return world.SITES.library
		"electricity": return Vector2(560, 470)
		"roads": return Vector2(600, 505)
		"school": return world.SITES.school
		"clinic": return world.SITES.clinic
		"computer": return world.SITES.computer
		"internet": return world.SITES.tower + Vector2(0, -60)
		"shop": return world.SITES.market if lvl >= 2 else world.SITES.shop
	return world.LAMP_POS


func _run_events() -> void:
	busy = true
	world.input_enabled = false
	var guard := 0
	while guard < 40:
		guard += 1
		var ev: Dictionary = state.next_event()
		if ev.is_empty():
			break
		match ev.type:
			"zone": await _event_zone(ev)
			"building": await _event_building(ev)
			"milestone": await _event_milestone(ev)
			"finale": await _run_finale()
		state.pop_event()
	world.release_focus()
	world.refresh_news()
	world.input_enabled = true


func _event_zone(ev: Dictionary) -> void:
	var z: String = ev.id
	if state.zone_shown(z):
		return
	var info: Dictionary = Content.ZONES[z]
	var pos: Vector2 = Vector2(680, 330) if z == "north" else Vector2(860, 512)
	world.focus_on(pos, 2.4)
	await get_tree().create_timer(1.1).timeout
	state.mark_shown_zone(z)
	world.refresh()
	world.spawn_dust(pos, 22)
	await get_tree().create_timer(0.8).timeout
	var line := "The overgrown path is cleared, and the way north opens to the hill." if z == "north" else "A proper road is laid east, past the old fence."
	await _show_banner("New area", info.name, "A new part of the village opens up", line)
	world.release_focus()
	await get_tree().create_timer(0.4).timeout


func _event_building(ev: Dictionary) -> void:
	var id: String = ev.id
	var lvl: int = ev.level
	if state.shown_levels()[id] >= lvl:
		return
	var b: Dictionary = Content.BUILDINGS[id]
	# a building may sit in an area that is not yet shown; reveal the zone first
	if id in ["school", "clinic"] and not state.zone_shown("north") and state.zone_open("north"):
		await _event_zone({"id": "north"})
	if id in ["computer", "internet"] and not state.zone_shown("east") and state.zone_open("east"):
		await _event_zone({"id": "east"})
	var pos := _site_pos(id, lvl)
	world.focus_on(pos, 2.3)
	var prev_hour: float = world.hour
	var dusk := id == "electricity" and lvl == 1
	if dusk:
		world.time_frozen = true
		world.set_sky(20.2, "", "")
	await get_tree().create_timer(1.1).timeout
	state.mark_shown_building(id, lvl)
	world.refresh(id)
	world.spawn_dust(pos + Vector2(0, -6), 26)
	await get_tree().create_timer(0.7).timeout
	world.spawn_sparkles(pos + Vector2(0, -20), 18)
	await get_tree().create_timer(0.9 if not dusk else 2.2).timeout
	var arrival: String = ARRIVALS.get("%s:%d" % [id, lvl], "")
	var sub := "%s  -  Level %d" % [b.levels[lvl], lvl]
	var text: String = b.meaning if arrival == "" else "%s\n%s" % [b.meaning, arrival]
	await _show_banner(b.pillar, b.name, sub, text)
	if dusk:
		world.set_sky(prev_hour, "", "")
		world.time_frozen = false
	world.release_focus()
	await get_tree().create_timer(0.5).timeout


func _event_milestone(ev: Dictionary) -> void:
	var ms: Dictionary = Content.ASHA_MILESTONES[int(ev.index)]
	world.focus_on(world.LAMP_POS + Vector2(10, -20), 2.6)
	await get_tree().create_timer(0.8).timeout
	world.spawn_sparkles(world.LAMP_POS + Vector2(24, -10), 20)
	await _show_banner("Asha's journey", ms.title, "Because you were there", ms.text, 18.0)
	world.release_focus()


# ---------------------------------------------------------------------------------------------
# The finale
# ---------------------------------------------------------------------------------------------
func _run_finale() -> void:
	var nm: String = str(state.d.name)
	var lamp_tex: Texture2D = load("res://assets/origin/scenes/finale.png")
	await _fade(1.0, 0.8)
	var pages: Array = [
		{"text": "The seasons turn.\n\nYour books became shelves. The shelves became a library, and the library became a school.\nThe roads reached the hills, and light reached every window."},
		{"text": "One evening, you walk back to where it all began.\nThe street lamp is still there, a little older, a little brighter."},
		{"text": "Someone is sitting beneath it, a worn book in her lap.\nThere is something in her face you remember: part hope, part fear."},
		{"who": "Asha", "text": "Is... is it okay if I sit here? Everyone says this is where it starts."},
		{"who": nm, "text": "Of course. It is the best seat in the whole village."},
		{"text": "You made it.\nNow it's your turn.", "big": true},
		{"text": "Where you begin does not decide where you end.\nAnd how far you go can change how far someone else gets to go."},
	]
	await _fade(0.0, 0.01)
	story.play(lamp_tex, pages)
	await story.finished
	await _fade(1.0, 0.3)
	state.d.flags.ending_seen = true
	var first: bool = state.grant_achievement("you_made_it")
	if first:
		state.d.xp = int(state.d.xp) + Content.ACHIEVEMENT_XP
	state.save()
	world.refresh()
	world.snap_player(world.LAMP_POS + Vector2(-34, 26))
	_update_hud()
	await _fade(0.0, 0.7)
	world.focus_on(world.LAMP_POS + Vector2(0, -10), 2.6)
	world.spawn_sparkles(world.LAMP_POS + Vector2(18, 0), 30)
	await get_tree().create_timer(1.2).timeout
	await _show_banner("The cycle continues", "You Made It", "Achievement unlocked", "You returned to the lamp as someone who can help a new student begin. Sit beside Asha and study together, and watch her grow.", 20.0)
	world.release_focus()
	toast("Talk to Asha, or study beside her to guide her journey.", 6.0)


# ---------------------------------------------------------------------------------------------
# Debug capture hooks (used only with explicit command-line arguments, never in the browser build)
# ---------------------------------------------------------------------------------------------
func _debug_start() -> bool:
	var args := OS.get_cmdline_user_args()
	var opts := {}
	for a in args:
		var s := String(a).trim_prefix("--")
		var kv := s.split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if not opts.has("shot"):
		return false
	_run_shot(opts)
	return true


func _run_shot(o: Dictionary) -> void:
	var ch := int(o.get("chapter", "3"))
	state.load_slot("preview")
	state.synthesize(ch, "Traveler")
	if o.has("noevents"):
		state.d.events = []
	mode = "world"
	title_screen.visible = false
	world.visible = true
	weather_overlay.visible = true
	hud.visible = true
	_help_panel.visible = false
	world.refresh()
	world.snap_player(world.SPAWN)
	if o.has("px"):
		world.snap_player(Vector2(float(o.px), float(o.py)))
	world.input_enabled = false
	_update_hud()
	world.set_sky(float(o.get("hour", "12")), String(o.get("weather", "sunny")), String(o.get("season", "autumn")))
	world.time_frozen = true
	world.weather_locked = true
	if o.has("focus"):
		var p := String(o.focus).split(",")
		world.focus_on(Vector2(float(p[0]), float(p[1])), float(o.get("zoom", "2.0")))
	await get_tree().create_timer(0.6).timeout
	if o.has("study"):
		var sp := String(o.study).split(":")
		hud.visible = false
		weather_overlay.visible = false
		world.visible = false
		var opts := _env_opts()
		opts["tier"] = int(sp[1])
		study_ui.visible = true
		study_ui.scene.configure(opts)
		study_ui.subject = "Science"
		study_ui.target_min = 25
		study_ui._begin()
		study_ui.scene.set_angle(sp[0])
		study_ui.scene.t = float(o.get("t", "4"))
		study_ui.scene.paused = true
	if o.has("dialogue"):
		_say(Content.VILLAGERS[o.dialogue].name, Content.VILLAGERS[o.dialogue].role, load("res://assets/origin/chars/%s_front.png" % o.dialogue), state.dialogue_pages(o.dialogue), Content.VILLAGERS[o.dialogue].color)
	if o.has("journal"):
		journal.open_journal(int(o.journal))
	if o.has("title"):
		world.visible = false
		hud.visible = false
		title_screen.open_menu()
	await get_tree().create_timer(float(o.get("wait", "1.0"))).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(String(o.get("out", "/tmp/shot.png")))
	get_tree().quit()
