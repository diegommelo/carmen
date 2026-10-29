class_name PfTheme
extends RefCounted
## Tema de terminal da PF, montado em código: duas fontes bitmap (VT323 para o texto do
## jogo, Tiny5 para a interface), molduras de 1 px e as cores de Palette.
## As fontes só ficam nítidas nos tamanhos da grade delas: VT323 em 20, Tiny5 em 8.

const TEXT_FONT_PATH := "res://ui/theme/fonts/vt323-latin-400-normal.woff2"
const UI_FONT_PATH := "res://ui/theme/fonts/tiny5-latin-400-normal.woff2"
const TEXT_SIZE := 20
const UI_SIZE := 8


## Importadas sem antialiasing, sem hinting e sem posição subpixel (ver os .import).
static func text_font() -> FontFile:
	return load(TEXT_FONT_PATH)


static func ui_font() -> FontFile:
	return load(UI_FONT_PATH)


static func box(bg: Color, border: Color, margin: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(margin)
	s.anti_aliasing = false
	return s


static func build() -> Theme:
	var t := Theme.new()
	var text := text_font()
	t.default_font = ui_font()
	t.default_font_size = UI_SIZE

	t.set_color("font_color", "Label", Palette.TEXT)

	t.set_font("normal_font", "RichTextLabel", text)
	t.set_font("bold_font", "RichTextLabel", text)
	t.set_font("italics_font", "RichTextLabel", text)
	for kind in ["normal", "bold", "italics"]:
		t.set_font_size(kind + "_font_size", "RichTextLabel", TEXT_SIZE)
	t.set_color("default_color", "RichTextLabel", Palette.TEXT)
	t.set_constant("line_separation", "RichTextLabel", -4)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	t.set_stylebox("panel", "PanelContainer", box(Palette.PANEL, Palette.PANEL_BORDER))
	t.set_stylebox("panel", "Panel", box(Palette.PANEL, Palette.PANEL_BORDER))

	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, box(Palette.PANEL, Palette.PANEL_BORDER, 3))
		t.set_stylebox("hover", type, box(Palette.PANEL, Palette.HIGHLIGHT, 3))
		t.set_stylebox("pressed", type, box(Palette.PANEL_BORDER, Palette.HIGHLIGHT, 3))
		t.set_stylebox("focus", type, box(Color.TRANSPARENT, Palette.HIGHLIGHT, 3))
		t.set_stylebox("disabled", type, box(Palette.INK, Palette.PANEL_BORDER, 3))
		t.set_color("font_color", type, Palette.TEXT)
		t.set_color("font_hover_color", type, Palette.HIGHLIGHT)
		t.set_color("font_pressed_color", type, Palette.HIGHLIGHT)
		t.set_color("font_focus_color", type, Palette.TEXT)
		t.set_color("font_hover_pressed_color", type, Palette.HIGHLIGHT)
		t.set_color("font_disabled_color", type, Palette.TEXT_DIM)

	# Itens da barra de menu: texto solto, sem moldura.
	t.add_type("MenuItem")
	t.set_type_variation("MenuItem", "Button")
	var flat := StyleBoxEmpty.new()
	flat.set_content_margin_all(2)
	flat.content_margin_left = 6
	flat.content_margin_right = 6
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "MenuItem", flat)
	t.set_color("font_color", "MenuItem", Palette.INK)
	t.set_color("font_hover_color", "MenuItem", Palette.PANEL_BORDER)
	t.set_color("font_pressed_color", "MenuItem", Palette.PANEL_BORDER)
	t.set_color("font_focus_color", "MenuItem", Palette.INK)

	t.set_stylebox("panel", "PopupMenu", box(Palette.PANEL, Palette.HIGHLIGHT, 2))
	t.set_stylebox("hover", "PopupMenu", box(Palette.PANEL_BORDER, Palette.PANEL_BORDER, 0))
	t.set_color("font_color", "PopupMenu", Palette.TEXT)
	t.set_color("font_hover_color", "PopupMenu", Palette.HIGHLIGHT)
	t.set_constant("v_separation", "PopupMenu", 4)

	t.set_stylebox("normal", "LineEdit", box(Palette.INK, Palette.PANEL_BORDER, 3))
	t.set_stylebox("focus", "LineEdit", box(Color.TRANSPARENT, Palette.HIGHLIGHT, 3))
	t.set_font("font", "LineEdit", text)
	t.set_font_size("font_size", "LineEdit", TEXT_SIZE)
	t.set_color("font_color", "LineEdit", Palette.TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Palette.TEXT_DIM)
	t.set_color("caret_color", "LineEdit", Palette.HIGHLIGHT)

	t.set_stylebox("background", "ProgressBar", box(Palette.INK, Palette.PANEL_BORDER, 0))
	t.set_stylebox("fill", "ProgressBar", box(Palette.HIGHLIGHT, Palette.HIGHLIGHT, 0))

	t.set_stylebox("panel", "AcceptDialog", box(Palette.PANEL, Palette.HIGHLIGHT, 8))
	for state in ["embedded_border", "embedded_unfocused_border"]:
		# A barra de título fica na margem expandida, acima do conteúdo.
		var border := box(Palette.PANEL, Palette.HIGHLIGHT, 0)
		border.set_expand_margin_all(1)
		border.expand_margin_top = 18
		t.set_stylebox(state, "Window", border)
	t.set_font("title_font", "Window", text)
	t.set_font_size("title_font_size", "Window", TEXT_SIZE)
	t.set_color("title_color", "Window", Palette.HIGHLIGHT)
	t.set_constant("title_height", "Window", 18)

	t.set_stylebox("scroll", "VScrollBar", box(Palette.INK, Palette.INK, 0))
	t.set_stylebox("grabber", "VScrollBar", box(Palette.PANEL_BORDER, Palette.PANEL_BORDER, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Palette.HIGHLIGHT, Palette.HIGHLIGHT, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(Palette.HIGHLIGHT, Palette.HIGHLIGHT, 0))
	return t
