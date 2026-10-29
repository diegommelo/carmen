class_name DossierScreen
extends Control
## Fichário de suspeitos no formato do famoso PowerPoint: o chefe no centro e os outros
## em volta, com setas apontando para ele. Clicar num nome abre a ficha num cartão, como
## no original. O conteúdo do cartão vem de main.gd.

signal picked(index: int)
signal back_pressed

## Cores do slide, fora da paleta da interface de propósito.
const SLIDE_BG := Color("000000")
const SLIDE_GREY := Color("7f7f7f")
const SLIDE_BLUE := Color("4f81bd")
const SLIDE_DIM := Color("3a3a3a")
const SLIDE_LINE := Color("ffffff")
const RADIUS := 32.0
const CENTER_RADIUS := 40.0
const BAR_HEIGHT := 24.0
## Letras por linha dentro do círculo; palavra maior é quebrada com hífen, como no slide.
const LINE_CHARS := 6

var _entries: Array = []
var _centers: Array[Vector2] = []
var _buttons: Array[Button] = []
var _hover := -1
var _current := 0
var _bar: HBoxContainer
var _dim: ColorRect
var _portrait: ColorRect
var _caption: Label
var _stamp: Label
var _title: Label
var _sheet: RichTextLabel
var _close: Button


## `entries`: [{name, boss, ruled_out}], na ordem do pacote. O chefe fica no centro.
func setup(entries: Array, back_text: String, close_text: String) -> void:
	_entries = entries
	for i in entries.size():
		_centers.append(Vector2.ZERO)
		_buttons.append(_node_button(i))
	_bar = HBoxContainer.new()
	add_child(_bar)
	GameFrame.add_spacer(_bar)
	_bar.add_child(_button(back_text, back_pressed.emit))
	_build_card(close_text)
	resized.connect(_layout)


func _node_button(i: int) -> Button:
	var b := Button.new()
	b.flat = true
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): picked.emit(i))
	for s in [b.mouse_entered, b.focus_entered]:
		s.connect(_set_hover.bind(i))
	for s in [b.mouse_exited, b.focus_exited]:
		s.connect(_set_hover.bind(-1))
	var label := Label.new()
	label.text = hyphenate(_entries[i].name)
	label.set_anchors_preset(PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", SLIDE_LINE)
	if _entries[i].boss:
		label.add_theme_font_size_override("font_size", 16)
	b.add_child(label)
	add_child(b)
	return b


## "Valéria Bolsonaro" vira "VALÉR- / IA / BOLSO- / NARO".
static func hyphenate(text: String) -> String:
	var lines := []
	for word in text.to_upper().split(" ", false):
		while word.length() > LINE_CHARS:
			lines.append(word.left(LINE_CHARS - 1) + "-")
			word = word.substr(LINE_CHARS - 1)
		lines.append(word)
	return "\n".join(lines)


func _build_card(close_text: String) -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.hide()
	_dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close_card())
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	_dim.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", PfTheme.box(Palette.TEXT, Palette.INK, 8))
	center.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	row.add_child(_build_portrait())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	row.add_child(column)
	_title = _card_label(Palette.PANEL)
	column.add_child(_title)
	_sheet = RichTextLabel.new()
	_sheet.bbcode_enabled = true
	_sheet.fit_content = true
	_sheet.custom_minimum_size.x = 320
	_sheet.add_theme_color_override("default_color", Palette.INK)
	column.add_child(_sheet)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	buttons.add_child(_button("<", func(): picked.emit(_current - 1)))
	buttons.add_child(_button(">", func(): picked.emit(_current + 1)))
	GameFrame.add_spacer(buttons)
	_close = _button(close_text, close_card)
	buttons.add_child(_close)


func _build_portrait() -> ColorRect:
	_portrait = ColorRect.new()
	_portrait.custom_minimum_size = Vector2(88, 104)
	var box := VBoxContainer.new()
	box.set_anchors_preset(PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_portrait.add_child(box)
	_stamp = _card_label(Palette.ALERT)
	_caption = _card_label(Palette.TEXT_DIM)
	box.add_child(_stamp)
	box.add_child(_caption)
	return _portrait


func _card_label(color: Color) -> Label:
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


## `rows` são pares [campo, valor]; `stamp`, quando não vazio, sai na cor `stamp_color`
## em cima do retrato.
func show_card(index: int, title: String, caption: String, tint: Color, stamp: String,
		stamp_color: Color, rows: Array) -> void:
	_current = index
	_title.text = title.to_upper()
	_portrait.color = tint
	_caption.text = caption
	_stamp.text = stamp
	_stamp.visible = stamp != ""
	_stamp.add_theme_color_override("font_color", stamp_color)
	var field := Palette.PANEL.to_html(false)
	_sheet.text = "\n".join(rows.map(func(r): return "[color=#%s]%s:[/color] %s" % [field, r[0], r[1]]))
	_dim.show()
	_close.grab_focus()


func close_card() -> void:
	_dim.hide()
	if _current < _buttons.size():
		_buttons[_current].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _dim.visible:
			close_card()
		else:
			back_pressed.emit()
		get_viewport().set_input_as_handled()


func _set_hover(i: int) -> void:
	_hover = i
	queue_redraw()


## Os comparsas ficam em volta, distribuídos pelo contorno de um retângulo a partir do
## alto, no sentido horário; o chefe fica no meio.
func _layout() -> void:
	var area := Vector2(size.x, size.y - BAR_HEIGHT)
	var mid := area / 2.0
	var half := mid - Vector2(RADIUS + 2, RADIUS + 2)
	var ring := range(_entries.size()).filter(func(i): return not _entries[i].boss)
	var perimeter := 4.0 * (half.x + half.y)
	for k in ring.size():
		_centers[ring[k]] = mid + _on_rect(half, perimeter * k / ring.size())
	for i in _entries.size():
		var r := CENTER_RADIUS if _entries[i].boss else RADIUS
		if _entries[i].boss:
			_centers[i] = mid
		_buttons[i].position = (_centers[i] - Vector2(r, r)).round()
		_buttons[i].size = Vector2(r, r) * 2.0
	_bar.position = Vector2(0, area.y)
	_bar.size = Vector2(size.x, BAR_HEIGHT)
	_dim.position = Vector2.ZERO
	_dim.size = size
	queue_redraw()


## Ponto a `s` pixels do alto-centro, andando pelo contorno no sentido horário.
static func _on_rect(half: Vector2, s: float) -> Vector2:
	var p := Vector2(0, -half.y)
	var dirs := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
	var lengths := [half.x, 2.0 * half.y, 2.0 * half.x, 2.0 * half.y, half.x]
	for j in dirs.size():
		if s <= lengths[j]:
			return p + dirs[j] * s
		p += dirs[j] * lengths[j]
		s -= lengths[j]
	return p


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y - BAR_HEIGHT)), SLIDE_BG)
	var boss := _entries.find_custom(func(e): return e.boss)
	for i in _entries.size():
		if i != boss and boss >= 0:
			_arrow(_centers[i], _centers[boss])
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var r := CENTER_RADIUS if e.boss else RADIUS
		var fill := SLIDE_BLUE if e.boss else SLIDE_GREY
		if e.ruled_out:
			fill = SLIDE_DIM
		draw_circle(_centers[i], r, fill, true, -1.0, false)
		draw_circle(_centers[i], r, SLIDE_LINE, false, 2.0, false)
		if e.ruled_out:
			var d := Vector2(r, r) * 0.6
			draw_line(_centers[i] - d, _centers[i] + d, Palette.ALERT, 3.0)
			draw_line(_centers[i] + Vector2(d.x, -d.y), _centers[i] - Vector2(d.x, -d.y), Palette.ALERT, 3.0)
		if i == _hover:
			draw_circle(_centers[i], r + 2, Palette.HIGHLIGHT, false, 2.0, false)


func _arrow(from: Vector2, to: Vector2) -> void:
	var dir := (to - from).normalized()
	var a := from + dir * (RADIUS + 3)
	var b := to - dir * (CENTER_RADIUS + 3)
	if a.distance_to(b) < 10:
		return
	var side := dir.orthogonal() * 5
	draw_line(a, b - dir * 6, SLIDE_LINE, 3.0)
	draw_colored_polygon(PackedVector2Array([b, b - dir * 9 + side, b - dir * 9 - side]), SLIDE_LINE)
