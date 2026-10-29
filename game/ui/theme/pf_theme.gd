class_name PfTheme
extends RefCounted
## Tema de terminal da PF: a fonte bitmap Press Start 2P, molduras de 1 px e as cores de
## Palette. A fonte só fica nítida em 8 px (ou múltiplos); ela foi importada sem
## antialiasing, sem hinting e sem posição subpixel (ver o .import).

const FONT_PATH := "res://ui/theme/fonts/press-start-2p-latin-400-normal.woff2"
const FONT_SIZE := 8
## Espaço extra entre linhas: os glifos ocupam a altura toda da fonte.
const LINE_GAP := 4


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
	t.default_font = load(FONT_PATH)
	t.default_font_size = FONT_SIZE
	t.set_color("font_color", "Label", Palette.TEXT)
	t.set_constant("line_spacing", "Label", LINE_GAP)
	_text(t)
	_panels(t)
	_buttons(t)
	_menu_items(t)
	_inputs(t)
	_dialogs(t)
	return t


static func _text(t: Theme) -> void:
	t.set_color("default_color", "RichTextLabel", Palette.TEXT)
	t.set_constant("line_separation", "RichTextLabel", LINE_GAP)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("scroll", "VScrollBar", box(Palette.INK, Palette.INK, 0))
	t.set_stylebox("grabber", "VScrollBar", box(Palette.PANEL_BORDER, Palette.PANEL_BORDER, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Palette.HIGHLIGHT, Palette.HIGHLIGHT, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(Palette.HIGHLIGHT, Palette.HIGHLIGHT, 0))


static func _panels(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", box(Palette.PANEL, Palette.PANEL_BORDER, 2))
	t.set_stylebox("background", "ProgressBar", box(Palette.INK, Palette.PANEL_BORDER, 0))
	t.set_stylebox("fill", "ProgressBar", box(Palette.HIGHLIGHT, Palette.HIGHLIGHT, 0))


## Botão: moldura azul, que fica dourada sob o mouse ou com foco.
static func _buttons(t: Theme) -> void:
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, box(Palette.PANEL, Palette.PANEL_BORDER, 2))
		t.set_stylebox("hover", type, box(Palette.PANEL, Palette.HIGHLIGHT, 2))
		t.set_stylebox("pressed", type, box(Palette.PANEL_BORDER, Palette.HIGHLIGHT, 2))
		t.set_stylebox("focus", type, box(Color.TRANSPARENT, Palette.HIGHLIGHT, 2))
		t.set_stylebox("disabled", type, box(Palette.INK, Palette.PANEL_BORDER, 2))
		t.set_color("font_color", type, Palette.TEXT)
		t.set_color("font_hover_color", type, Palette.HIGHLIGHT)
		t.set_color("font_pressed_color", type, Palette.HIGHLIGHT)
		t.set_color("font_focus_color", type, Palette.TEXT)
		t.set_color("font_hover_pressed_color", type, Palette.HIGHLIGHT)
		t.set_color("font_disabled_color", type, Palette.TEXT_DIM)
	t.set_stylebox("panel", "PopupMenu", box(Palette.PANEL, Palette.HIGHLIGHT, 2))
	t.set_stylebox("hover", "PopupMenu", box(Palette.PANEL_BORDER, Palette.PANEL_BORDER, 0))
	t.set_color("font_color", "PopupMenu", Palette.TEXT)
	t.set_color("font_hover_color", "PopupMenu", Palette.HIGHLIGHT)


## Itens da barra de menu: texto escuro solto sobre a barra creme, sem moldura.
static func _menu_items(t: Theme) -> void:
	t.add_type("MenuItem")
	t.set_type_variation("MenuItem", "Button")
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = 8
	flat.content_margin_right = 8
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "MenuItem", flat)
	t.set_color("font_color", "MenuItem", Palette.INK)
	t.set_color("font_hover_color", "MenuItem", Palette.PANEL_BORDER)
	t.set_color("font_pressed_color", "MenuItem", Palette.PANEL_BORDER)
	t.set_color("font_focus_color", "MenuItem", Palette.INK)


static func _inputs(t: Theme) -> void:
	t.set_stylebox("normal", "LineEdit", box(Palette.INK, Palette.PANEL_BORDER, 2))
	t.set_stylebox("focus", "LineEdit", box(Color.TRANSPARENT, Palette.HIGHLIGHT, 2))
	t.set_color("font_color", "LineEdit", Palette.TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Palette.TEXT_DIM)
	t.set_color("caret_color", "LineEdit", Palette.HIGHLIGHT)


## Diálogos: a barra de título fica na margem expandida da moldura, acima do conteúdo.
static func _dialogs(t: Theme) -> void:
	t.set_stylebox("panel", "AcceptDialog", box(Palette.PANEL, Palette.HIGHLIGHT, 8))
	for state in ["embedded_border", "embedded_unfocused_border"]:
		var border := box(Palette.PANEL, Palette.HIGHLIGHT, 0)
		border.set_expand_margin_all(1)
		border.expand_margin_top = 22
		t.set_stylebox(state, "Window", border)
	t.set_color("title_color", "Window", Palette.HIGHLIGHT)
	t.set_constant("title_height", "Window", 22)
