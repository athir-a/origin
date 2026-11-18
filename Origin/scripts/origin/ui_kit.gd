extends RefCounted
## Tiny UI kit giving every screen the same cozy parchment-and-wood pixel look.

const PARCH := Color("f3e4c0")
const PARCH_D := Color("e2cd9c")
const PARCH_DD := Color("c9b07a")
const INK := Color("3b2a1a")
const INK_L := Color("6e5539")
const WOODC := Color("7e5634")
const WOODC_H := Color("9a6b40")
const WOODC_P := Color("5e3f24")
const MOSS := Color("5d8f46")
const MOSS_H := Color("74a95a")
const MOSS_P := Color("476f34")
const GOLD := Color("e2a93a")
const GOLD_H := Color("f0c060")
const NIGHT := Color("1a1f3a")
const NIGHT_L := Color("2c335c")
const CREAM := Color("fbf1d6")
const ROSE := Color("c96f6f")

const FONT_BOLD := "res://assets/template/fonts/ui_bold.tres"
const FONT_MED := "res://assets/template/fonts/ui_medium.tres"
const FONT_TITLE := "res://assets/template/fonts/display/generic_title.tres"
const FONT_HEAD := "res://assets/template/fonts/display/generic_heading.tres"


static func box(bg: Color, border: Color = INK, bw: int = 3, margin: int = 12, shadow: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.border_width_bottom = bw + 2
	sb.set_content_margin_all(margin)
	sb.set_corner_radius_all(3)
	sb.corner_detail = 1
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(0, 4)
	sb.anti_aliasing = false
	return sb


static func font(path: String) -> Font:
	return load(path) as Font


static func label(text: String, size: int = 18, color: Color = INK, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font(FONT_BOLD))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


static func wrap_label(text: String, size: int = 18, color: Color = INK, bold: bool = false) -> Label:
	var l := label(text, size, color, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func title(text: String, size: int = 40, color: Color = CREAM) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font(FONT_TITLE))
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 8)
	return l


static func heading(text: String, size: int = 26, color: Color = INK) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font(FONT_HEAD))
	return l


static func panel(bg: Color = PARCH, border: Color = INK, margin: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 3, margin))
	return p


static func button(text: String, kind: String = "wood", size: int = 18, min_size: Vector2 = Vector2(0, 40)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font(FONT_BOLD))
	var base := WOODC
	var hi := WOODC_H
	var pr := WOODC_P
	var txt := CREAM
	match kind:
		"moss":
			base = MOSS
			hi = MOSS_H
			pr = MOSS_P
		"gold":
			base = GOLD
			hi = GOLD_H
			pr = Color("b98625")
			txt = INK
		"parch":
			base = PARCH_D
			hi = PARCH
			pr = PARCH_DD
			txt = INK
		"ghost":
			base = Color(0, 0, 0, 0.0)
			hi = Color(1, 1, 1, 0.12)
			pr = Color(0, 0, 0, 0.18)
			txt = CREAM
		"night":
			base = NIGHT_L
			hi = Color("3d4680")
			pr = NIGHT
	var border := INK if kind != "ghost" else Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", box(base, border, 3, 10, kind != "ghost"))
	b.add_theme_stylebox_override("hover", box(hi, border, 3, 10, kind != "ghost"))
	b.add_theme_stylebox_override("pressed", box(pr, border, 3, 10, false))
	b.add_theme_stylebox_override("disabled", box(base.darkened(0.2).lerp(Color(0.5, 0.5, 0.5), 0.4), border, 3, 10, false))
	var focus := box(Color(0, 0, 0, 0), Color("ffe07a"), 3, 10, false)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_color_override("font_color", txt)
	b.add_theme_color_override("font_hover_color", txt)
	b.add_theme_color_override("font_pressed_color", txt)
	b.add_theme_color_override("font_disabled_color", txt.darkened(0.4))
	b.add_theme_color_override("font_focus_color", txt)
	return b


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer(h: float = 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func margin(child: Control, m: int) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", m)
	mc.add_theme_constant_override("margin_right", m)
	mc.add_theme_constant_override("margin_top", m)
	mc.add_theme_constant_override("margin_bottom", m)
	mc.add_child(child)
	return mc


## A chunky progress bar. Returns a Control with `frac` meta that can be updated by set_bar().
static func bar(frac: float, h: int = 14, fill: Color = MOSS, back: Color = Color("4a3a28")) -> Control:
	var c := BarControl.new()
	c.frac = frac
	c.fill = fill
	c.back = back
	c.custom_minimum_size = Vector2(60, h)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func set_bar(c: Control, frac: float) -> void:
	(c as BarControl).frac = frac
	c.queue_redraw()


class BarControl extends Control:
	var frac := 0.0
	var fill := Color("5d8f46")
	var back := Color("4a3a28")
	var shown := 0.0

	func _process(delta: float) -> void:
		if absf(shown - frac) > 0.002:
			shown = lerpf(shown, frac, 1.0 - exp(-delta * 6.0))
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("2a1b14"))
		draw_rect(r.grow(-2), back)
		var inner := r.grow(-2)
		var w := inner.size.x * clampf(shown, 0.0, 1.0)
		if w > 0.0:
			draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), fill)
			draw_rect(Rect2(inner.position, Vector2(w, 2)), fill.lightened(0.35))
			draw_rect(Rect2(inner.position.x, inner.end.y - 2, w, 2), fill.darkened(0.25))


## A rounded subject badge (2 letters on a colored plate)
static func badge(code: String, color: Color, size: int = 36) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(size, size)
	p.add_theme_stylebox_override("panel", box(color, INK, 2, 2, false))
	var l := label(code, int(size * 0.42), Color.WHITE, true)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func fmt_duration(seconds: int) -> String:
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%d min" % m
	return "%d sec" % seconds


static func fmt_clock(seconds: int) -> String:
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	var s := seconds % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]
