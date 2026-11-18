extends Control
## Shown after a recorded study session: XP, level progress, gentle encouragement and what is changing.

signal closed

const UI = preload("res://scripts/origin/ui_kit.gd")
const Content = preload("res://scripts/origin/content.gd")

var _panel: PanelContainer
var _body: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.1, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = UI.panel(UI.PARCH, UI.INK, 22)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(660, 0)
	add_child(_panel)
	_body = UI.vbox(10)
	_panel.add_child(_body)


func show_result(res: Dictionary, subject: String, mentor: bool, player_name: String) -> void:
	for c in _body.get_children():
		c.queue_free()
	_body.add_child(UI.heading("Session recorded", 32))
	var greet := _greeting(res, mentor, player_name)
	_body.add_child(UI.wrap_label(greet, 19, UI.INK_L))
	_body.add_child(HSeparator.new())
	var stats := UI.hbox(26)
	_body.add_child(stats)
	stats.add_child(_stat("Time", UI.fmt_duration(int(res.seconds))))
	stats.add_child(_stat("Subject", subject))
	stats.add_child(_stat("XP earned", "+%d" % int(res.xp)))
	if res.bonuses.size() > 0:
		var bl := UI.vbox(2)
		_body.add_child(bl)
		for b: Dictionary in res.bonuses:
			bl.add_child(UI.label("   +%d XP   %s" % [b.xp, b.label], 17, Color("7a5a1a")))
	# level bar
	var lrow := UI.hbox(10)
	_body.add_child(lrow)
	var lvl_lbl := UI.label("Level %d  %s" % [res.level_after, res.level_title], 19, UI.INK, true)
	lrow.add_child(lvl_lbl)
	var bar := UI.bar(0.0, 16, UI.GOLD)
	lrow.add_child(bar)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void: UI.set_bar(bar, res.level_frac))
	if res.level_after > res.level_before:
		var up := UI.label("Level up!  You are now a %s." % res.level_title, 20, Color("2f7a3a"), true)
		_body.add_child(up)
	# what is changing
	var changes: Array = []
	for nl: Dictionary in res.new_levels:
		var b: Dictionary = Content.BUILDINGS[nl.id]
		changes.append("%s: %s" % [b.name, b.levels[nl.level]])
	for z: String in res.new_zones:
		changes.append("A new area opens: %s" % Content.ZONES[z].name)
	if changes.size() > 0:
		_body.add_child(UI.label("The village is changing...", 18, UI.INK, true))
		for ch in changes:
			_body.add_child(UI.label("   " + ch, 17, Color("2f6a3a")))
	if res.achievements.size() > 0:
		_body.add_child(UI.label("Achievements unlocked", 18, UI.INK, true))
		for id: String in res.achievements:
			for a: Dictionary in Content.ACHIEVEMENTS:
				if a.id == id:
					_body.add_child(UI.label("   %s  -  %s" % [a.name, a.desc], 17, Color("8a5a10")))
	var go := UI.button("Return to the village", "moss", 21, Vector2(300, 50))
	go.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	var brow := UI.hbox(0)
	brow.alignment = BoxContainer.ALIGNMENT_END
	brow.add_child(go)
	_body.add_child(brow)
	visible = true
	_panel.scale = Vector2(0.94, 0.94)
	_panel.pivot_offset = _panel.size / 2.0
	create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	go.grab_focus()


func _greeting(res: Dictionary, mentor: bool, player_name: String) -> String:
	if res.returned:
		return "You came back, %s. That matters more than any streak. Welcome back." % player_name
	if mentor:
		return "Another quiet hour beside Asha. Teaching is a way of learning twice."
	var m: float = res.minutes
	if m >= 45.0:
		return "A long, steady session, %s. Take a breath and drink some water." % player_name
	if m >= 20.0:
		return "A solid session. Small, steady work is how villages are built."
	return "Every minute counts, %s. You showed up, and that is the hardest part." % player_name


func _stat(title: String, value: String) -> Control:
	var v := UI.vbox(0)
	v.add_child(UI.label(title, 15, UI.INK_L))
	v.add_child(UI.label(value, 24, UI.INK, true))
	return v
