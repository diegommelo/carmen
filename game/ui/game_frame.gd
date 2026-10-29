class_name GameFrame
extends Control
## Moldura comum das telas do jogo, numa tela de 640 × 360 (ver o guia de estilo).
## Só desenha e repassa cliques; quem conhece as regras é main.gd. Telas que precisam
## de mais espaço (viagem, mandado) abrem por cima da cena e do texto com show_overlay.

signal verb_pressed(index: int)
signal menu_pressed(id: String)

const MENU_IDS := ["new_career", "rank", "language", "about"]
const VERB_COUNT := 4
## Caracteres por segundo da máquina de escrever.
const TYPE_SPEED := 60.0

## Posição e tamanho de cada parte da moldura, em pixels da tela de 640 × 360.
const MENU_BAR := Rect2i(0, 0, 640, 20)
const CASE_BAR := Rect2i(8, 24, 624, 24)
const HEADER := Rect2i(8, 52, 296, 24)
const SCENE := Rect2i(8, 80, 296, 212)
const TEXT_PANEL := Rect2i(308, 52, 324, 240)
const NOTES := Rect2i(8, 296, 216, 56)
const FIRST_VERB := Rect2i(228, 296, 98, 56)
const VERB_STEP := 102
const OVERLAY := Rect2i(8, 52, 624, 240)

var _menu: Dictionary = {}
var _case_label: Label
var _budget_label: Label
var _deadline_label: Label
var _deadline_bar: ProgressBar
var _header: Label
var _scene_bg: ColorRect
var _scene_title: Label
var _scene_caption: Label
var _stamp: Label
var _text: RichTextLabel
var _more: Label
var _choices: VBoxContainer
var _notes: Label
var _verbs: Array[Button] = []
var _verb_names: Array[Label] = []
var _verb_keys: Array[Label] = []
var _overlay: PanelContainer
var _typed := 0.0
## Primeira linha da página que está no painel de texto.
var _page_line := 0
## A página encheu e o texto espera um clique ou uma tecla para continuar.
var _waiting_page := false
## Linhas vazias no fim do texto para a última página poder rolar até o topo.
var _padding := 0


func _ready() -> void:
	theme = PfTheme.build()
	_build_menu_bar()
	_build_case_bar()
	_build_header()
	_build_scene()
	_build_text_panel()
	_build_notes()
	_build_verbs()
	_build_overlay()


func _build_menu_bar() -> void:
	var bar := ColorRect.new()
	bar.color = Palette.TEXT
	_place(bar, MENU_BAR)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(row)
	for id in MENU_IDS:
		var b := Button.new()
		b.theme_type_variation = "MenuItem"
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): menu_pressed.emit(id))
		row.add_child(b)
		_menu[id] = b


func _build_case_bar() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_place(_panel(row), CASE_BAR)
	_case_label = _label()
	_case_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_case_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_case_label)
	_budget_label = _label()
	row.add_child(_budget_label)
	_deadline_label = _label()
	row.add_child(_deadline_label)
	_deadline_bar = ProgressBar.new()
	_deadline_bar.custom_minimum_size = Vector2(64, 8)
	_deadline_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_deadline_bar.show_percentage = false
	_deadline_bar.max_value = 1.0
	_deadline_bar.step = 0.0
	row.add_child(_deadline_bar)


func _build_header() -> void:
	_header = _label(Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	_header.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(_panel(_header), HEADER)


## Até a arte existir, a cena é um placeholder colorido com o nome do arquivo esperado.
func _build_scene() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PfTheme.box(Palette.INK, Palette.PANEL_BORDER, 1))
	_place(panel, SCENE)
	_scene_bg = ColorRect.new()
	panel.add_child(_scene_bg)
	var labels := VBoxContainer.new()
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(labels)
	_scene_title = _label(Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_scene_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(_scene_title)
	_scene_caption = _label(Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	labels.add_child(_scene_caption)
	_stamp = _label(Palette.ALERT, HORIZONTAL_ALIGNMENT_CENTER)
	_stamp.add_theme_stylebox_override("normal", PfTheme.box(Palette.INK, Palette.ALERT, 4))
	_stamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stamp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_stamp.hide()
	panel.add_child(_stamp)


func _build_text_panel() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_place(_panel(box), TEXT_PANEL)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.gui_input.connect(_on_text_input)
	box.add_child(_text)
	_more = _label(Palette.HIGHLIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	_more.hide()
	box.add_child(_more)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 3)
	box.add_child(_choices)


func _build_notes() -> void:
	_notes = _label()
	_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notes.max_lines_visible = 3
	_place(_panel(_notes), NOTES)


## Cada verbo é um botão com o nome em cima e a tecla de atalho embaixo.
func _build_verbs() -> void:
	for i in VERB_COUNT:
		var b := Button.new()
		b.pressed.connect(func(): verb_pressed.emit(i))
		var rect := FIRST_VERB
		rect.position.x += VERB_STEP * i
		_place(b, rect)
		var labels := VBoxContainer.new()
		labels.set_anchors_preset(Control.PRESET_FULL_RECT)
		labels.alignment = BoxContainer.ALIGNMENT_CENTER
		labels.add_theme_constant_override("separation", 6)
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(labels)
		_verb_names.append(_label(Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		_verb_keys.append(_label(Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		labels.add_child(_verb_names[i])
		labels.add_child(_verb_keys[i])
		_verbs.append(b)


func _build_overlay() -> void:
	_overlay = PanelContainer.new()
	_overlay.hide()
	_place(_overlay, OVERLAY)


func _place(node: Control, rect: Rect2i) -> void:
	node.position = rect.position
	node.size = rect.size
	add_child(node)


func _panel(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_child(content)
	return panel


func _label(color: Color = Palette.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func set_menu_texts(texts: Dictionary) -> void:
	for id in texts:
		_menu[id].text = texts[id]


func set_verbs(names: Array, key_format: String) -> void:
	for i in VERB_COUNT:
		_verb_names[i].text = names[i]
		_verb_keys[i].text = key_format % (i + 1)


func set_verbs_enabled(enabled: bool) -> void:
	for b in _verbs:
		b.disabled = not enabled


## O nome do caso é o que encurta quando falta espaço. `remaining` vai de 1 (prazo
## inteiro) a 0 (prazo esgotado); sem prazo, a barra some.
func set_case(case_text: String, budget_text: String, deadline_text: String, remaining: float) -> void:
	_case_label.text = case_text
	_budget_label.text = budget_text
	_deadline_label.text = deadline_text
	_deadline_bar.visible = deadline_text != ""
	_deadline_bar.value = clampf(remaining, 0.0, 1.0)
	var color := Palette.ALERT if remaining < 0.25 else Palette.HIGHLIGHT
	_deadline_bar.add_theme_stylebox_override("fill", PfTheme.box(color, color, 0))


func set_header(text: String) -> void:
	_header.text = text


## `stamp`, quando não vazio, aparece carimbado em vermelho no alto da cena.
func show_scene(title: String, caption: String, tint: Color, stamp: String = "") -> void:
	_scene_bg.color = tint
	_scene_title.text = title
	_scene_caption.text = caption
	_stamp.text = stamp
	_stamp.visible = stamp != ""


## Abre `content` por cima da cena e do painel de texto, no lugar do que estava aberto.
func show_overlay(content: Control) -> void:
	hide_overlay()
	_overlay.add_child(content)
	_overlay.show()


func hide_overlay() -> void:
	for child in _overlay.get_children():
		_overlay.remove_child(child)
		child.queue_free()
	_overlay.hide()


func is_overlay_open() -> bool:
	return _overlay.visible


func set_notes(text: String) -> void:
	_notes.text = text


func clear_text() -> void:
	_text.clear()
	_text.visible_characters = 0
	_typed = 0.0
	_page_line = 0
	_waiting_page = false
	_padding = 0
	_more.hide()
	_text.scroll_to_line(0)


## Acrescenta texto ao painel, que aparece em máquina de escrever, uma página por vez.
func say(text: String) -> void:
	for i in _padding:
		_text.remove_paragraph(_text.get_paragraph_count() - 1)
	_padding = 0
	if not is_typing():
		_typed = _text.get_total_character_count()
		_text.visible_characters = int(_typed)
	_text.append_text(text + "\n")


## Verdadeiro enquanto o texto ainda está sendo escrito ou espera virar a página.
func is_typing() -> bool:
	return _text.visible_characters >= 0


## Mostra de uma vez o resto da página atual.
func finish_typing() -> void:
	if is_typing() and not _waiting_page:
		_typed = _page_end()
		_reach(int(_typed))


## A quebra de página é recalculada a cada quadro porque o texto só sabe onde quebra
## as linhas depois de ser diagramado na largura do painel.
func _process(delta: float) -> void:
	if _page_line > 0:
		_keep_page_on_top()
	if not is_typing():
		return
	var end := _page_end()
	if _waiting_page:
		_text.visible_characters = end
		return
	_typed = minf(_typed + TYPE_SPEED * delta, end)
	_reach(int(_typed))


## Mostra o texto até o caractere `shown`; no fim da página, espera; no fim do texto, para.
func _reach(shown: int) -> void:
	_text.visible_characters = shown
	if shown < _page_end():
		return
	if shown >= _text.get_total_character_count():
		_text.visible_characters = -1
	else:
		_waiting_page = true
		_more.text = tr("MORE")
		_more.show()


func _next_page() -> void:
	_waiting_page = false
	_more.hide()
	_page_line += _lines_per_page()
	_keep_page_on_top()


## Rola o texto para a página atual ficar no topo. Na última página pode faltar texto
## para rolar até lá, então o fim recebe linhas vazias. A página tem uma sobra menor que
## uma linha, por isso a linha a mais.
func _keep_page_on_top() -> void:
	var missing := _page_line + _lines_per_page() + 1 - _text.get_line_count()
	for i in missing:
		_text.newline()
		_padding += 1
	_text.get_v_scroll_bar().value = _text.get_line_offset(_page_line)


func _lines_per_page() -> int:
	var gap := _text.get_theme_constant("line_separation")
	var line := _text.get_theme_font("normal_font").get_height(_text.get_theme_font_size("normal_font_size")) + gap
	return maxi(1, int((_text.size.y + gap) / line))


## Índice do primeiro caractere que não cabe na página atual (ou o total, se tudo cabe).
func _page_end() -> int:
	var total := _text.get_total_character_count()
	var first_out := _page_line + _lines_per_page()
	if first_out >= _text.get_line_count():
		return total
	var lo := 0
	var hi := total
	while lo < hi:
		var mid := (lo + hi) / 2
		if _text.get_character_line(mid) < first_out:
			lo = mid + 1
		else:
			hi = mid
	return lo


## Clique no texto: vira a página ou termina a máquina de escrever.
func _on_text_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance_text()


func _advance_text() -> bool:
	if _waiting_page:
		_next_page()
		return true
	if is_typing():
		finish_typing()
		return true
	return false


func clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


## Escolhas ficam no pé do painel de texto, em linhas que quebram sozinhas.
func add_choice_row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 3)
	row.add_theme_constant_override("v_separation", 3)
	_choices.add_child(row)
	return row


## Escolhas uma embaixo da outra, na largura toda do painel.
func add_choice_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_choices.add_child(column)
	return column


func add_choice(row: Container, text: String, action: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(action)
	row.add_child(b)
	return b


func add_choice_control(control: Control) -> void:
	_choices.add_child(control)


## Qualquer tecla vira a página ou termina a máquina de escrever; as teclas 1 a 4
## acionam os verbos.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _advance_text():
		get_viewport().set_input_as_handled()
		return
	var index: int = event.keycode - KEY_1
	if index >= 0 and index < VERB_COUNT and not _verbs[index].disabled:
		verb_pressed.emit(index)
		get_viewport().set_input_as_handled()
