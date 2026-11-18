extends Control
## Title screen: key art, menu, name entry, story preview.

signal start_new(player_name: String)
signal continue_pressed
signal preview_chapter(chapter: int)
signal erase_confirmed

const UI = preload("res://scripts/origin/ui_kit.gd")
const Content = preload("res://scripts/origin/content.gd")

var state: Node
var _bg: TextureRect
var _menu: VBoxContainer
var _name_box: Control
var _name_edit: LineEdit
var _preview_box: Control
var _confirm_box: Control
var _about_box: Control
var _t := 0.0
var _stars: Control
var _continue_btn: Button
var _tw: Tween


func _ready() -> void:
	state = get_node("/root/OriginState")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color("0b0d1a")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_bg = TextureRect.new()
	_bg.texture = load("res://assets/origin/scenes/keyart.png")
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_bg)
	var grad := ColorRect.new()
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.color = Color(0.02, 0.03, 0.08, 0.28)
	add_child(grad)
	var bottom := ColorRect.new()
	bottom.anchor_top = 0.5
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.color = Color(0.02, 0.03, 0.08, 0.35)
	add_child(bottom)

	var title := UI.title("ORIGIN", 128, Color("fbe9b8"))
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_outline_color", Color("2a1b14"))
	title.anchor_right = 1.0
	title.offset_top = 36
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var tag := UI.label("Where your growth becomes someone else's beginning.", 24, Color("f4e6c0"), true)
	tag.anchor_right = 1.0
	tag.offset_top = 188
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_outline_color", Color("150f1c"))
	tag.add_theme_constant_override("outline_size", 8)
	add_child(tag)

	_menu = UI.vbox(10)
	_menu.anchor_left = 0.5
	_menu.anchor_right = 0.5
	_menu.anchor_top = 1.0
	_menu.anchor_bottom = 1.0
	_menu.offset_left = -170
	_menu.offset_right = 170
	_menu.offset_top = -292
	_menu.offset_bottom = -34
	add_child(_menu)
	_continue_btn = UI.button("Continue your journey", "gold", 22, Vector2(0, 52))
	_continue_btn.pressed.connect(func() -> void: continue_pressed.emit())
	_menu.add_child(_continue_btn)
	var nb := UI.button("Begin a new journey", "moss", 22, Vector2(0, 52))
	nb.pressed.connect(_open_name)
	_menu.add_child(nb)
	var pv := UI.button("Story preview", "wood", 20, Vector2(0, 46))
	pv.pressed.connect(func() -> void: _show_box(_preview_box))
	_menu.add_child(pv)
	var ab := UI.button("About Origin", "wood", 20, Vector2(0, 46))
	ab.pressed.connect(func() -> void: _show_box(_about_box))
	_menu.add_child(ab)
	var er := UI.button("Erase saved progress", "ghost", 16, Vector2(0, 34))
	er.pressed.connect(func() -> void: _show_box(_confirm_box))
	_menu.add_child(er)

	_build_name()
	_build_preview()
	_build_confirm()
	_build_about()
	var ver := UI.label("A calm little game about learning and community", 14, Color("b8b0c8"))
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 16
	ver.offset_top = -28
	add_child(ver)


func open_menu() -> void:
	_menu.visible = true
	for b in [_name_box, _preview_box, _confirm_box, _about_box]:
		b.visible = false
	_continue_btn.visible = state.has_save()
	visible = true
	_bg.pivot_offset = size / 2.0
	_bg.scale = Vector2.ONE
	if _tw:
		_tw.kill()
	_tw = create_tween().set_loops()
	_tw.tween_property(_bg, "scale", Vector2(1.06, 1.06), 18.0).set_trans(Tween.TRANS_SINE)
	_tw.tween_property(_bg, "scale", Vector2(1.0, 1.0), 18.0).set_trans(Tween.TRANS_SINE)


func _show_box(box: Control) -> void:
	_menu.visible = false
	box.visible = true


func _hide_boxes() -> void:
	open_menu()


func _modal(w: int) -> PanelContainer:
	var p := UI.panel(UI.PARCH, UI.INK, 20)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(w, 0)
	p.offset_top = 80
	return p


func _build_name() -> void:
	_name_box = Control.new()
	_name_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_box)
	var p := _modal(520)
	_name_box.add_child(p)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.heading("Who are you?", 32))
	v.add_child(UI.wrap_label("A student in a small village, with a lamp, a book and people who believe in you. What should they call you?", 18, UI.INK_L))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name"
	_name_edit.max_length = 14
	_name_edit.custom_minimum_size = Vector2(0, 46)
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.add_theme_color_override("font_color", UI.INK)
	_name_edit.add_theme_color_override("font_placeholder_color", UI.INK_L)
	_name_edit.add_theme_stylebox_override("normal", UI.box(Color("fff6dc"), UI.INK, 2, 10, false))
	_name_edit.add_theme_stylebox_override("focus", UI.box(Color("fff6dc"), Color("c78a1e"), 3, 10, false))
	_name_edit.text_submitted.connect(func(_t: String) -> void: _submit_name())
	v.add_child(_name_edit)
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var back := UI.button("Back", "parch", 18, Vector2(120, 44))
	back.pressed.connect(_hide_boxes)
	row.add_child(back)
	var go := UI.button("Begin", "moss", 20, Vector2(160, 44))
	go.pressed.connect(_submit_name)
	row.add_child(go)
	_name_box.visible = false


func _open_name() -> void:
	if state.has_save():
		_show_box(_confirm_box)
		_confirm_box.set_meta("then_new", true)
		return
	_show_box(_name_box)
	_name_edit.grab_focus()


func _submit_name() -> void:
	var n := _name_edit.text.strip_edges()
	start_new.emit(n if n != "" else "Traveler")


func _build_preview() -> void:
	_preview_box = Control.new()
	_preview_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview_box)
	var p := _modal(700)
	_preview_box.add_child(p)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.heading("Story preview", 32))
	v.add_child(UI.wrap_label("Jump to a moment in the journey to see how the village grows. This uses a separate preview save, so your real progress is never touched.", 17, UI.INK_L))
	for ch: Dictionary in state.CHAPTERS:
		var b := UI.button("%d.  %s" % [ch.id, ch.title], "wood", 20, Vector2(0, 48))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = ch.blurb
		b.pressed.connect(func() -> void: preview_chapter.emit(ch.id))
		var row := UI.hbox(10)
		v.add_child(row)
		b.custom_minimum_size = Vector2(240, 48)
		row.add_child(b)
		var bl := UI.wrap_label(ch.blurb, 16, UI.INK_L)
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(bl)
	var back := UI.button("Back", "parch", 18, Vector2(120, 44))
	back.pressed.connect(_hide_boxes)
	var row2 := UI.hbox(0)
	row2.alignment = BoxContainer.ALIGNMENT_END
	row2.add_child(back)
	v.add_child(row2)
	_preview_box.visible = false


func _build_confirm() -> void:
	_confirm_box = Control.new()
	_confirm_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_confirm_box)
	var p := _modal(520)
	_confirm_box.add_child(p)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.heading("Erase your journey?", 30))
	v.add_child(UI.wrap_label("This removes your saved village, sessions and achievements from this browser. It cannot be undone.", 18, UI.INK_L))
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var back := UI.button("Keep it", "moss", 18, Vector2(140, 44))
	back.pressed.connect(_hide_boxes)
	row.add_child(back)
	var yes := UI.button("Erase", "parch", 18, Vector2(140, 44))
	yes.pressed.connect(func() -> void:
		var then_new: bool = _confirm_box.get_meta("then_new", false)
		_confirm_box.set_meta("then_new", false)
		erase_confirmed.emit()
		if then_new:
			_show_box(_name_box)
			_name_edit.grab_focus()
		else:
			open_menu())
	row.add_child(yes)
	_confirm_box.visible = false


func _build_about() -> void:
	_about_box = Control.new()
	_about_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_about_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_about_box)
	var p := _modal(700)
	_about_box.add_child(p)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.heading("About Origin", 32))
	v.add_child(UI.wrap_label("Study beneath the old street lamp. Every focused session earns experience, and the village grows with you: farms, a library, a school, light in every window, roads, a clinic, a computer center and a connection to the wider world.", 18, UI.INK))
	v.add_child(UI.wrap_label("There are no punishments here. Missed days never erase anything. Coming back is celebrated.", 18, UI.INK_L))
	v.add_child(UI.wrap_label("Where you begin does not have to decide where you end. And how far you go can change how far someone else gets to go.", 18, Color("7a5a1a")))
	v.add_child(UI.label("Move: WASD / arrows     Interact: E or Space     Journal: J     Menu: Esc", 15, UI.INK_L))
	var back := UI.button("Back", "parch", 18, Vector2(120, 44))
	back.pressed.connect(_hide_boxes)
	var row := UI.hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(back)
	v.add_child(row)
	_about_box.visible = false
