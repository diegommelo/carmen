extends Control
## Tela provisória, só texto e botões, para jogar o núcleo com o pacote de conteúdo.
## Os textos da tela vêm de i18n/ui.csv (tr) e os do jogo vêm do pacote de conteúdo.

const PACK_DIR := "res://content/parody"
## Idiomas oferecidos no seletor, na ordem em que aparecem.
const LANGUAGES := {"pt_BR": "Português (Brasil)", "en": "English"}

var pack: ContentPack
var session: CaseSession
var detective: Dictionary

var _status: Label
var _language: OptionButton
var _log: RichTextLabel
var _actions: HFlowContainer
var _marks: Dictionary = {}


func _ready() -> void:
	pack = ContentPack.load_dir(PACK_DIR, OS.get_locale())
	TranslationServer.set_locale(pack.locale)
	_build_layout()
	detective = Career.load_saved()
	if detective.is_empty():
		detective = Career.fresh(tr("DEFAULT_AGENT"))
	elif detective.cases > 0:
		_say(tr("CAREER_RESUMED") % [detective.name, detective.cases])
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
	var top := HBoxContainer.new()
	box.add_child(top)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status)
	_language = OptionButton.new()
	for code in LANGUAGES:
		_language.add_item(LANGUAGES[code])
		_language.set_item_metadata(_language.item_count - 1, code)
		if code == pack.locale:
			_language.selected = _language.item_count - 1
	_language.item_selected.connect(_on_language_selected)
	top.add_child(_language)
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.bbcode_enabled = true
	box.add_child(_log)
	_actions = HFlowContainer.new()
	box.add_child(_actions)


func _on_language_selected(index: int) -> void:
	var code: String = _language.get_item_metadata(index)
	TranslationServer.set_locale(code)
	session.set_language(code)
	# O que já está no registro fica como estava; a cidade é mostrada de novo no idioma novo.
	if session.outcome == CaseSession.ONGOING:
		_show_city()
	else:
		_show_main_actions()


func _new_case() -> void:
	if detective.name == "":
		detective.name = tr("DEFAULT_AGENT")
	session = CaseSession.new(pack, randi())
	session.start(detective)
	_marks.clear()
	var deadline: Dictionary = session.difficulty.deadline
	_say(tr("ALERT_THEFT") % [session.treasure(), pack.city(session.crime_city).name])
	_say(tr("SUSPECT_SEEN") % _sex_name().to_lower())
	_say(tr("DEADLINE") % [_day_name(deadline.day), tr("HOUR_FMT") % deadline.hour])
	_show_city()


func _on_new_case() -> void:
	_log.clear()
	_new_case()


func _on_new_career() -> void:
	Career.erase()
	detective = Career.fresh(tr("DEFAULT_AGENT"))
	_on_new_case()


func _sex_name() -> String:
	var sex_trait: String = pack.rules.sex_trait
	for t in pack.traits:
		if t.id == sex_trait:
			return t.values[session.suspect.traits[sex_trait]]
	return ""


func _day_name(day: int) -> String:
	return tr("DAY_%d" % mini(day, 6))


func _say(text: String) -> void:
	_log.append_text(text + "\n")


func _show_city() -> void:
	_say("\n[b]%s[/b]  %s" % [pack.city(session.current_city).name, session.arrival_text()])
	_show_main_actions()


func _refresh_status() -> void:
	var c := session.clock
	var warrant := tr("WARRANT_NONE")
	if session.warrant_id != "":
		warrant = pack.suspect(session.warrant_id).name
	_status.text = tr("STATUS") % [detective.name, pack.ranks[detective.rank].name,
		_day_name(c.day), tr("HOUR_FMT") % c.hour, warrant]


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
	_button(tr("BTN_TRAVEL"), _show_destinations)
	_button(tr("BTN_COMPUTER"), _show_computer)
	_button(tr("BTN_DOSSIERS"), _show_dossiers)


func _on_investigate(slot: int) -> void:
	if session.outcome != CaseSession.ONGOING:
		return
	var r := session.investigate(slot)
	var type := pack.location_type(session.places[slot].type)
	match r.event:
		"capture":
			_say("\n" + tr("FOUND_HIDEOUT"))
		"henchman":
			_say("[i]%s[/i]" % pack.texts.henchman)
		"danger":
			_say("[i]%s[/i]" % session.rng.pick(pack.texts.danger))
	if r.text != "":
		_say("%s (%s): %s" % [r.witness, type.name, r.text])
	if r.slept:
		_say(tr("SLEEPING"))
	_show_main_actions()


func _show_destinations() -> void:
	_clear_actions()
	for id in session.destinations():
		_button(tr("TRAVEL_OPTION") % [pack.city(id).name, session.travel_hours(id)], _on_travel.bind(id))
	_button(tr("BTN_BACK"), _show_main_actions)


func _on_travel(city_id: String) -> void:
	if session.outcome != CaseSession.ONGOING:
		return
	var r := session.travel(city_id)
	if r.slept:
		_say(tr("SLEEPING"))
	if session.outcome == CaseSession.ONGOING:
		_show_city()
		if r.shortcut:
			_say(tr("SHORTCUT"))
	else:
		_show_main_actions()


func _show_computer() -> void:
	_clear_actions()
	for t in pack.warrant_traits():
		var opt := OptionButton.new()
		opt.add_item(tr("TRAIT_UNKNOWN") % t.name)
		var values: Array = t.values.keys()
		for v in values:
			opt.add_item(t.values[v])
		opt.selected = values.find(_marks[t.id]) + 1 if _marks.has(t.id) else 0
		opt.item_selected.connect(_on_mark.bind(t.id, values))
		_actions.add_child(opt)
	_button(tr("BTN_ISSUE_WARRANT"), _on_compute)
	_button(tr("BTN_BACK"), _show_main_actions)


func _on_mark(index: int, trait_id: String, values: Array) -> void:
	if index == 0:
		_marks.erase(trait_id)
	else:
		_marks[trait_id] = values[index - 1]


func _on_compute() -> void:
	var matches := session.compute_warrant(_marks)
	if matches.is_empty():
		_say(tr("NO_MATCH"))
	elif matches.size() == 1:
		_say(tr("WARRANT_ISSUED") % matches[0].name)
	else:
		_say(tr("SUSPECTS_LIST") % ", ".join(matches.map(func(s): return s.name)))
	_show_main_actions()


func _show_dossiers() -> void:
	_clear_actions()
	for s in pack.suspects:
		_button(s.name, _on_dossier.bind(s.id))
	_button(tr("BTN_BACK"), _show_main_actions)


func _on_dossier(id: String) -> void:
	var d := pack.dossier(id)
	_say("\n[b]%s[/b]" % tr("DOSSIER_TITLE"))
	_say("%s: %s" % [tr("DOSSIER_NAME"), d.full_name])
	if d.occupation != "":
		_say("%s: %s" % [tr("DOSSIER_OCCUPATION"), d.occupation])
	for row in d.traits:
		_say("%s: %s" % [row.name, row.value])
	if not d.notes.is_empty():
		_say("%s: %s" % [tr("DOSSIER_NOTES"), " ".join(d.notes)])


func _show_outcome() -> void:
	var name: String = session.suspect.name
	match session.outcome:
		CaseSession.ARRESTED:
			_say(tr("OUTCOME_ARRESTED") % [name, session.treasure()])
			if session.promoted:
				_say(tr("PROMOTED") % pack.ranks[detective.rank].name)
		CaseSession.NO_WARRANT:
			_say(tr("OUTCOME_NO_WARRANT") % name)
		CaseSession.WRONG_WARRANT:
			_say(tr("OUTCOME_WRONG_WARRANT") % name)
		CaseSession.ESCAPED_TIME:
			_say(tr("OUTCOME_TIME") % name)
	Career.save(detective)
	if session.boss_arrested:
		_say(tr("CAREER_DONE"))
	else:
		_button(tr("BTN_NEW_CASE"), _on_new_case)
	_button(tr("BTN_NEW_CAREER"), _on_new_career)
