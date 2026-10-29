class_name AgentsScreen
extends VBoxContainer
## Tela PF: os agentes do fichário à esquerda, cada um com o botão de apagar, e a ficha
## do escolhido à direita. Os textos e o que fazer com cada clique vêm de main.gd.

signal picked(index: int)
signal delete_pressed(index: int)
signal back_pressed

const LIST_WIDTH := 300

var _sheet: RichTextLabel


## `rows`: um texto por agente, na ordem do fichário. `hint` ocupa a ficha até alguém ser
## escolhido; `legend` vazia fica escondida.
func setup(title: String, rows: Array, hint: String, legend: String, delete_tip: String, back_text: String) -> void:
	add_theme_constant_override("separation", 8)
	add_child(GameFrame.heading(title))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(body)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.custom_minimum_size.x = LIST_WIDTH
	body.add_child(list)
	for i in rows.size():
		list.add_child(_row(i, rows[i], delete_tip))
	if legend != "":
		var label := Label.new()
		label.text = legend
		list.add_child(label)
	_sheet = RichTextLabel.new()
	_sheet.bbcode_enabled = true
	_sheet.size_flags_horizontal = SIZE_EXPAND_FILL
	_sheet.text = hint
	body.add_child(_sheet)
	var bar := HBoxContainer.new()
	add_child(bar)
	GameFrame.add_spacer(bar)
	bar.add_child(_button(back_text, back_pressed.emit))


func show_sheet(text: String) -> void:
	_sheet.text = text


func _row(i: int, text: String, delete_tip: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var pick := _button(text, func(): picked.emit(i))
	pick.size_flags_horizontal = SIZE_EXPAND_FILL
	pick.clip_text = true
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(pick)
	var remove := _button("X", func(): delete_pressed.emit(i))
	remove.tooltip_text = delete_tip
	row.add_child(remove)
	return row


static func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	return b
