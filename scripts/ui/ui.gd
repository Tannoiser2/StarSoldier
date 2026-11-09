class_name UI
extends RefCounted
## Helper grafici condivisi. Tema "copertina SPI 1977": carta color crema, le macchie rosso-arancio
## dell'aerografo dietro lo StarSoldier, l'inchiostro seppia dell'illustrazione e il nero pieno del logo.
## Caratteri liberi (OFL): Russo One inclinato per i titoli (il lettering pesante e corsivo del logo),
## Saira Condensed per le intestazioni, Saira per i testi, Share Tech Mono per esagoni e numeri.

const PAPER := Color("#f3ecdc")
const PAPER_D := Color("#e4d8bf")
const PAPER_L := Color("#fbf7ee")
const INK := Color("#2b1a10")
const SEPIA := Color("#6b4a32")
const SEPIA_L := Color("#a08066")
const RED := Color("#e0452a")
const RED_D := Color("#a62a17")
const RED_L := Color("#f7a08a")
const BLACK := Color("#141010")
const SPACE := Color("#0a0807")
const TEXT := INK
const MUTED := Color("#7d6450")
const GREEN := Color("#3e7d3a")
const BLUE := Color("#2f6fb0")
const GOLD := Color("#c98a1a")
const WHITE := Color("#ffffff")

static var font_title: Font
static var font_head: Font
static var font_body: Font
static var font_bold: Font
static var font_mono: Font
static var _tex := {}


static func init_fonts() -> void:
	if font_title != null:
		return
	var russo: FontFile = load("res://assets/fonts/RussoOne-Regular.ttf")
	var ft := FontVariation.new()
	ft.base_font = russo
	ft.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.22, 1), Vector2.ZERO)
	font_title = ft
	font_head = load("res://assets/fonts/SairaCondensed-Bold.ttf")
	var saira: FontFile = load("res://assets/fonts/Saira.ttf")
	var fb := FontVariation.new()
	fb.base_font = saira
	fb.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 480}
	font_body = fb
	var fbb := FontVariation.new()
	fbb.base_font = saira
	fbb.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	font_bold = fbb
	font_mono = load("res://assets/fonts/ShareTechMono-Regular.ttf")


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## colore del lato in gioco (Alpha rosso, Bravo blu) o della specie
static func side_color(s: int) -> Color:
	return RED if s == 0 else BLUE


static func species_color(sp: String) -> Color:
	match sp:
		"h":
			return Color("#8fc8f5")
		"l":
			return Color("#7f9a1f")
		"r":
			return Color("#f2c21c")
		"x":
			return Color("#98b58a")
		"d":
			return Color("#b08a4a")
	return Color.WHITE


static func make_theme() -> Theme:
	init_fonts()
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", BLACK)
	t.set_color("font_pressed_color", "Button", PAPER_L)
	t.set_color("font_hover_pressed_color", "Button", PAPER_L)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.48, 0.42))
	t.set_font("font", "Button", font_head)
	t.set_stylebox("normal", "Button", box(PAPER_D, SEPIA, 2, 4))
	t.set_stylebox("hover", "Button", box(Color("#efe2c6"), RED, 2, 4))
	t.set_stylebox("pressed", "Button", box(RED_D, BLACK, 2, 4))
	t.set_stylebox("disabled", "Button", box(Color("#ddd3bf"), Color("#bfb19b"), 1, 4))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(Color(PAPER, 0.96), SEPIA, 2, 4))
	t.set_stylebox("normal", "LineEdit", box(PAPER_L, SEPIA, 2, 4))
	t.set_stylebox("focus", "LineEdit", box(PAPER_L, RED, 2, 4))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", SEPIA_L)
	t.set_color("caret_color", "LineEdit", RED_D)
	t.set_stylebox("panel", "PopupMenu", box(PAPER, SEPIA, 2, 4))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", RED_D)
	t.set_stylebox("normal", "OptionButton", box(PAPER_D, SEPIA, 2, 4))
	t.set_stylebox("hover", "OptionButton", box(Color("#efe2c6"), RED, 2, 4))
	t.set_stylebox("pressed", "OptionButton", box(RED_D, BLACK, 2, 4))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", INK)
	t.set_stylebox("scroll", "VScrollBar", box(PAPER_D, PAPER_D, 0, 4))
	t.set_stylebox("grabber", "VScrollBar", box(SEPIA_L, SEPIA_L, 0, 4))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(RED, RED, 0, 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(RED_D, RED_D, 0, 4))
	t.set_stylebox("scroll", "HScrollBar", box(PAPER_D, PAPER_D, 0, 4))
	t.set_stylebox("grabber", "HScrollBar", box(SEPIA_L, SEPIA_L, 0, 4))
	t.set_stylebox("panel", "TooltipPanel", box(PAPER_L, SEPIA, 2, 4))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", 17)
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", RED_D)
	t.set_color("default_color", "RichTextLabel", INK)
	return t


static func box(bg: Color, border: Color, bw := 2, radius := 4, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 2
	s.content_margin_right = pad + 2
	s.content_margin_top = pad - 3
	s.content_margin_bottom = pad - 3
	return s


static func panel_style(alpha := 0.95) -> StyleBoxFlat:
	var s := box(Color(PAPER, alpha), SEPIA, 2, 4, 14)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	return s


static func label(t: String, size := 20, col := TEXT, font: Font = null) -> Label:
	init_fonts()
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


static func wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	return l


static func title(t: String, size := 48, col := BLACK) -> Label:
	init_fonts()
	var l := label(t, size, col, font_title)
	l.add_theme_color_override("font_shadow_color", Color(RED, 0.85))
	l.add_theme_constant_override("shadow_offset_x", maxi(2, size / 18))
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 18))
	return l


static func head(t: String, size := 22, col := INK) -> Label:
	init_fonts()
	return label(t, size, col, font_head)


static func mono(t: String, size := 18, col := TEXT) -> Label:
	init_fonts()
	return label(t, size, col, font_mono)


static func button(t: String, w := 0, h := 48, size := 20) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func primary(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", box(RED, BLACK, 2, 4))
	b.add_theme_stylebox_override("hover", box(Color("#f05a3c"), BLACK, 2, 4))
	b.add_theme_stylebox_override("pressed", box(RED_D, BLACK, 2, 4))
	b.add_theme_color_override("font_color", PAPER_L)
	b.add_theme_color_override("font_hover_color", WHITE)
	return b


## pulsante attivo/selezionato
static func toggled(b: Button, on: bool) -> Button:
	if on:
		b.add_theme_stylebox_override("normal", box(INK, RED, 2, 4))
		b.add_theme_stylebox_override("hover", box(Color("#3d2617"), RED, 2, 4))
		b.add_theme_color_override("font_color", PAPER_L)
		b.add_theme_color_override("font_hover_color", WHITE)
	else:
		b.remove_theme_stylebox_override("normal")
		b.remove_theme_stylebox_override("hover")
		b.remove_theme_color_override("font_color")
		b.remove_theme_color_override("font_hover_color")
	return b


static func rich(size := 18) -> RichTextLabel:
	init_fonts()
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_override("normal_font", font_body)
	r.add_theme_font_override("bold_font", font_bold)
	r.add_theme_font_override("mono_font", font_mono)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("mono_font_size", size)
	r.add_theme_color_override("default_color", INK)
	return r


static func hsep(col := SEPIA_L) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.custom_minimum_size = Vector2(0, 2)
	return c


## Sfondo dei menu: la carta della copertina con le macchie dell'aerografo che pulsano piano.
class Airbrush extends Control:
	var blobs: Array = []
	var t := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := RandomNumberGenerator.new()
		g.seed = 1977
		for i in 26:
			blobs.append([Vector2(g.randf(), g.randf()), g.randf_range(0.03, 0.16), g.randf_range(0.25, 0.75), g.randf() * 6.28])

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), UI.PAPER)
		var m := minf(s.x, s.y)
		for b in blobs:
			var p: Vector2 = b[0] * s
			var r: float = b[1] * m * (0.95 + 0.05 * sin(t * 0.5 + b[3]))
			# alone morbido: cerchi concentrici sempre più trasparenti
			for k in 7:
				var f := 1.0 - float(k) / 7.0
				draw_circle(p, r * (0.45 + 0.6 * float(k) / 6.0), Color(UI.RED, b[2] * 0.11 * f + 0.02))
		# grana della carta
		for i in 140:
			var q := Vector2(fposmod(sin(i * 12.9898) * 43758.5453, 1.0), fposmod(sin(i * 78.233) * 12345.678, 1.0)) * s
			draw_circle(q, 1.2, Color(UI.SEPIA, 0.12))
