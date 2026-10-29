class_name GameFrame
extends Control
## Moldura comum de todas as telas do jogo (ver o guia de estilo), na tela de 640 × 360:
## barra de menu, barra do caso, cabeçalho da cidade, área de cena, painel de texto com
## escolhas, ficha e os quatro verbos. Não conhece as regras: main.gd preenche e reage.

signal verb_pressed(index: int)
signal menu_pressed(id: String)

const MENU_IDS := ["new_career", "rank", "language", "about"]
const VERB_COUNT := 4
## Caracteres por segundo da máquina de escrever.
const TYPE_SPEED := 60.0

var _menu: Dictionary = {}
var _case_label: Label
var _deadline_label: Label
var _deadline_bar: ProgressBar
var _header: Label
var _scene_bg: ColorRect
var _scene_title: Label
var _scene_caption: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _notes: Label
var _verbs: Array[Button] = []
var _verb_labels: Array[Label] = []
var _key_labels: Array[Label] = []
var _typed := 0.0


func _ready() -> void:
	theme = PfTheme.build()
	_build()


func _build() -> void:
	var menu_bar := ColorRect.new()
	menu_bar.color = Palette.TEXT
	_place(menu_bar, 0, 0, 640, 16)
	var menu_row := HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 0)
	_place(menu_row, 4, 0, 400, 16)
	for id in MENU_IDS:
		var b := Button.new()
		b.theme_type_variation = "MenuItem"
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): menu_pressed.emit(id))
		menu_row.add_child(b)
		_menu[id] = b

	var case_bar := PanelContainer.new()
	_place(case_bar, 8, 20, 624, 20)
	var case_row := HBoxContainer.new()
	case_row.add_theme_constant_override("separation", 8)
	case_bar.add_child(case_row)
	_case_label = Label.new()
	_case_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_case_label.clip_text = true
	case_row.add_child(_case_label)
	_deadline_label = Label.new()
	case_row.add_child(_deadline_label)
	_deadline_bar = ProgressBar.new()
	_deadline_bar.custom_minimum_size = Vector2(120, 6)
	_deadline_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_deadline_bar.show_percentage = false
	_deadline_bar.max_value = 1.0
	_deadline_bar.step = 0.0
	case_row.add_child(_deadline_bar)

	var header := PanelContainer.new()
	_place(header, 8, 44, 296, 24)
	_header = Label.new()
	_header.add_theme_font_override("font", PfTheme.text_font())
	_header.add_theme_font_size_override("font_size", PfTheme.TEXT_SIZE)
	_header.add_theme_color_override("font_color", Palette.HIGHLIGHT)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.clip_text = true
	header.add_child(_header)

	# Área de cena: até a arte existir, um placeholder do tamanho certo (296 × 216 por dentro).
	var scene := PanelContainer.new()
	_place(scene, 8, 72, 296, 220)
	scene.add_theme_stylebox_override("panel", PfTheme.box(Palette.INK, Palette.PANEL_BORDER, 1))
	_scene_bg = ColorRect.new()
	scene.add_child(_scene_bg)
	var scene_labels := VBoxContainer.new()
	scene_labels.alignment = BoxContainer.ALIGNMENT_CENTER
	scene.add_child(scene_labels)
	_scene_title = Label.new()
	_scene_title.add_theme_font_override("font", PfTheme.text_font())
	_scene_title.add_theme_font_size_override("font_size", PfTheme.TEXT_SIZE)
	_scene_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scene_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_labels.add_child(_scene_title)
	_scene_caption = Label.new()
	_scene_caption.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_scene_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scene_labels.add_child(_scene_caption)

	var text_panel := PanelContainer.new()
	_place(text_panel, 308, 44, 324, 248)
	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 4)
	text_panel.add_child(text_box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_following = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.gui_input.connect(_on_text_input)
	text_box.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 3)
	text_box.add_child(_choices)

	var notes := PanelContainer.new()
	_place(notes, 8, 296, 296, 56)
	_notes = Label.new()
	_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notes.max_lines_visible = 3
	notes.add_child(_notes)

	for i in VERB_COUNT:
		var b := Button.new()
		_place(b, 308 + 82 * i, 296, 78, 56)
		b.pressed.connect(func(): verb_pressed.emit(i))
		var labels := VBoxContainer.new()
		labels.set_anchors_preset(Control.PRESET_FULL_RECT)
		labels.alignment = BoxContainer.ALIGNMENT_CENTER
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(labels)
		var name := Label.new()
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		labels.add_child(name)
		var key := Label.new()
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_color_override("font_color", Palette.TEXT_DIM)
		key.text = str(i + 1)
		labels.add_child(key)
		_verbs.append(b)
		_verb_labels.append(name)
		_key_labels.append(key)


func _place(node: Control, x: int, y: int, w: int, h: int) -> void:
	node.position = Vector2(x, y)
	node.size = Vector2(w, h)
	add_child(node)


func set_menu_texts(texts: Dictionary) -> void:
	for id in texts:
		_menu[id].text = texts[id]


func set_verbs(names: Array, key_format: String) -> void:
	for i in VERB_COUNT:
		_verb_labels[i].text = names[i]
		_key_labels[i].text = key_format % (i + 1)


func set_verbs_enabled(enabled: bool) -> void:
	for b in _verbs:
		b.disabled = not enabled


## `remaining` vai de 1 (prazo inteiro) a 0 (prazo acabou).
func set_case(case_text: String, deadline_text: String, remaining: float) -> void:
	_case_label.text = case_text
	_deadline_label.text = deadline_text
	_deadline_bar.value = clampf(remaining, 0.0, 1.0)
	_deadline_bar.visible = deadline_text != ""
	var fill := PfTheme.box(Palette.ALERT if remaining < 0.25 else Palette.HIGHLIGHT,
		Palette.ALERT if remaining < 0.25 else Palette.HIGHLIGHT, 0)
	_deadline_bar.add_theme_stylebox_override("fill", fill)


func set_header(text: String) -> void:
	_header.text = text


func show_scene(title: String, caption: String, tint: Color) -> void:
	_scene_bg.color = tint
	_scene_title.text = title
	_scene_caption.text = caption


func set_notes(text: String) -> void:
	_notes.text = text


func clear_text() -> void:
	_text.clear()
	_text.visible_characters = 0
	_typed = 0.0


## Acrescenta texto ao painel; ele aparece em máquina de escrever.
func say(text: String) -> void:
	if _text.visible_characters < 0:
		_typed = _text.get_total_character_count()
		_text.visible_characters = int(_typed)
	_text.append_text(text + "\n")


func is_typing() -> bool:
	return _text.visible_characters >= 0


func finish_typing() -> void:
	_text.visible_characters = -1


func _process(delta: float) -> void:
	if not is_typing():
		return
	_typed += TYPE_SPEED * delta
	if _typed >= _text.get_total_character_count():
		finish_typing()
	else:
		_text.visible_characters = int(_typed)


func _on_text_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and is_typing():
		finish_typing()


func clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


## Linha de botões (ou outros controles) no pé do painel de texto.
func add_choice_row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 3)
	row.add_theme_constant_override("v_separation", 3)
	_choices.add_child(row)
	return row


func add_choice(row: Container, text: String, action: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(action)
	row.add_child(b)
	return b


func add_choice_control(control: Control) -> void:
	_choices.add_child(control)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if is_typing():
		finish_typing()
		get_viewport().set_input_as_handled()
		return
	var index: int = event.keycode - KEY_1
	if index >= 0 and index < VERB_COUNT and not _verbs[index].disabled:
		verb_pressed.emit(index)
		get_viewport().set_input_as_handled()
