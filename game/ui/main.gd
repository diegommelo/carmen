extends GameFrame
## O jogo em si: liga o CaseSession à moldura comum (GameFrame).
## Textos da tela vêm de i18n/ui.csv (tr); os do jogo, do pacote de conteúdo.

const PACK_DIR := "res://content/parody"
const LANGUAGES := {"pt_BR": "Português (Brasil)", "en": "English"}
enum Verb { INVESTIGATE, TRAVEL, WARRANT }

var pack: ContentPack
var session: CaseSession
var detective: Dictionary

var _marks: Dictionary = {}
## Cidades visitadas no caso, da cena do crime até a atual, para desenhar no mapa.
var _route: Array = []
var _confirm: ConfirmationDialog
var _info: AcceptDialog
var _languages: PopupMenu
## Tela fora do caso (identificação, sede, briefing) a redesenhar quando o idioma muda.
var _redraw := Callable()


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
		_show_welcome()
	else:
		_show_home()


## Salva a carreira e, com um caso em andamento, o caso (semente e ações). Roda depois
## de cada ação, para nada se perder ao fechar o jogo, inclusive no navegador.
func _autosave() -> void:
	var state := {}
	if session != null and session.outcome == CaseSession.ONGOING:
		state = session.save_state()
		state.marks = _marks
	Career.save(detective, Career.PATH, state)


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
		"dossier": tr("MENU_DOSSIERS"),
		"language": tr("MENU_LANGUAGE"),
		"about": tr("MENU_ABOUT"),
	})
	set_verbs([tr("BTN_INVESTIGATE"), tr("BTN_TRAVEL"), tr("BTN_WARRANT")],
		tr("KEY_HINT"))


func _on_menu(id: String) -> void:
	match id:
		"new_career":
			_confirm.dialog_text = tr("CONFIRM_NEW_CAREER")
			_confirm.popup_centered()
		"rank":
			_show_info(tr("MENU_RANK"), _rank_text())
		"dossier":
			_show_dossier()
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
		pack.set_language(code)
	else:
		session.set_language(code)
	if _redraw.is_valid():
		_redraw.call()
	elif session.outcome == CaseSession.ONGOING:
		# O que já está no painel fica como estava; a cidade é mostrada de novo no idioma novo.
		_show_city(false)
	else:
		clear_text()
		_refresh_status()
		clear_choices()
		_render_outcome()


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


## Sede da PF sem caso aberto: limpa a moldura para as telas de abertura.
func _show_hq() -> void:
	session = null
	hide_overlay()
	set_case("", "", 1.0)
	set_header(tr("HQ_TITLE"))
	show_scene(tr("HQ_TITLE"), tr("SCENE_ART") % "hq", Palette.PANEL)
	set_notes("")
	set_verbs_enabled(false)
	clear_text()
	clear_choices()


## Sem carreira salva: boas-vindas da PF e cadastro do agente.
func _show_welcome() -> void:
	_redraw = _show_welcome
	_show_hq()
	say(tr("WELCOME"))
	say(tr("IDENTIFY"))
	var row := add_choice_row()
	var field := LineEdit.new()
	field.placeholder_text = tr("DEFAULT_AGENT")
	field.custom_minimum_size.x = 220
	field.text_submitted.connect(func(_text): _on_identified(field))
	row.add_child(field)
	add_choice(row, tr("BTN_START"), _on_identified.bind(field))
	field.grab_focus.call_deferred()


func _on_identified(field: LineEdit) -> void:
	var agent_name := field.text.strip_edges()
	detective = Career.fresh(agent_name if agent_name != "" else tr("DEFAULT_AGENT"))
	Career.save(detective)
	_show_home()


## Com carreira salva, o agente já entra identificado. Se havia caso em andamento,
## pergunta se retoma; senão, mostra a carreira e oferece uma nova investigação.
func _show_home() -> void:
	_redraw = _show_home
	_show_hq()
	say(tr("AGENT_WELCOME") % detective.name)
	var bar := add_choice_bar()
	if detective.has("case"):
		say(tr("ASK_RESUME"))
		add_choice(bar, tr("BTN_YES"), _on_resume)
		add_choice(bar, tr("BTN_NO"), _on_abandon)
		return
	if pack.boss().id in detective.caught:
		say(tr("CAREER_DONE"))
		add_choice(bar, tr("BTN_NEW_CAREER"), _on_new_career)
		return
	say(tr("CAREER_STATUS") % [pack.ranks[detective.rank].name, detective.cases])
	var left := pack.cases_to_next_rank(detective.cases)
	if left > 0:
		var next_rank: String = pack.ranks[detective.rank + 1].name
		say(tr("NEXT_RANK_ONE") % next_rank if left == 1 else tr("NEXT_RANK") % [left, next_rank])
	say(tr("ASK_NEW_CASE"))
	add_choice(bar, tr("BTN_NEW_CASE"), _new_case)


## Um save que não serve mais (outra versão do pacote) é descartado.
func _on_resume() -> void:
	var saved: Dictionary = detective.case
	detective.erase("case")
	if not _resume_case(saved):
		session = null
		_autosave()
		_show_home()


func _on_abandon() -> void:
	detective.erase("case")
	_autosave()
	_show_home()


func _new_case() -> void:
	session = CaseSession.new(pack, randi())
	session.start(detective)
	_marks.clear()
	_route = [session.crime_city]
	_autosave()
	_show_briefing()


func _resume_case(saved: Dictionary) -> bool:
	session = CaseSession.new(pack, int(saved.get("seed", 0)))
	session.start(detective)
	var actions: Array = saved.get("actions", [])
	if not session.replay(actions):
		return false
	_marks = saved.get("marks", {})
	_route = [session.crime_city]
	for a in actions:
		if a[0] == "travel":
			_route.append(a[1])
	_redraw = Callable()
	_show_city()
	return true


## Briefing do caso, como o "*** FLASH ***" do original: o roubo, o suspeito, a missão
## e o prazo. O caso só começa quando o jogador aceita.
func _show_briefing() -> void:
	_redraw = _show_briefing
	hide_overlay()
	_refresh_status()
	set_header(tr("HQ_TITLE"))
	show_scene(tr("BRIEFING_TITLE"), tr("SCENE_ART") % "hq", Palette.PANEL)
	set_verbs_enabled(false)
	clear_text()
	var crime_city: String = pack.city(session.crime_city).name
	var deadline: Dictionary = session.difficulty.deadline
	say(_highlight(tr("BRIEFING_FLASH")))
	say(tr("ALERT_THEFT") % [session.treasure(), crime_city])
	say(tr("SUSPECT_SEEN") % _sex_name().to_lower())
	say(tr("MISSION") % crime_city)
	say(tr("DEADLINE") % [_day_name(deadline.day), tr("HOUR_FMT") % deadline.hour])
	say(tr("GOOD_LUCK") % [pack.ranks[detective.rank].name, detective.name])
	clear_choices()
	var bar := add_choice_bar()
	add_spacer(bar)
	add_choice(bar, tr("BTN_ACCEPT"), _accept_case)


func _accept_case() -> void:
	_redraw = Callable()
	_show_city()


func _on_new_career() -> void:
	Career.erase()
	detective = {}
	_show_welcome()


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
	set_case(budget, tr("DEADLINE_SHORT") % _when(deadline.day, deadline.hour), _time_left())
	set_notes(_notes_text())


## Faixa de notas: o mandado emitido e os valores dos traços marcados.
func _notes_text() -> String:
	var warrant := tr("WARRANT_NONE")
	if session.warrant_id != "":
		warrant = pack.suspect(session.warrant_id).name
	var marked := []
	for t in pack.warrant_traits():
		if _marks.has(t.id):
			marked.append(t.values[_marks[t.id]])
	var traits: String = tr("NOTES_TRAITS") % " · ".join(marked) if not marked.is_empty() else tr("NOTES_NONE")
	return tr("NOTES_WARRANT") % warrant + "\n" + traits


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
	_autosave()
	_refresh_status()
	clear_choices()
	set_verbs_enabled(session.outcome == CaseSession.ONGOING)
	if session.outcome != CaseSession.ONGOING:
		_render_outcome()


## Investigar: os lugares da cidade viram uma lista no painel de texto.
func _show_places() -> void:
	clear_text()
	say(tr("WHERE_TO"))
	clear_choices()
	var column := add_choice_column()
	for i in session.places.size():
		add_choice(column, pack.location_type(session.places[i].type).name, _on_investigate.bind(i))
	var bar := add_choice_bar()
	add_spacer(bar)
	add_choice(bar, tr("BTN_BACK"), _show_city)


## A testemunha aparece na cena e a fala dela ocupa o painel de texto.
func _on_investigate(slot: int) -> void:
	if session.outcome != CaseSession.ONGOING:
		return
	var r := session.investigate(slot)
	var type_id: String = session.places[slot].type
	var type := pack.location_type(type_id)
	show_scene(r.witness, tr("SCENE_ART") % ("witnesses/" + type_id), _tint(type_id))
	clear_text()
	_say_event(r.event, r.danger)
	if r.text != "":
		say(_highlight("%s (%s):" % [r.witness, type.name]))
		say(r.text)
	if r.slept:
		say(tr("SLEEPING"))
	_show_main_actions()


func _say_event(event: String, danger: int) -> void:
	match event:
		"capture":
			say(tr("FOUND_HIDEOUT"))
		"henchman":
			say("[i]%s[/i]" % pack.texts.henchman)
		"danger":
			say("[i]%s[/i]" % pack.texts.danger[danger])


## Viajar: mapa em tela cheia, com um botão por destino; passar o mouse destaca a rota.
func _show_destinations() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(heading(tr("TRAVEL_TITLE") % pack.city(session.current_city).name))
	var map := _travel_map()
	box.add_child(map)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	box.add_child(row)
	for id in session.destinations():
		var b := add_choice(row, _ticket_text(id), _fly.bind(map, row, id), session.can_afford(id))
		b.mouse_entered.connect(map.highlight.bind(id))
		b.focus_entered.connect(map.highlight.bind(id))
	var bar := HBoxContainer.new()
	box.add_child(bar)
	add_spacer(bar)
	add_choice(bar, tr("BTN_BACK"), hide_overlay)
	show_overlay(box)


func _travel_map() -> TravelMap:
	var map := TravelMap.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var points := {}
	var names := {}
	for id in pack.city_ids():
		points[id] = Vector2(pack.city(id).map.x, pack.city(id).map.y)
		names[id] = pack.city(id).name
	map.setup(points, names, session.current_city, session.destinations(), _route)
	return map


func _ticket_text(city_id: String) -> String:
	var text: String = tr("TRAVEL_OPTION") % [pack.city(city_id).name, session.travel_hours(city_id)]
	if session.budget >= 0:
		text += " · " + _money(session.ticket_price(city_id))
	return text


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
	_autosave()


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


## Dossiê no formato do PowerPoint, aberto pelo menu a qualquer hora. Quem não bate com
## os traços marcados aparece riscado; clicar num nome abre a ficha.
func _show_dossier() -> void:
	var compatible := _compatible_ids()
	var entries := pack.suspects.map(func(s): return {
		"name": s.name, "boss": s.get("boss", false), "ruled_out": not (s.id in compatible)})
	var screen := DossierScreen.new()
	screen.setup(entries, tr("BTN_BACK"), tr("BTN_CLOSE"))
	screen.picked.connect(_show_card.bind(screen))
	screen.back_pressed.connect(hide_overlay)
	show_overlay(screen, true)


func _compatible_ids() -> Array:
	return _compatible(_marks).map(func(s): return s.id)


## Ficha no estilo do cartão do original. Preso na carreira ganha carimbo verde.
func _show_card(index: int, screen: DossierScreen) -> void:
	index = posmod(index, pack.suspects.size())
	var s: Dictionary = pack.suspects[index]
	var d := pack.dossier(s.id)
	var stamp := ""
	var color := Palette.ALERT
	if s.id in detective.get("caught", []):
		stamp = tr("STAMP_CAUGHT")
		color = Palette.OK
	elif not (s.id in _compatible_ids()):
		stamp = tr("STAMP_RULED_OUT")
	var rows := [[tr("DOSSIER_NAME"), d.full_name]]
	if d.occupation != "":
		rows.append([tr("DOSSIER_OCCUPATION"), d.occupation])
	for row in d.traits:
		rows.append([row.name, row.value])
	if not d.notes.is_empty():
		rows.append([tr("DOSSIER_NOTES"), " ".join(d.notes)])
	screen.show_card(index, s.name, tr("SCENE_ART") % ("suspects/" + s.id), _tint(s.id),
		stamp, color, rows)


## Desfecho: a cena mostra a prisão ou a fuga e o texto conta o resultado.
func _render_outcome() -> void:
	var arrested := session.outcome == CaseSession.ARRESTED
	show_scene(tr("SCENE_ARRESTED") if arrested else tr("SCENE_ESCAPED"),
		tr("SCENE_ART") % ("outcomes/" + ("arrest" if arrested else "escape")),
		Palette.OK.darkened(0.6) if arrested else Palette.ALERT.darkened(0.6))
	say(_outcome_text())
	if session.promoted:
		say(tr("PROMOTED") % pack.ranks[detective.rank].name)
	_show_next_step()


func _outcome_text() -> String:
	var name: String = session.suspect.name
	match session.outcome:
		CaseSession.ARRESTED:
			return tr("OUTCOME_ARRESTED") % [name, session.treasure()]
		CaseSession.NO_WARRANT:
			return tr("OUTCOME_NO_WARRANT") % name
		CaseSession.WRONG_WARRANT:
			return tr("OUTCOME_WRONG_WARRANT") % name
		CaseSession.ESCAPED_TIME:
			return tr("OUTCOME_TIME") % name
		_:
			return tr("OUTCOME_MONEY") % name


## Depois do desfecho: fim da carreira, ou quanto falta para a próxima patente e um caso novo.
func _show_next_step() -> void:
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
