extends Control
## Tela provisória, só texto e botões, para jogar o núcleo com o pacote de conteúdo.

const PACK_DIR := "res://content/placeholder"
const DAYS := ["segunda", "terça", "quarta", "quinta", "sexta", "sábado", "domingo"]

var pack: ContentPack
var session: CaseSession
var detective := {"name": "Agente", "cases": 0, "rank": 0}

var _status: Label
var _log: RichTextLabel
var _actions: HFlowContainer
var _marks: Dictionary = {}


func _ready() -> void:
	pack = ContentPack.load_dir(PACK_DIR)
	_build_layout()
	_new_case()


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.bbcode_enabled = true
	box.add_child(_log)
	_actions = HFlowContainer.new()
	box.add_child(_actions)


func _new_case() -> void:
	session = CaseSession.new(pack, randi())
	session.start(detective)
	_marks.clear()
	_log.clear()
	var crime := pack.city(session.crime_city)
	var sex_name: String = pack.traits[0].values[session.suspect.traits[pack.rules.sex_trait]]
	_say("[b]Alerta![/b] Roubaram %s em %s." % [session.treasure, crime.name])
	_say("Suspeito do sexo %s visto no local do crime." % sex_name.to_lower())
	_say("Prazo: domingo, 17h.")
	_show_city()


func _say(text: String) -> void:
	_log.append_text(text + "\n")


func _show_city() -> void:
	_say("\n[b]%s[/b]  %s" % [pack.city(session.current_city).name, session.arrival_text])
	_show_main_actions()


func _refresh_status() -> void:
	var c := session.clock
	var warrant := "nenhum"
	if session.warrant_id != "":
		for s in pack.suspects:
			if s.id == session.warrant_id:
				warrant = s.name
	_status.text = "%s (%s) · %s, %dh · Mandado: %s" % [
		detective.name, pack.ranks[detective.rank].name, DAYS[mini(c.day, 6)], c.hour, warrant]


func _clear_actions() -> void:
	for child in _actions.get_children():
		child.queue_free()


func _button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	_actions.add_child(b)


func _show_main_actions() -> void:
	_refresh_status()
	_clear_actions()
	if session.outcome != CaseSession.ONGOING:
		_show_outcome()
		return
	for i in session.places.size():
		var type := pack.location_type(session.places[i].type)
		_button(type.name, _on_investigate.bind(i))
	_button("Viajar", _show_destinations)
	_button("Computador", _show_computer)


func _on_investigate(slot: int) -> void:
	if session.outcome != CaseSession.ONGOING:
		return
	var r := session.investigate(slot)
	var type := pack.location_type(session.places[slot].type)
	match r.event:
		"capture":
			_say("\n[b]Você encontrou o esconderijo![/b]")
		"henchman":
			_say("[i]%s[/i]" % pack.texts.henchman)
		"danger":
			_say("[i]%s[/i]" % session.rng.pick(pack.texts.danger))
	if r.text != "":
		_say("%s (%s): %s" % [r.witness, type.name, r.text])
	if r.slept:
		_say("[i]Dormindo...[/i]")
	_show_main_actions()


func _show_destinations() -> void:
	_clear_actions()
	for id in session.destinations():
		_button("%s (%dh)" % [pack.city(id).name, session.travel_hours(id)], _on_travel.bind(id))
	_button("Voltar", _show_main_actions)


func _on_travel(city_id: String) -> void:
	if session.outcome != CaseSession.ONGOING:
		return
	var r := session.travel(city_id)
	if r.slept:
		_say("[i]Dormindo...[/i]")
	if session.outcome == CaseSession.ONGOING:
		_show_city()
	else:
		_show_main_actions()


func _show_computer() -> void:
	_clear_actions()
	for t in pack.warrant_traits():
		var opt := OptionButton.new()
		opt.add_item("%s: ?" % t.name)
		var values: Array = t.values.keys()
		for v in values:
			opt.add_item(t.values[v])
		opt.selected = values.find(_marks[t.id]) + 1 if _marks.has(t.id) else 0
		opt.item_selected.connect(_on_mark.bind(t.id, values))
		_actions.add_child(opt)
	_button("Emitir mandado", _on_compute)
	_button("Voltar", _show_main_actions)


func _on_mark(index: int, trait_id: String, values: Array) -> void:
	if index == 0:
		_marks.erase(trait_id)
	else:
		_marks[trait_id] = values[index - 1]


func _on_compute() -> void:
	var matches := session.compute_warrant(_marks)
	if matches.is_empty():
		_say("Nenhum suspeito tem esses traços.")
	elif matches.size() == 1:
		_say("[b]Mandado emitido contra %s.[/b]" % matches[0].name)
	else:
		_say("Suspeitos: %s." % ", ".join(matches.map(func(s): return s.name)))
	_show_main_actions()


func _show_outcome() -> void:
	match session.outcome:
		CaseSession.ARRESTED:
			_say("[b]%s foi preso(a) e %s voltou para casa![/b]" % [session.suspect.name, session.treasure])
			if session.promoted:
				_say("Promoção! Sua nova patente: %s." % pack.ranks[detective.rank].name)
		CaseSession.NO_WARRANT:
			_say("Você alcançou %s, mas sem mandado não dá para prender. Fugiu!" % session.suspect.name)
		CaseSession.WRONG_WARRANT:
			_say("O mandado era contra outra pessoa. %s escapou." % session.suspect.name)
		CaseSession.ESCAPED_TIME:
			_say("O prazo acabou. %s escapou." % session.suspect.name)
	_button("Novo caso", _new_case)
