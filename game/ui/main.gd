extends GameFrame
## O jogo em si: liga o CaseSession à moldura comum (GameFrame).
## Textos da tela vêm de i18n/ui.csv (tr); os do jogo, do pacote de conteúdo.

const PACK_DIR := "res://content/parody"
const LANGUAGES := {"pt_BR": "Português (Brasil)", "en": "English"}
enum Verb { INVESTIGATE, TRAVEL, WARRANT, DOSSIER }

var pack: ContentPack
var session: CaseSession
var detective: Dictionary

var _marks: Dictionary = {}
## Cidades visitadas no caso, da cena do crime até a atual, para desenhar no mapa.
var _route: Array = []
var _dossier_index := 0
var _confirm: ConfirmationDialog
var _info: AcceptDialog
var _languages: PopupMenu


func _ready() -> void:
	super()
	RenderingServer.set_default_clear_color(Palette.INK)
	pack = ContentPack.load_dir(PACK_DIR, OS.get_locale())
	TranslationServer.set_locale(pack.locale)
	_build_dialogs()
	verb_pressed.connect(_on_verb)
	menu_pressed.connect(_on_menu)
	_refresh_labels()
	detective = Career.load_saved()
	if detective.is_empty():
		_ask_name()
		return
	_new_case()
	if detective.cases > 0:
		say(tr("CAREER_RESUMED") % [detective.name, detective.cases])


func _build_dialogs() -> void:
	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(_on_new_career)
	add_child(_confirm)
	_info = AcceptDialog.new()
	add_child(_info)
	_languages = PopupMenu.new()
	for code in LANGUAGES:
		_languages.add_item(LANGUAGES[code])
		_languages.set_item_metadata(_languages.item_count - 1, code)
	_languages.index_pressed.connect(_on_language_selected)
	add_child(_languages)


func _refresh_labels() -> void:
	set_menu_texts({
		"new_career": tr("BTN_NEW_CAREER"),
		"rank": tr("MENU_RANK"),
		"language": tr("MENU_LANGUAGE"),
		"about": tr("MENU_ABOUT"),
	})
	set_verbs([tr("BTN_INVESTIGATE"), tr("BTN_TRAVEL"), tr("BTN_WARRANT"), tr("BTN_DOSSIERS")],
		tr("KEY_HINT"))


func _on_menu(id: String) -> void:
	match id:
		"new_career":
			_confirm.dialog_text = tr("CONFIRM_NEW_CAREER")
			_confirm.popup_centered()
		"rank":
			_show_info(tr("MENU_RANK"), _rank_text())
		"language":
			_languages.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i.ZERO))
		"about":
			_show_info(tr("MENU_ABOUT"), tr("ABOUT_TEXT"))


func _show_info(title: String, text: String) -> void:
	_info.title = title
	_info.dialog_text = text
	_info.popup_centered()


func _rank_text() -> String:
	if detective.is_empty():
		return tr("RANK_NO_CAREER")
	var text: String = tr("RANK_INFO") % [detective.name, pack.ranks[detective.rank].name, detective.cases]
	var left := pack.cases_to_next_rank(detective.cases)
	if left > 0:
		var next_rank: String = pack.ranks[detective.rank + 1].name
		text += "\n" + (tr("NEXT_RANK_ONE") % next_rank if left == 1 else tr("NEXT_RANK") % [left, next_rank])
	return text


func _on_language_selected(index: int) -> void:
	var code: String = _languages.get_item_metadata(index)
	TranslationServer.set_locale(code)
	_refresh_labels()
	if session == null:
		_ask_name()
		return
	session.set_language(code)
	# O que já está no painel fica como estava; a cidade é mostrada de novo no idioma novo.
	if session.outcome == CaseSession.ONGOING:
		_show_city(false)
	else:
		_show_main_actions()


func _on_verb(index: int) -> void:
	if session == null or session.outcome != CaseSession.ONGOING:
		return
	hide_overlay()
	match index:
		Verb.INVESTIGATE:
			_show_places()
		Verb.TRAVEL:
			_show_destinations()
		Verb.WARRANT:
			_show_computer()
		Verb.DOSSIER:
			_show_dossier(_dossier_index)


func _ask_name() -> void:
	session = null
	set_case("", "", "", 1.0)
	set_header(tr("HQ_TITLE"))
	show_scene(tr("HQ_TITLE"), tr("SCENE_ART") % "hq", Palette.PANEL)
	set_notes("")
	set_verbs_enabled(false)
	clear_text()
	say(tr("ASK_NAME"))
	clear_choices()
	var row := add_choice_row()
	var field := LineEdit.new()
	field.placeholder_text = tr("DEFAULT_AGENT")
	field.custom_minimum_size.x = 220
	field.text_submitted.connect(func(_text): _on_name_entered(field))
	row.add_child(field)
	add_choice(row, tr("BTN_START"), _on_name_entered.bind(field))
	field.grab_focus.call_deferred()


func _on_name_entered(field: LineEdit) -> void:
	var agent_name := field.text.strip_edges()
	detective = Career.fresh(agent_name if agent_name != "" else tr("DEFAULT_AGENT"))
	Career.save(detective)
	_new_case()


func _new_case() -> void:
	session = CaseSession.new(pack, randi())
	session.start(detective)
	_marks.clear()
	_route = [session.crime_city]
	hide_overlay()
	clear_text()
	var deadline: Dictionary = session.difficulty.deadline
	say(tr("ALERT_THEFT") % [session.treasure(), pack.city(session.crime_city).name])
	say(tr("SUSPECT_SEEN") % _sex_name().to_lower())
	say(tr("DEADLINE") % [_day_name(deadline.day), tr("HOUR_FMT") % deadline.hour])
	_show_city(false)


func _on_new_career() -> void:
	Career.erase()
	detective = {}
	_ask_name()


func _sex_name() -> String:
	var sex_trait: String = pack.rules.sex_trait
	for t in pack.traits:
		if t.id == sex_trait:
			return t.values[session.suspect.traits[sex_trait]]
	return ""


func _day_name(day: int) -> String:
	return tr("DAY_%d" % mini(day, 6))


func _when(day: int, hour: int) -> String:
	return "%s, %s" % [_day_name(day), tr("HOUR_FMT") % hour]


## Mostra a cidade atual. Com `fresh`, o painel de texto é limpo antes.
func _show_city(fresh: bool = true) -> void:
	var city := pack.city(session.current_city)
	if fresh:
		clear_text()
	show_scene(city.name, tr("SCENE_ART") % ("cities/" + session.current_city), _tint(session.current_city))
	say("\n" + _highlight(city.name))
	say(session.arrival_text())
	_show_main_actions()


func _highlight(text: String) -> String:
	return "[color=#%s]%s[/color]" % [Palette.HIGHLIGHT.to_html(false), text]


## Cor provisória da cena enquanto não há arte: escura e sempre a mesma para cada id.
func _tint(id: String) -> Color:
	return Color.from_hsv(float(hash(id) % 360) / 360.0, 0.35, 0.3)


func _refresh_status() -> void:
	var c := session.clock
	set_header("%s · %s" % [pack.city(session.current_city).name, _when(c.day, c.hour)])
	var budget := tr("STATUS_BUDGET") % _money(session.budget) if session.budget >= 0 else ""
	var deadline: Dictionary = session.difficulty.deadline
	set_case(tr("CASE_BAR") % session.treasure(), budget,
		tr("DEADLINE_SHORT") % _when(deadline.day, deadline.hour), _time_left())
	var warrant := tr("WARRANT_NONE")
	if session.warrant_id != "":
		warrant = pack.suspect(session.warrant_id).name
	var notes: String = tr("NOTES_WARRANT") % warrant
	var marked := []
	for t in pack.warrant_traits():
		if _marks.has(t.id):
			marked.append("%s: %s" % [t.name, t.values[_marks[t.id]]])
	notes += "\n" + (tr("NOTES_TRAITS") % ", ".join(marked) if not marked.is_empty() else tr("NOTES_NONE"))
	set_notes(notes)


## Fração do prazo que ainda resta: 1 no início do caso, 0 no fim.
func _time_left() -> float:
	var rules: Dictionary = pack.rules.clock
	var deadline: Dictionary = session.difficulty.deadline
	var start := int(rules.start_day) * 24 + int(rules.start_hour)
	var end := int(deadline.day) * 24 + int(deadline.hour)
	var now := session.clock.day * 24 + session.clock.hour
	return float(end - now) / float(maxi(end - start, 1))


func _money(amount: int) -> String:
	return tr("MONEY_FMT") % amount


func _show_main_actions() -> void:
	_refresh_status()
	clear_choices()
	set_verbs_enabled(session.outcome == CaseSession.ONGOING)
	if session.outcome != CaseSession.ONGOING:
		_show_outcome()


## Investigar: os lugares da cidade viram uma lista no painel de texto.
func _show_places() -> void:
	clear_text()
	say(tr("WHERE_TO"))
	clear_choices()
	var column := add_choice_column()
	for i in session.places.size():
		add_choice(column, pack.location_type(session.places[i].type).name, _on_investigate.bind(i))
	add_choice(column, tr("BTN_BACK"), _show_city)


## A testemunha aparece na cena e a fala dela ocupa o painel de texto.
func _on_investigate(slot: int) -> void:
	if session.outcome != CaseSession.ONGOING:
		return
	var r := session.investigate(slot)
	var type_id: String = session.places[slot].type
	var type := pack.location_type(type_id)
	show_scene(r.witness, tr("SCENE_ART") % ("witnesses/" + type_id), _tint(type_id))
	clear_text()
	match r.event:
		"capture":
			say(tr("FOUND_HIDEOUT"))
		"henchman":
			say("[i]%s[/i]" % pack.texts.henchman)
		"danger":
			say("[i]%s[/i]" % session.rng.pick(pack.texts.danger))
	if r.text != "":
		say(_highlight("%s (%s):" % [r.witness, type.name]))
		say(r.text)
	if r.slept:
		say(tr("SLEEPING"))
	_show_main_actions()


## Viajar: mapa em tela cheia, com um botão por destino; passar o mouse destaca a rota.
func _show_destinations() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = tr("TRAVEL_TITLE") % pack.city(session.current_city).name
	title.add_theme_color_override("font_color", Palette.HIGHLIGHT)
	box.add_child(title)
	var map := TravelMap.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(map)
	var points := {}
	var names := {}
	for id in pack.city_ids():
		points[id] = Vector2(pack.city(id).map.x, pack.city(id).map.y)
		names[id] = pack.city(id).name
	map.setup(points, names, session.current_city, session.destinations(), _route)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	box.add_child(row)
	for id in session.destinations():
		var label: String = tr("TRAVEL_OPTION") % [pack.city(id).name, session.travel_hours(id)]
		if session.budget >= 0:
			label += " · " + _money(session.ticket_price(id))
		var b := add_choice(row, label, _fly.bind(map, row, id), session.can_afford(id))
		b.mouse_entered.connect(map.highlight.bind(id))
		b.focus_entered.connect(map.highlight.bind(id))
	add_choice(row, tr("BTN_BACK"), hide_overlay)
	show_overlay(box)


func _fly(map: TravelMap, row: Container, city_id: String) -> void:
	for b in row.get_children():
		b.disabled = true
	map.fly(city_id)
	await map.flight_finished
	hide_overlay()
	_on_travel(city_id)


func _on_travel(city_id: String) -> void:
	if session.outcome != CaseSession.ONGOING:
		return
	var r := session.travel(city_id)
	_route.append(city_id)
	if session.outcome == CaseSession.ONGOING:
		_show_city()
		if r.slept:
			say(tr("SLEEPING"))
		if r.shortcut:
			say(tr("SHORTCUT"))
	else:
		clear_text()
		if r.slept:
			say(tr("SLEEPING"))
		_show_main_actions()


## Mandado: terminal em tela cheia, com a contagem de compatíveis mudando a cada traço.
func _show_computer() -> void:
	var screen := WarrantScreen.new()
	screen.setup(tr("WARRANT_TITLE"), pack.warrant_traits(), _marks, tr("TRAIT_UNKNOWN"),
		tr("BTN_ISSUE_WARRANT"), tr("BTN_BACK"))
	screen.marks_changed.connect(_on_marks_changed.bind(screen))
	screen.issue_pressed.connect(_on_compute)
	screen.back_pressed.connect(hide_overlay)
	screen.set_count_text(_count_text())
	show_overlay(screen)


func _on_marks_changed(marks: Dictionary, screen: WarrantScreen) -> void:
	_marks = marks
	screen.set_count_text(_count_text())
	_refresh_status()


## Mesmo filtro de CaseSession.compute_warrant, sem emitir nem cancelar mandado.
func _compatible(marks: Dictionary) -> Array:
	return pack.suspects.filter(func(s):
		for k in marks:
			if s.traits[k] != marks[k]:
				return false
		return true)


func _count_text() -> String:
	var matches := _compatible(_marks)
	return tr("WARRANT_COUNT") % [matches.size(), ", ".join(matches.map(func(s): return s.name))]


func _on_compute() -> void:
	hide_overlay()
	var matches := session.compute_warrant(_marks)
	clear_text()
	if matches.is_empty():
		say(tr("NO_MATCH"))
	elif matches.size() == 1:
		say(tr("WARRANT_ISSUED") % matches[0].name)
	else:
		say(tr("SUSPECTS_LIST") % ", ".join(matches.map(func(s): return s.name)))
	_show_main_actions()


## Dossiê: um suspeito por vez, com setas para folhear. Quem não bate com os traços
## marcados aparece carimbado como descartado.
func _show_dossier(index: int) -> void:
	_dossier_index = posmod(index, pack.suspects.size())
	var id: String = pack.suspects[_dossier_index].id
	var d := pack.dossier(id)
	var ruled_out := not _compatible(_marks).any(func(s): return s.id == id)
	show_scene(d.full_name, tr("SCENE_ART") % ("suspects/" + id), _tint(id),
		tr("STAMP_RULED_OUT") if ruled_out else "")
	clear_text()
	say(_highlight("%s %d/%d" % [tr("DOSSIER_TITLE"), _dossier_index + 1, pack.suspects.size()]))
	say("%s: %s" % [tr("DOSSIER_NAME"), d.full_name])
	if d.occupation != "":
		say("%s: %s" % [tr("DOSSIER_OCCUPATION"), d.occupation])
	for row in d.traits:
		say("%s: %s" % [row.name, row.value])
	if not d.notes.is_empty():
		say("%s: %s" % [tr("DOSSIER_NOTES"), " ".join(d.notes)])
	clear_choices()
	var row := add_choice_row()
	add_choice(row, "<", _show_dossier.bind(_dossier_index - 1))
	add_choice(row, ">", _show_dossier.bind(_dossier_index + 1))
	add_choice(row, tr("BTN_BACK"), _show_city)


## Desfecho: a cena mostra a prisão ou a fuga e o texto conta o resultado.
func _show_outcome() -> void:
	var name: String = session.suspect.name
	var arrested := session.outcome == CaseSession.ARRESTED
	show_scene(tr("SCENE_ARRESTED") if arrested else tr("SCENE_ESCAPED"),
		tr("SCENE_ART") % ("outcomes/" + ("arrest" if arrested else "escape")),
		Palette.OK.darkened(0.6) if arrested else Palette.ALERT.darkened(0.6))
	match session.outcome:
		CaseSession.ARRESTED:
			say(tr("OUTCOME_ARRESTED") % [name, session.treasure()])
			if session.promoted:
				say(tr("PROMOTED") % pack.ranks[detective.rank].name)
		CaseSession.NO_WARRANT:
			say(tr("OUTCOME_NO_WARRANT") % name)
		CaseSession.WRONG_WARRANT:
			say(tr("OUTCOME_WRONG_WARRANT") % name)
		CaseSession.ESCAPED_TIME:
			say(tr("OUTCOME_TIME") % name)
		CaseSession.OUT_OF_MONEY:
			say(tr("OUTCOME_MONEY") % name)
	Career.save(detective)
	var row := add_choice_row()
	if session.boss_arrested:
		say(tr("CAREER_DONE"))
		add_choice(row, tr("BTN_NEW_CAREER"), _on_new_career)
		return
	var left := pack.cases_to_next_rank(detective.cases)
	if left > 0:
		var next_rank: String = pack.ranks[detective.rank + 1].name
		say(tr("NEXT_RANK_ONE") % next_rank if left == 1 else tr("NEXT_RANK") % [left, next_rank])
	add_choice(row, tr("BTN_NEW_CASE"), _new_case)
