extends Control
## Full-screen narrative cards over key art (intro, ending, milestones).

signal finished

const UI = preload("res://scripts/origin/ui_kit.gd")

var _bg: TextureRect
var _shade: ColorRect
var _panel: PanelContainer
var _who: Label
var _text: RichTextLabel
var _big: Label
var _hint: Label
var _pages: Array = []
var _i := 0
var _chars := 0.0
var _active := false
var _zoom_t: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var back := ColorRect.new()
	back.color = Color("0b0d1a")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_bg)
	_shade = ColorRect.new()
	_shade.color = Color(0.02, 0.03, 0.08, 0.35)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_big = UI.title("", 54, UI.CREAM)
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_big.offset_left = 120
	_big.offset_right = -120
	_big.visible = false
	add_child(_big)
	_panel = UI.panel(Color(0.06, 0.06, 0.12, 0.84), Color("0a0910"), 20)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -480
	_panel.offset_right = 480
	_panel.offset_top = -226
	_panel.offset_bottom = -28
	add_child(_panel)
	var v := UI.vbox(6)
	_panel.add_child(v)
	_who = UI.label("", 20, Color("f2c960"), true)
	v.add_child(_who)
	_text = RichTextLabel.new()
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 23)
	_text.add_theme_color_override("default_color", Color("f5ead0"))
	v.add_child(_text)
	_hint = UI.label("Click, E or Space to continue", 14, Color("9a92b0"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)


## pages: Array of String or {text, who, big, bg}
func play(bg: Texture2D, pages: Array) -> void:
	_bg.texture = bg
	_pages = pages
	_i = 0
	_active = true
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	_bg.pivot_offset = size / 2.0
	_bg.scale = Vector2(1.0, 1.0)
	if _zoom_t:
		_zoom_t.kill()
	_zoom_t = create_tween()
	_zoom_t.tween_property(_bg, "scale", Vector2(1.08, 1.08), 40.0)
	_show()


func _show() -> void:
	var p: Variant = _pages[_i]
	var d: Dictionary = p if p is Dictionary else {"text": str(p)}
	if d.has("bg"):
		_bg.texture = d.bg
	var big: bool = d.get("big", false)
	_big.visible = big
	_panel.visible = not big
	_shade.color.a = 0.62 if big else 0.28
	if big:
		_big.text = d.text
		_big.modulate.a = 0.0
		create_tween().tween_property(_big, "modulate:a", 1.0, 1.4)
	else:
		_who.text = d.get("who", "")
		_who.visible = _who.text != ""
		_text.text = d.text
		_text.visible_characters = 0
		_chars = 0.0


func _process(delta: float) -> void:
	if not _active or _big.visible:
		return
	var total := _text.get_total_character_count()
	if _text.visible_characters < total:
		_chars += delta * 54.0
		_text.visible_characters = int(_chars)


func _advance() -> void:
	if not _big.visible:
		var total := _text.get_total_character_count()
		if _text.visible_characters < total:
			_text.visible_characters = total
			_chars = total
			return
	_i += 1
	if _i >= _pages.size():
		_active = false
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func() -> void:
			visible = false
			finished.emit())
	else:
		_show()


func _gui_input(event: InputEvent) -> void:
	if _active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _active and (event.is_action_pressed("o_interact") or event.is_action_pressed("ui_accept")):
		_advance()
		get_viewport().set_input_as_handled()
