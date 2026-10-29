class_name WarrantScreen
extends VBoxContainer
## Terminal de mandados da PF, em tela cheia: um seletor por traço e, embaixo, quantos
## suspeitos ainda batem com o que foi marcado. Quem emite o mandado é main.gd.

signal marks_changed(marks: Dictionary)
signal issue_pressed

var _marks: Dictionary
var _count: Label


## `traits` são os traços do mandado, como em ContentPack.warrant_traits().
func setup(title: String, traits: Array, marks: Dictionary, unknown_text: String,
		issue_text: String) -> void:
	_marks = marks.duplicate()
	add_theme_constant_override("separation", 6)
	add_child(GameFrame.heading(title))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	for t in traits:
		_add_trait_row(grid, t, unknown_text)
	_count = Label.new()
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_count.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_count)
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(_button(issue_text, issue_pressed))


func _add_trait_row(grid: GridContainer, t: Dictionary, unknown_text: String) -> void:
	var name := Label.new()
	name.text = t.name
	name.custom_minimum_size.x = 120
	grid.add_child(name)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_item(unknown_text)
	var values: Array = t.values.keys()
	for v in values:
		opt.add_item(t.values[v])
	opt.selected = values.find(_marks[t.id]) + 1 if _marks.has(t.id) else 0
	opt.item_selected.connect(_on_selected.bind(t.id, values))
	grid.add_child(opt)


func _button(text: String, pressed: Signal) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(pressed.emit)
	return b


func set_count_text(text: String) -> void:
	_count.text = text


func _on_selected(index: int, trait_id: String, values: Array) -> void:
	if index == 0:
		_marks.erase(trait_id)
	else:
		_marks[trait_id] = values[index - 1]
	marks_changed.emit(_marks.duplicate())
