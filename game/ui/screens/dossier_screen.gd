class_name DossierScreen
extends VBoxContainer
## Fichário de suspeitos em tela cheia, aberto pelo menu: retrato à esquerda, ficha à
## direita, setas para folhear. Quem escolhe o que mostrar é main.gd.

signal turned(step: int)
signal back_pressed

var _portrait: ColorRect
var _name: Label
var _caption: Label
var _stamp: Label
var _sheet: RichTextLabel


func setup(back_text: String) -> void:
	add_theme_constant_override("separation", 6)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	body.add_child(_build_portrait())
	_sheet = RichTextLabel.new()
	_sheet.bbcode_enabled = true
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet.add_theme_color_override("default_color", Palette.TEXT)
	body.add_child(_sheet)
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(_button("<", turned.emit.bind(-1)))
	row.add_child(_button(">", turned.emit.bind(1)))
	GameFrame.add_spacer(row)
	row.add_child(_button(back_text, back_pressed.emit))


func _build_portrait() -> ColorRect:
	_portrait = ColorRect.new()
	_portrait.custom_minimum_size = Vector2(176, 0)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_portrait.add_child(box)
	_stamp = _label(Palette.ALERT)
	_name = _label(Palette.HIGHLIGHT)
	_caption = _label(Palette.TEXT_DIM)
	for l in [_stamp, _name, _caption]:
		box.add_child(l)
	return _portrait


func _label(color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	return b


## `stamp`, quando não vazio, aparece em vermelho em cima do retrato.
func show_entry(title: String, caption: String, tint: Color, stamp: String, sheet: String) -> void:
	_portrait.color = tint
	_name.text = title
	_caption.text = caption
	_stamp.text = stamp
	_stamp.visible = stamp != ""
	_sheet.text = sheet
