extends Control
## Bottom-of-screen dialogue with a character portrait and typewriter text.

signal finished
signal advanced

const UI = preload("res://scripts/origin/ui_kit.gd")

var _panel: PanelContainer
var _portrait: TextureRect
var _name_label: Label
var _role_label: Label
var _text: RichTextLabel
var _hint: Label
var _pages: Array = []
var _index := 0
var _chars := 0.0
var _active := false
var _accent := UI.GOLD
var _frame: PanelContainer
var _dots: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_panel = UI.panel(UI.PARCH, UI.INK, 16)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -470
	_panel.offset_right = 470
	_panel.offset_top = -214
	_panel.offset_bottom = -22
	add_child(_panel)
	var row := UI.hbox(16)
	_panel.add_child(row)

	_frame = PanelContainer.new()
	_frame.custom_minimum_size = Vector2(120, 150)
	_frame.add_theme_stylebox_override("panel", UI.box(Color("d9c595"), UI.INK, 3, 4, false))
	row.add_child(_frame)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.add_child(_portrait)

	var col := UI.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var head := UI.hbox(10)
	col.add_child(head)
	_name_label = UI.heading("", 26)
	head.add_child(_name_label)
	_role_label = UI.label("", 16, UI.INK_L)
	_role_label.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_role_label)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.fit_content = false
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_color_override("default_color", UI.INK)
	col.add_child(_text)
	var foot := UI.hbox(8)
	col.add_child(foot)
	_dots = UI.label("", 14, UI.INK_L)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_dots)
	_hint = UI.label("E / Space / Click  to continue", 14, UI.INK_L)
	foot.add_child(_hint)


func is_active() -> bool:
	return _active


func play(speaker: String, role: String, portrait: Texture2D, pages: Array, accent: Color = UI.GOLD) -> void:
	_pages = pages
	_index = 0
	_active = true
	_accent = accent
	_name_label.text = speaker
	_name_label.add_theme_color_override("font_color", accent.darkened(0.35))
	_role_label.text = role
	_portrait.texture = portrait
	_frame.visible = portrait != null
	visible = true
	_show_page()
	_panel.modulate.a = 0.0
	_panel.position.y += 12
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.18)


func _show_page() -> void:
	_text.text = _pages[_index]
	_text.visible_characters = 0
	_chars = 0.0
	_dots.text = ("page %d / %d" % [_index + 1, _pages.size()]) if _pages.size() > 1 else ""
	advanced.emit()


func _process(delta: float) -> void:
	if not _active:
		return
	var total := _text.get_total_character_count()
	if _text.visible_characters < total:
		_chars += delta * 62.0
		_text.visible_characters = int(_chars)


func _advance() -> void:
	var total := _text.get_total_character_count()
	if _text.visible_characters < total:
		_text.visible_characters = total
		_chars = total
		return
	_index += 1
	if _index >= _pages.size():
		_active = false
		visible = false
		finished.emit()
	else:
		_show_page()


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("o_interact") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()
