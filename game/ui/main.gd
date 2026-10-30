extends GameFrame
## O jogo em si: liga o CaseSession à moldura comum (GameFrame).
## Textos da tela vêm de i18n/ui.csv (tr); os do jogo, do pacote de conteúdo.

const PACK_DIR := "res://content/parody"
const LANGUAGES := {"pt_BR": "Português (Brasil)", "en": "English"}
enum Verb { INVESTIGATE, TRAVEL, WARRANT }
enum GameItem { NEW_CASE, NEW_AGENT, LANGUAGE, ABOUT }

var pack: ContentPack
var session: CaseSession
var roster: Dictionary
## O agente que entrou pelo nome (o mesmo dicionário que está em roster.agents).
var detective: Dictionary

## O que Career.apply_outcome() devolveu no fim do caso ({promoted, boss_arrested});
## vazio enquanto o caso está em andamento.
var _result: Dictionary = {}
var _confirm: ConfirmationDialog
var _confirm_action := Callable()
var _info: AcceptDialog
var _game_menu: PopupMenu
var _languages: PopupMenu
## Tela fora do caso (identificação, sede, briefing) a redesenhar quando o idioma muda.
var _redraw := Callable()
## Muda a cada tela nova. Uma sequência com pausas (animação, texto, pausa) para quando
## o número mudou no meio dela.
var _flow := 0


func _ready() -> void:
	super()
	RenderingServer.set_default_clear_color(Palette.INK)
	pack = ContentPack.load_dir(PACK_DIR, OS.get_locale())
	TranslationServer.set_locale(pack.locale)
	_build_dialogs()
	verb_pressed.connect(_on_verb)
	menu_pressed.connect(_on_menu)
	_refresh_labels()
	roster = Career.load_roster()
	_show_welcome()


## Salva o fichário e, com um caso em andamento, o caso (semente e ações) no agente.
## Roda depois de cada ação, para nada se perder ao fechar o jogo, inclusive no navegador.
func _autosave() -> void:
	if session != null and session.outcome == CaseSession.ONGOING:
		detective.case = session.save_state()
	else:
		detective.erase("case")
	Career.save_roster(roster)


func _build_dialogs() -> void:
	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(func(): _confirm_action.call())
	add_child(_confirm)
	_info = AcceptDialog.new()
	add_child(_info)
	_languages = PopupMenu.new()
	for code in LANGUAGES:
		_languages.add_item(LANGUAGES[code])
		_languages.set_item_metadata(_languages.item_count - 1, code)
	_languages.index_pressed.connect(_on_language_selected)
	_game_menu = PopupMenu.new()
	for i in GameItem.size():
		if i == GameItem.LANGUAGE:
			_game_menu.add_submenu_node_item("", _languages, i)
		else:
			_game_menu.add_item("", i)
	_game_menu.id_pressed.connect(_on_game_item)
	add_child(_game_menu)


func _refresh_labels() -> void:
	set_menu_texts({
		"game": tr("MENU_GAME"),
		"pf": tr("MENU_PF"),
		"dossier": tr("MENU_DOSSIERS"),
	})
	var items := [tr("BTN_NEW_CASE"), tr("BTN_NEW_AGENT"), tr("MENU_LANGUAGE"), tr("MENU_ABOUT")]
	for i in items.size():
		_game_menu.set_item_text(_game_menu.get_item_index(i), items[i])
	set_verbs([tr("BTN_INVESTIGATE"), tr("BTN_TRAVEL"), tr("BTN_WARRANT")],
		tr("KEY_HINT"))


func _on_menu(id: String) -> void:
	match id:
		"game":
			_game_menu.set_item_disabled(_game_menu.get_item_index(GameItem.NEW_CASE), detective.is_empty())
			_game_menu.popup(Rect2i(menu_anchor(id), Vector2i.ZERO))
		"pf":
			_show_agents()
		"dossier":
			_show_dossier()


func _on_game_item(id: int) -> void:
	match id:
		GameItem.NEW_CASE:
			_on_new_case_menu()
		GameItem.NEW_AGENT:
			_show_welcome()
		GameItem.ABOUT:
			_show_info(tr("MENU_ABOUT"), tr("ABOUT_TEXT"))


## Um caso aberto (o salvo ou o que está na tela) é perdido; pede confirmação antes.
func _on_new_case_menu() -> void:
	if pack.boss().id in detective.caught:
		_show_home()
	elif detective.has("case") or (session != null and session.outcome == CaseSession.ONGOING):
		_confirm.dialog_text = tr("CONFIRM_NEW_CASE")
		_confirm_action = _new_case
		_confirm.popup_centered()
	else:
		_new_case()


func _show_info(title: String, text: String) -> void:
	_info.title = title
	_info.dialog_text = text
	_info.popup_centered()


## Ficha do agente na tela PF: nome, patente, casos, quanto falta para a promoção.
func _agent_sheet(agent: Dictionary) -> String:
	var text: String = tr("RANK_INFO") % [agent.name, _rank_name(agent.cases), agent.cases]
	var next := _next_rank_text(agent.cases)
	if next != "":
		text += "\n\n" + next
	if agent.has("case"):
		text += "\n\n" + tr("AGENT_ONGOING_CASE")
	return text


func _rank_name(cases: int) -> String:
	return pack.ranks[pack.rank_for_cases(cases)].name


## Quantos casos faltam para a próxima patente; "" na última.
func _next_rank_text(cases: int) -> String:
	var left := pack.cases_to_next_rank(cases)
	if left == 0:
		return ""
	var next_rank: String = pack.ranks[pack.rank_for_cases(cases) + 1].name
	return tr("NEXT_RANK_ONE") % next_rank if left == 1 else tr("NEXT_RANK") % [left, next_rank]


func _on_language_selected(index: int) -> void:
	var code: String = _languages.get_item_metadata(index)
	TranslationServer.set_locale(code)
	_refresh_labels()
	_flow += 1
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
	_flow += 1
	session = null
	hide_overlay()
	set_case("", "", 1.0)
	set_header(tr("HQ_TITLE"))
	show_scene(tr("HQ_TITLE"), tr("SCENE_ART") % "hq", Palette.PANEL)
	set_notes("")
	set_verbs_enabled(false)
	clear_text()
	clear_choices()


## Abertura, como no original: o agente se identifica pelo nome. Um nome que não está
## no fichário cadastra um agente novo, com carreira do zero.
func _show_welcome() -> void:
	_redraw = _show_welcome
	_show_hq()
	detective = {}
	say(tr("WELCOME"))
	say(tr("IDENTIFY"))
	var row := add_choice_row()
	var field := LineEdit.new()
	field.placeholder_text = tr("DEFAULT_AGENT")
	field.max_length = Career.MAX_NAME
	field.custom_minimum_size.x = 220
	field.text_submitted.connect(func(_text): _on_identified(field))
	row.add_child(field)
	add_choice(row, tr("BTN_START"), _on_identified.bind(field))
	field.grab_focus.call_deferred()


func _on_identified(field: LineEdit) -> void:
	var agent_name := field.text.strip_edges()
	if agent_name == "":
		agent_name = tr("DEFAULT_AGENT")
	var agent := Career.find(roster, agent_name)
	if agent.is_empty():
		agent = Career.fresh(agent_name)
		if not Career.add(roster, agent):
			_show_info(tr("MENU_PF"), tr("AGENTS_FULL"))
			return
		Career.save_roster(roster)
	detective = agent
	_show_home()


## Tela PF, por cima do que estiver aberto. Quem tem caso em andamento leva *.
func _show_agents() -> void:
	var rows: Array = roster.agents.map(func(a): return "%s · %s%s" % [
		a.name, _rank_name(a.cases), " *" if a.has("case") else ""])
	var ongoing: bool = roster.agents.any(func(a): return a.has("case"))
	var screen := AgentsScreen.new()
	screen.setup(tr("AGENTS_TITLE"), rows, tr("AGENTS_HINT") if not rows.is_empty() else tr("AGENTS_EMPTY"),
		tr("AGENTS_ONGOING") if ongoing else "", tr("BTN_DELETE"), tr("BTN_BACK"))
	screen.picked.connect(func(i): screen.show_sheet(_agent_sheet(roster.agents[i])))
	screen.delete_pressed.connect(_confirm_delete)
	screen.back_pressed.connect(hide_overlay)
	show_overlay(screen)


func _confirm_delete(index: int) -> void:
	_confirm.dialog_text = tr("CONFIRM_DELETE_AGENT") % roster.agents[index].name
	_confirm_action = _delete_agent.bind(index)
	_confirm.popup_centered()


## Apagar o agente que está jogando volta para a identificação.
func _delete_agent(index: int) -> void:
	var agent: Dictionary = roster.agents[index]
	roster.agents.remove_at(index)
	Career.save_roster(roster)
	if is_same(agent, detective):
		_show_welcome()
	else:
		_show_agents()


## Depois da identificação: se havia caso em andamento, pergunta se retoma; senão,
## mostra a carreira e oferece uma nova investigação.
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
	say(tr("CAREER_STATUS") % [_rank_name(detective.cases), detective.cases])
	var next := _next_rank_text(detective.cases)
	if next != "":
		say(next)
	say(tr("ASK_NEW_CASE"))
	add_choice(bar, tr("BTN_NEW_CASE"), _new_case)


## Um save que não serve mais (outra versão do pacote) é descartado, com aviso.
func _on_resume() -> void:
	var saved: Dictionary = detective.case
	detective.erase("case")
	if not _resume_case(saved):
		session = null
		_autosave()
		_show_home()
		_show_info(tr("MENU_GAME"), tr("CASE_DISCARDED"))


func _on_abandon() -> void:
	detective.erase("case")
	_autosave()
	_show_home()


func _new_case() -> void:
	session = CaseSession.new(pack, randi())
	session.start(detective)
	_result = {}
	_autosave()
	_show_briefing()


func _resume_case(saved: Dictionary) -> bool:
	session = CaseSession.resume(pack, detective, saved)
	if session == null:
		return false
	_result = {}
	_redraw = Callable()
	_show_city()
	return true


## Briefing do caso, como o "*** FLASH ***" do original: o roubo e o suspeito, uma pausa,
## e depois a missão, a verba e o prazo. O caso só começa quando o jogador aceita.
func _show_briefing() -> void:
	_redraw = _show_briefing
	_flow += 1
	var flow := _flow
	hide_overlay()
	_refresh_status()
	set_header(tr("HQ_TITLE"))
	show_scene(tr("BRIEFING_TITLE"), tr("SCENE_ART") % "hq", Palette.PANEL)
	set_verbs_enabled(false)
	clear_text()
	clear_choices()
	var crime_city: String = pack.city(session.crime_city).name
	say(_highlight(tr("BRIEFING_FLASH")))
	say(tr("ALERT_THEFT") % [session.treasure(), crime_city])
	say(tr("SUSPECT_SEEN") % _sex_name().to_lower())
	await wait_for_continue(tr("BTN_CONTINUE"))
	if flow != _flow:
		return
	clear_text()
	var deadline: Dictionary = session.difficulty.deadline
	var when := _when(deadline.day, deadline.hour)
	say(tr("MISSION") % crime_city)
	if session.budget >= 0:
		say(tr("BUDGET_AND_DEADLINE") % [_money(session.budget), when])
	else:
		say(tr("CAPTURE_DEADLINE") % when)
	say(tr("GOOD_LUCK") % [_rank_name(detective.cases), detective.name])
	var bar := add_choice_bar()
	add_spacer(bar)
	add_choice(bar, tr("BTN_ACCEPT"), _accept_case)


func _accept_case() -> void:
	_redraw = Callable()
	_show_city()


## Depois de prender o chefe: o mesmo agente recomeça do zero.
func _on_new_career() -> void:
	Career.restart(detective)
	Career.save_roster(roster)
	_show_home()


func _sex_name() -> String:
	var sex_trait: String = pack.rules.sex_trait
	return pack.trait_def(sex_trait).values[session.suspect.traits[sex_trait]]


func _day_name(day: int) -> String:
	return tr("DAY_%d" % mini(day, 6))


func _when(day: int, hour: int) -> String:
	return "%s, %s" % [_day_name(day), tr("HOUR_FMT") % hour]


## Mostra a cidade atual. Com `fresh`, o painel de texto é limpo antes.
func _show_city(fresh: bool = true) -> void:
	_flow += 1
	var city := pack.city(session.current_city)
	if fresh:
		clear_text()
	show_scene(city.name, tr("SCENE_ART") % ("cities/" + session.current_city), _tint(session.current_city))
	say(("" if fresh else "\n") + _highlight(city.name))
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
	set_case(budget, tr("DEADLINE_SHORT") % _when(deadline.day, deadline.hour), session.time_left())
	set_notes(_notes_text())


## Faixa de notas: o mandado emitido e os valores dos traços marcados.
func _notes_text() -> String:
	var warrant := tr("WARRANT_NONE")
	if session.warrant_id != "":
		warrant = pack.suspect(session.warrant_id).name
	var marked := []
	for t in pack.warrant_traits():
		if session.marks.has(t.id):
			marked.append(t.values[session.marks[t.id]])
	var traits: String = tr("NOTES_TRAITS") % " · ".join(marked) if not marked.is_empty() else tr("NOTES_NONE")
	return tr("NOTES_WARRANT") % warrant + "\n" + traits


func _money(amount: int) -> String:
	return tr("MONEY_FMT") % amount


func _show_main_actions() -> void:
	if session.outcome != CaseSession.ONGOING and _result.is_empty():
		_result = Career.apply_outcome(detective, pack, session)
	_autosave()
	_refresh_status()
	clear_choices()
	set_verbs_enabled(session.outcome == CaseSession.ONGOING)
	if session.outcome != CaseSession.ONGOING:
		_render_outcome()


## Investigar: os lugares da cidade viram uma lista no painel de texto. Para sair, basta
## outro verbo.
func _show_places() -> void:
	_flow += 1
	clear_text()
	say(tr("WHERE_TO"))
	clear_choices()
	var column := add_choice_column()
	for i in session.places.size():
		add_choice(column, pack.location_type(session.places[i].type).name, _on_investigate.bind(i))


## Como no original: se algo acontece, primeiro a animação na cena e o texto do evento;
## depois a cena mostra o lugar e a testemunha fala no pé do painel.
func _on_investigate(slot: int) -> void:
	if session.outcome != CaseSession.ONGOING:
		return
	_flow += 1
	var flow := _flow
	var r := session.investigate(slot)
	var type_id: String = session.places[slot].type
	var type := pack.location_type(type_id)
	set_verbs_enabled(false)
	clear_choices()
	clear_text()
	if r.event != "":
		await play_animation("", tr("ANIMATION_ART") % ("events/" + r.event), _tint(r.event))
		if flow != _flow:
			return
		_say_event(r.event, r.danger)
		await wait_typing()
		if flow != _flow:
			return
	show_scene(type.name, tr("SCENE_ART") % ("places/" + type_id), _tint(type_id))
	if r.text != "":
		show_speaker(r.witness, tr("SCENE_ART") % ("witnesses/" + type_id), _tint(r.witness), r.text)
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
	show_overlay(box)


func _travel_map() -> TravelMap:
	var map := TravelMap.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var points := {}
	var names := {}
	for id in pack.city_ids():
		points[id] = Vector2(pack.city(id).map.x, pack.city(id).map.y)
		names[id] = pack.city(id).name
	map.setup(points, names, session.current_city, session.destinations(), session.route)
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


## Mandado: o ministro na cena e, no painel, um seletor por traço. Marcar não filtra
## nada; a busca e o pedido de mandado custam horas, mostradas nos botões.
func _show_computer(result: Array = []) -> void:
	_flow += 1
	show_scene(tr("JUDGE_TITLE"), tr("SCENE_ART") % "warrant/judge", Palette.PANEL)
	clear_text()
	say(_highlight(tr("WARRANT_TITLE")))
	for line in result:
		say(line)
	clear_choices()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 3)
	for t in pack.warrant_traits():
		_add_trait_row(grid, t)
	add_choice_control(grid)
	var bar := add_choice_bar()
	add_choice(bar, _with_hours(tr("BTN_SEARCH"), "search_hours"), _on_search)
	add_spacer(bar)
	add_choice(bar, _with_hours(tr("BTN_ISSUE_WARRANT"), "issue_hours"), _on_issue)


func _add_trait_row(grid: GridContainer, t: Dictionary) -> void:
	var label := Label.new()
	label.text = t.name
	label.custom_minimum_size.x = 96
	grid.add_child(label)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_item(tr("TRAIT_UNKNOWN"))
	var values: Array = t.values.keys()
	for v in values:
		opt.add_item(t.values[v])
	opt.selected = values.find(session.marks[t.id]) + 1 if session.marks.has(t.id) else 0
	opt.item_selected.connect(_on_mark.bind(t.id, values))
	grid.add_child(opt)


func _on_mark(index: int, trait_id: String, values: Array) -> void:
	session.set_mark(trait_id, values[index - 1] if index > 0 else "")
	_refresh_status()
	_autosave()


func _with_hours(label: String, rule: String) -> String:
	var hours := int(pack.rules.get("warrant", {}).get(rule, 0))
	return tr("TRAVEL_OPTION") % [label, hours] if hours > 0 else label


func _on_search() -> void:
	var r := session.search(session.marks)
	_after_warrant(r, _search_lines(r.matches))


## Mandado com um só compatível: o ministro bate o martelo. Senão, conta como busca.
func _on_issue() -> void:
	var r := session.issue_warrant(session.marks)
	if not r.issued:
		_after_warrant(r, [tr("WARRANT_NOT_ISSUED")] + _search_lines(r.matches))
		return
	_flow += 1
	var flow := _flow
	set_verbs_enabled(false)
	clear_choices()
	await play_animation(tr("JUDGE_TITLE"), tr("ANIMATION_ART") % "warrant/gavel", Palette.PANEL)
	if flow != _flow:
		return
	_after_warrant(r, [tr("WARRANT_ISSUED") % r.matches[0].name])


func _search_lines(matches: Array) -> Array:
	if matches.is_empty():
		return [tr("NO_MATCH")]
	if matches.size() == 1:
		return [tr("ONE_MATCH") % matches[0].name]
	return [tr("SUSPECTS_LIST") % ", ".join(matches.map(func(s): return s.name))]


func _after_warrant(r: Dictionary, lines: Array) -> void:
	if r.slept:
		lines.append(tr("SLEEPING"))
	if session.outcome == CaseSession.ONGOING:
		_show_main_actions()
		_show_computer(lines)
		return
	clear_text()
	for line in lines:
		say(line)
	_show_main_actions()


## Dossiê no formato do PowerPoint, aberto pelo menu a qualquer hora. Quem não bate com
## os traços marcados aparece riscado; clicar num nome abre a ficha.
func _show_dossier() -> void:
	var matches := _last_matches()
	var entries := pack.suspects.map(func(s): return {
		"name": s.name, "boss": s.get("boss", false),
		"ruled_out": not matches.is_empty() and not (s.id in matches)})
	var screen := DossierScreen.new()
	screen.setup(entries, tr("BTN_BACK"), tr("BTN_CLOSE"))
	screen.picked.connect(_show_card.bind(screen))
	screen.back_pressed.connect(hide_overlay)
	show_overlay(screen, true)


func _last_matches() -> Array:
	return session.last_matches if session != null else []


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
	elif not _last_matches().is_empty() and not (s.id in _last_matches()):
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
	if _result.promoted:
		say(tr("PROMOTED") % _rank_name(detective.cases))
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
	if _result.boss_arrested:
		say(tr("CAREER_DONE"))
		add_choice(row, tr("BTN_NEW_CAREER"), _on_new_career)
		return
	var next := _next_rank_text(detective.cases)
	if next != "":
		say(next)
	add_choice(row, tr("BTN_NEW_CASE"), _new_case)
